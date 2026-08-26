import 'package:expense_splitter_app/services/calculator_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalculatorEngine', () {
    test('addition: 10000 + 5000 + 2500 = 17500, live value updates after each operator', () {
      var state = CalculatorEngine.initial(0);
      state = CalculatorEngine.inputDigit(state, '1');
      state = CalculatorEngine.inputDigit(state, '0');
      state = CalculatorEngine.inputDigit(state, '0');
      state = CalculatorEngine.inputDigit(state, '0');
      state = CalculatorEngine.inputDigit(state, '0');
      expect(state.liveValue, 10000);

      state = CalculatorEngine.inputOperator(state, CalculatorOperator.add);
      expect(state.liveValue, 10000);

      state = CalculatorEngine.inputDigit(state, '5');
      state = CalculatorEngine.inputDigit(state, '0');
      state = CalculatorEngine.inputDigit(state, '0');
      state = CalculatorEngine.inputDigit(state, '0');
      expect(state.liveValue, 15000);

      state = CalculatorEngine.inputOperator(state, CalculatorOperator.add);
      expect(state.liveValue, 15000);

      state = CalculatorEngine.inputDigit(state, '2');
      state = CalculatorEngine.inputDigit(state, '5');
      state = CalculatorEngine.inputDigit(state, '0');
      state = CalculatorEngine.inputDigit(state, '0');
      expect(state.liveValue, 17500);

      state = CalculatorEngine.equals(state);
      expect(state.liveValue, 17500);
    });

    test('subtraction', () {
      var state = CalculatorEngine.initial(100);
      state = CalculatorEngine.inputOperator(state, CalculatorOperator.subtract);
      state = CalculatorEngine.inputDigit(state, '3');
      state = CalculatorEngine.inputDigit(state, '0');
      expect(state.liveValue, 70);
      state = CalculatorEngine.equals(state);
      expect(state.liveValue, 70);
    });

    test('multiplication', () {
      var state = CalculatorEngine.initial(0);
      state = CalculatorEngine.inputDigit(state, '6');
      state = CalculatorEngine.inputOperator(state, CalculatorOperator.multiply);
      state = CalculatorEngine.inputDigit(state, '7');
      expect(state.liveValue, 42);
    });

    test('division', () {
      var state = CalculatorEngine.initial(0);
      state = CalculatorEngine.inputDigit(state, '9');
      state = CalculatorEngine.inputOperator(state, CalculatorOperator.divide);
      state = CalculatorEngine.inputDigit(state, '3');
      expect(state.liveValue, 3);
    });

    test('decimal input: 10.5 + 2.25 = 12.75', () {
      var state = CalculatorEngine.initial(0);
      state = CalculatorEngine.inputDigit(state, '1');
      state = CalculatorEngine.inputDigit(state, '0');
      state = CalculatorEngine.inputDecimal(state);
      state = CalculatorEngine.inputDigit(state, '5');
      state = CalculatorEngine.inputOperator(state, CalculatorOperator.add);
      state = CalculatorEngine.inputDigit(state, '2');
      state = CalculatorEngine.inputDecimal(state);
      state = CalculatorEngine.inputDigit(state, '2');
      state = CalculatorEngine.inputDigit(state, '5');
      expect(state.liveValue, 12.75);
    });

    test('a second decimal point in the same operand is ignored', () {
      var state = CalculatorEngine.initial(0);
      state = CalculatorEngine.inputDigit(state, '1');
      state = CalculatorEngine.inputDecimal(state);
      state = CalculatorEngine.inputDigit(state, '5');
      state = CalculatorEngine.inputDecimal(state); // ignored, already has a '.'
      state = CalculatorEngine.inputDigit(state, '2');
      expect(state.currentInput, '1.52');
    });

    test('divide by zero sets an error state instead of throwing', () {
      var state = CalculatorEngine.initial(0);
      state = CalculatorEngine.inputDigit(state, '5');
      state = CalculatorEngine.inputOperator(state, CalculatorOperator.divide);
      state = CalculatorEngine.inputDigit(state, '0');
      state = CalculatorEngine.equals(state);
      expect(state.hasError, isTrue);
      expect(state.liveValue, isNull);
      expect(state.display, 'Error');
    });

    test('typing a digit after an error clears it and starts fresh', () {
      var state = CalculatorEngine.initial(0);
      state = CalculatorEngine.inputDigit(state, '5');
      state = CalculatorEngine.inputOperator(state, CalculatorOperator.divide);
      state = CalculatorEngine.inputDigit(state, '0');
      state = CalculatorEngine.equals(state);
      expect(state.hasError, isTrue);

      state = CalculatorEngine.inputDigit(state, '7');
      expect(state.hasError, isFalse);
      expect(state.liveValue, 7);
    });

    test('empty input treats equals/operator presses as a no-op that does not crash', () {
      var state = CalculatorEngine.initial(42);
      state = CalculatorEngine.equals(state);
      expect(state.liveValue, 42);

      state = CalculatorEngine.inputOperator(state, CalculatorOperator.add);
      expect(state.liveValue, 42);
      expect(state.hasError, isFalse);
    });

    test('pressing multiple operators in a row just replaces the pending operator', () {
      var state = CalculatorEngine.initial(0);
      state = CalculatorEngine.inputDigit(state, '1');
      state = CalculatorEngine.inputDigit(state, '0');
      state = CalculatorEngine.inputOperator(state, CalculatorOperator.add);
      state = CalculatorEngine.inputOperator(state, CalculatorOperator.subtract);
      state = CalculatorEngine.inputOperator(state, CalculatorOperator.multiply);
      state = CalculatorEngine.inputDigit(state, '5');
      expect(state.pendingOperator, CalculatorOperator.multiply);
      expect(state.liveValue, 50);
    });

    test('backspace removes the last typed digit', () {
      var state = CalculatorEngine.initial(0);
      state = CalculatorEngine.inputDigit(state, '1');
      state = CalculatorEngine.inputDigit(state, '2');
      state = CalculatorEngine.inputDigit(state, '3');
      state = CalculatorEngine.backspace(state);
      expect(state.currentInput, '12');
    });

    test('backspace with nothing typed clears a pending operator', () {
      var state = CalculatorEngine.initial(10);
      state = CalculatorEngine.inputOperator(state, CalculatorOperator.add);
      expect(state.pendingOperator, CalculatorOperator.add);
      state = CalculatorEngine.backspace(state);
      expect(state.pendingOperator, isNull);
    });

    test('clear resets everything to zero', () {
      var state = CalculatorEngine.initial(999);
      state = CalculatorEngine.inputDigit(state, '5');
      state = CalculatorEngine.inputOperator(state, CalculatorOperator.add);
      state = CalculatorEngine.clear(state);
      expect(state.accumulator, 0);
      expect(state.currentInput, isEmpty);
      expect(state.pendingOperator, isNull);
      expect(state.hasError, isFalse);
    });

    test('typing a new number right after equals starts a fresh calculation', () {
      var state = CalculatorEngine.initial(0);
      state = CalculatorEngine.inputDigit(state, '5');
      state = CalculatorEngine.inputOperator(state, CalculatorOperator.add);
      state = CalculatorEngine.inputDigit(state, '5');
      state = CalculatorEngine.equals(state);
      expect(state.liveValue, 10);

      state = CalculatorEngine.inputDigit(state, '3');
      expect(state.liveValue, 3);
    });

    test('formatNumber trims trailing zeros but keeps whole numbers unadorned', () {
      expect(CalculatorEngine.formatNumber(10000), '10000');
      expect(CalculatorEngine.formatNumber(12.5), '12.5');
      expect(CalculatorEngine.formatNumber(12.50), '12.5');
      expect(CalculatorEngine.formatNumber(12.75), '12.75');
    });
  });
}
