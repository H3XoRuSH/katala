import 'package:katala/domain/entities/resolved_contact.dart';
import 'package:katala/platform/bridges/contact_bridge.dart';

/// In-memory fake implementation of [ContactBridge] with exact, prefix, and contains search.
class FakeContactBridge implements ContactBridge {
  final List<ResolvedContact> contacts;

  FakeContactBridge([List<ResolvedContact>? initialContacts])
      : contacts = initialContacts != null ? List.from(initialContacts) : [];

  @override
  Future<List<ResolvedContact>> resolve(String name) async {
    final query = name.trim().toLowerCase();
    if (query.isEmpty) return [];

    final exactMatches = <ResolvedContact>[];
    final prefixMatches = <ResolvedContact>[];
    final containsMatches = <ResolvedContact>[];

    for (final contact in contacts) {
      final displayName = contact.displayName.toLowerCase();
      if (displayName == query) {
        exactMatches.add(contact);
      } else if (displayName.startsWith(query) || displayName.split(' ').any((part) => part.startsWith(query))) {
        prefixMatches.add(contact);
      } else if (displayName.contains(query)) {
        containsMatches.add(contact);
      }
    }

    final results = [...exactMatches, ...prefixMatches, ...containsMatches];
    return results.take(20).toList();
  }

  @override
  Future<ResolvedContact?> getById(String contactId) async {
    for (final contact in contacts) {
      if (contact.platformId == contactId) {
        return contact;
      }
    }
    return null;
  }
}
