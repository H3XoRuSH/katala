package com.katala.app.bridges

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.database.Cursor
import android.provider.ContactsContract
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native Android ContactBridge implementation.
 *
 * Resolves contacts against ContactsContract with a 3-tier relevance strategy:
 * 1. Exact display-name match
 * 2. Prefix match on word boundaries (first / last name)
 * 3. Substring contains match
 * Capped at 20 results.
 */
class ContactBridgeImpl(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.katala.app/contacts"
        private const val MAX_RESULTS = 20
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "resolve" -> {
                val name = call.argument<String>("name") ?: ""
                val contacts = resolveContacts(name)
                result.success(contacts)
            }
            "getById" -> {
                val contactId = call.argument<String>("contactId")
                if (contactId != null) {
                    val contact = getContactById(contactId)
                    result.success(contact)
                } else {
                    result.error("INVALID_ARGUMENTS", "contactId is required", null)
                }
            }
            "dispose" -> {
                channel.setMethodCallHandler(null)
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun resolveContacts(query: String): List<Map<String, Any?>> {
        val trimmedQuery = query.trim()
        if (trimmedQuery.isEmpty()) {
            return emptyList()
        }

        val hasPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_CONTACTS
        ) == PackageManager.PERMISSION_GRANTED

        if (!hasPermission) {
            // Per contract: permission denied returns empty list without error
            return emptyList()
        }

        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
            ContactsContract.CommonDataKinds.Phone.IS_PRIMARY
        )

        // Query all phone contacts
        val cursor: Cursor? = try {
            context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                projection,
                null,
                null,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC"
            )
        } catch (e: Exception) {
            null
        }

        cursor ?: return emptyList()

        data class RawContact(
            val id: String,
            val displayName: String,
            var primaryPhone: String? = null,
            val phoneNumbers: MutableList<String> = mutableListOf()
        )

        val contactsMap = mutableMapOf<String, RawContact>()

        cursor.use {
            val idIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
            val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val numberIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
            val primaryIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.IS_PRIMARY)

            while (it.moveToNext()) {
                val id = if (idIdx >= 0) it.getString(idIdx) else null ?: continue
                val displayName = if (nameIdx >= 0) it.getString(nameIdx) else null ?: ""
                val number = if (numberIdx >= 0) it.getString(numberIdx) else null
                val isPrimary = if (primaryIdx >= 0) it.getInt(primaryIdx) > 0 else false

                val contact = contactsMap.getOrPut(id) {
                    RawContact(id = id, displayName = displayName)
                }

                if (!number.isNullOrBlank()) {
                    val cleanNumber = number.trim()
                    if (!contact.phoneNumbers.contains(cleanNumber)) {
                        contact.phoneNumbers.add(cleanNumber)
                    }
                    if (isPrimary || contact.primaryPhone == null) {
                        contact.primaryPhone = cleanNumber
                    }
                }
            }
        }

        // Rank contacts according to strategy:
        // Rank 1: Exact match (case-insensitive)
        // Rank 2: Prefix match on any word boundary
        // Rank 3: Substring contains
        val scoredList = mutableListOf<Pair<Int, RawContact>>()

        for (contact in contactsMap.values) {
            val name = contact.displayName.trim()
            if (name.equals(trimmedQuery, ignoreCase = true)) {
                scoredList.add(1 to contact)
            } else if (name.split("\\s+".toRegex()).any { it.startsWith(trimmedQuery, ignoreCase = true) }) {
                scoredList.add(2 to contact)
            } else if (name.contains(trimmedQuery, ignoreCase = true)) {
                scoredList.add(3 to contact)
            }
        }

        // Sort by rank ascending, then displayName ascending
        return scoredList
            .sortedWith(compareBy<Pair<Int, RawContact>> { it.first }.thenBy { it.second.displayName })
            .take(MAX_RESULTS)
            .map { (_, contact) ->
                mapOf(
                    "platformId" to contact.id,
                    "displayName" to contact.displayName,
                    "phoneNumber" to (contact.primaryPhone ?: contact.phoneNumbers.firstOrNull()),
                    "allPhoneNumbers" to contact.phoneNumbers
                )
            }
    }

    private fun getContactById(contactId: String): Map<String, Any?>? {
        val hasPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_CONTACTS
        ) == PackageManager.PERMISSION_GRANTED

        if (!hasPermission) {
            return null
        }

        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
            ContactsContract.CommonDataKinds.Phone.IS_PRIMARY
        )

        val selection = "${ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?"
        val selectionArgs = arrayOf(contactId)

        val cursor: Cursor? = try {
            context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                null
            )
        } catch (e: Exception) {
            null
        }

        cursor ?: return null

        var displayName = ""
        var primaryPhone: String? = null
        val phoneNumbers = mutableListOf<String>()

        cursor.use {
            val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val numberIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
            val primaryIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.IS_PRIMARY)

            while (it.moveToNext()) {
                if (displayName.isEmpty() && nameIdx >= 0) {
                    displayName = it.getString(nameIdx) ?: ""
                }
                val number = if (numberIdx >= 0) it.getString(numberIdx) else null
                val isPrimary = if (primaryIdx >= 0) it.getInt(primaryIdx) > 0 else false

                if (!number.isNullOrBlank()) {
                    val cleanNumber = number.trim()
                    if (!phoneNumbers.contains(cleanNumber)) {
                        phoneNumbers.add(cleanNumber)
                    }
                    if (isPrimary || primaryPhone == null) {
                        primaryPhone = cleanNumber
                    }
                }
            }
        }

        if (displayName.isEmpty() && phoneNumbers.isEmpty()) {
            return null
        }

        return mapOf(
            "platformId" to contactId,
            "displayName" to displayName,
            "phoneNumber" to (primaryPhone ?: phoneNumbers.firstOrNull()),
            "allPhoneNumbers" to phoneNumbers
        )
    }
}
