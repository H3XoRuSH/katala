import '../../domain/entities/resolved_contact.dart';
import '../../platform/bridges/contact_bridge.dart';

/// Use case for contact search and disambiguation preview in UI.
class ResolveContactsUseCase {
  final ContactBridge contactBridge;

  const ResolveContactsUseCase({
    required this.contactBridge,
  });

  /// Resolves contacts matching [query] using native address book.
  Future<List<ResolvedContact>> execute(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    try {
      return await contactBridge.resolve(trimmed);
    } catch (e) {
      // Permission denied or platform error returns empty list gracefully
      return const [];
    }
  }
}
