import '../../domain/entities/resolved_contact.dart';

/// Dart abstraction for platform address book contact resolution.
///
/// Search Strategy:
/// 1. Exact display-name match (case-insensitive)
/// 2. First-name or last-name startsWith
/// 3. Substring contains match
/// Results sorted by relevance, capped at 20.
abstract class ContactBridge {
  /// Resolves a contact name from the native device address book.
  /// Returns matching resolved contacts, or an empty list if permission is denied or no match found.
  Future<List<ResolvedContact>> resolve(String name);

  /// Retrieves a single resolved contact by its platform contact ID.
  Future<ResolvedContact?> getById(String contactId);
}
