import 'package:expense_splitter_app/services/remainder_distributor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('distributeEqually', () {
    test('divides evenly with no remainder', () {
      expect(distributeEqually(total: 8500, count: 4), [2125, 2125, 2125, 2125]);
    });

    test('distributes remainder to the first N entries', () {
      final result = distributeEqually(total: 100000, count: 3);
      expect(result, [33334, 33333, 33333]);
      expect(result.fold<int>(0, (a, b) => a + b), 100000);
    });

    test('zero total yields all zeros', () {
      expect(distributeEqually(total: 0, count: 3), [0, 0, 0]);
    });

    test('single entry gets the full total', () {
      expect(distributeEqually(total: 12345, count: 1), [12345]);
    });

    test('rejects zero or negative count', () {
      expect(() => distributeEqually(total: 100, count: 0), throwsArgumentError);
    });
  });

  group('distributeByPercentage', () {
    test('sums to exactly the total', () {
      final result = distributeByPercentage(total: 100, percentages: [33.33, 33.33, 33.34]);
      expect(result.fold<int>(0, (a, b) => a + b), 100);
    });

    test('rejects percentages that do not sum to 100', () {
      expect(() => distributeByPercentage(total: 100, percentages: [50, 40]), throwsArgumentError);
    });
  });
}
