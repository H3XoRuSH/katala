import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/use_cases/resolve_contacts_use_case.dart';
import 'package:katala/domain/entities/resolved_contact.dart';
import '../../test_helpers/fake_contact_bridge.dart';

void main() {
  group('ResolveContactsUseCase', () {
    test('Resolves single match, multiple matches, and empty query', () async {
      const c1 = ResolvedContact(platformId: 'c1', displayName: 'Maria Santos', phoneNumber: '09171111111');
      const c2 = ResolvedContact(platformId: 'c2', displayName: 'Maria Clara', phoneNumber: '09172222222');
      const c3 = ResolvedContact(platformId: 'c3', displayName: 'Juan Dela Cruz', phoneNumber: '09173333333');

      final bridge = FakeContactBridge([c1, c2, c3]);
      final useCase = ResolveContactsUseCase(contactBridge: bridge);

      // Multiple matches
      final mariaList = await useCase.execute('Maria');
      expect(mariaList, hasLength(2));

      // Single match
      final juanList = await useCase.execute('Juan');
      expect(juanList, hasLength(1));
      expect(juanList.first.displayName, 'Juan Dela Cruz');

      // Empty query
      final emptyList = await useCase.execute('   ');
      expect(emptyList, isEmpty);
    });
  });
}
