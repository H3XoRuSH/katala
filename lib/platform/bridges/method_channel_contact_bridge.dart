import 'package:flutter/services.dart';
import '../../domain/entities/resolved_contact.dart';
import 'contact_bridge.dart';

/// Production [ContactBridge] implementation using native Flutter [MethodChannel].
class MethodChannelContactBridge implements ContactBridge {
  static const MethodChannel _channel = MethodChannel('com.katala.app/contacts');

  ResolvedContact _mapToContact(Map<dynamic, dynamic> map) {
    final phoneNumbers = (map['phoneNumbers'] as List<dynamic>?)?.cast<String>() ?? [];
    return ResolvedContact(
      platformId: (map['id'] as String?) ?? (map['platformId'] as String?) ?? '',
      displayName: (map['displayName'] as String?) ?? '',
      phoneNumber: phoneNumbers.isNotEmpty ? phoneNumbers.first : null,
      allPhoneNumbers: phoneNumbers,
    );
  }

  @override
  Future<List<ResolvedContact>> resolve(String name) async {
    try {
      final results = await _channel.invokeListMethod<dynamic>('resolve', {
        'name': name,
      });
      if (results != null) {
        return results.whereType<Map<dynamic, dynamic>>().map(_mapToContact).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<ResolvedContact?> getById(String contactId) async {
    try {
      final result = await _channel.invokeMapMethod<dynamic, dynamic>('getById', {
        'contactId': contactId,
      });
      if (result != null) {
        return _mapToContact(result);
      }
    } catch (_) {}
    return null;
  }
}
