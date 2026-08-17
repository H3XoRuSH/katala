import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/nlp/models/temporal_expression.dart';
import 'package:katala/domain/nlp/temporal_resolver.dart';
import '../../test_helpers/fake_clock.dart';

void main() {
  group('Stage 4: TemporalResolver', () {
    const resolver = TemporalResolver();
    // Monday Aug 17, 2026 at 10:00 AM UTC
    late FakeClock fakeClock;

    setUp(() {
      fakeClock = FakeClock(DateTime.utc(2026, 8, 17, 10, 0), timezone: 'UTC');
    });

    test('resolves relative minutes ("in 30 minutes")', () {
      const expr = TemporalExpression(rawText: 'in 30 minutes');
      final result = resolver.resolve(expr, clock: fakeClock);
      expect(result.resolvedTime, DateTime.utc(2026, 8, 17, 10, 30));
    });

    test('resolves relative hours ("in 2 hours")', () {
      const expr = TemporalExpression(rawText: 'in 2 hours');
      final result = resolver.resolve(expr, clock: fakeClock);
      expect(result.resolvedTime, DateTime.utc(2026, 8, 17, 12, 0));
    });

    test('resolves tomorrow combined ("tomorrow at 3pm")', () {
      const expr = TemporalExpression(rawText: 'tomorrow at 3pm');
      final result = resolver.resolve(expr, clock: fakeClock);
      expect(result.resolvedTime, DateTime.utc(2026, 8, 18, 15, 0));
    });

    test('resolves Filipino tomorrow ("bukas ng 9am")', () {
      const expr = TemporalExpression(rawText: 'bukas ng 9am');
      final result = resolver.resolve(expr, clock: fakeClock);
      expect(result.resolvedTime, DateTime.utc(2026, 8, 18, 9, 0));
    });

    test('resolves named times ("noon", "midnight", "tonight")', () {
      final noonResult = resolver.resolve(const TemporalExpression(rawText: 'noon'), clock: fakeClock);
      expect(noonResult.resolvedTime, DateTime.utc(2026, 8, 17, 12, 0));

      final midnightResult = resolver.resolve(const TemporalExpression(rawText: 'midnight'), clock: fakeClock);
      expect(midnightResult.resolvedTime, DateTime.utc(2026, 8, 18, 0, 0));

      final tonightResult = resolver.resolve(const TemporalExpression(rawText: 'tonight'), clock: fakeClock);
      expect(tonightResult.resolvedTime, DateTime.utc(2026, 8, 17, 20, 0));
    });

    test('resolves "later" / "mamaya" with 2 hour offset and 10 PM cap', () {
      final laterResult = resolver.resolve(const TemporalExpression(rawText: 'later'), clock: fakeClock);
      expect(laterResult.resolvedTime, DateTime.utc(2026, 8, 17, 12, 0));

      // Test night cap: 9:00 PM + 2 hours -> 11 PM -> caps to 8:00 AM next day
      final nightClock = FakeClock(DateTime.utc(2026, 8, 17, 21, 0));
      final nightResult = resolver.resolve(const TemporalExpression(rawText: 'mamaya'), clock: nightClock);
      expect(nightResult.resolvedTime, DateTime.utc(2026, 8, 18, 8, 0));
    });

    test('bare number returns ambiguity flag without resolving time', () {
      const expr = TemporalExpression(rawText: 'at 3', ambiguity: TemporalAmbiguity.bareNumber);
      final result = resolver.resolve(expr, clock: fakeClock);
      expect(result.resolvedTime, isNull);
      expect(result.ambiguity, TemporalAmbiguity.bareNumber);
    });

    test('resolves day-of-week ("next Monday at 10am", "sa Lunes ng 9am")', () {
      const expr = TemporalExpression(rawText: 'next monday at 10am');
      final result = resolver.resolve(expr, clock: fakeClock);
      // Next Monday from Monday Aug 17 is Monday Aug 24
      expect(result.resolvedTime, DateTime.utc(2026, 8, 24, 10, 0));
    });
  });
}
