/// A pure, reducer-style engine for a classic 4-function calculator (not an
/// expression-string parser) — the amount calculator dialog is the only
/// consumer, but keeping the arithmetic here (no Flutter dependency) makes
/// it independently unit-testable, matching this app's other pure
/// calculation services.
enum CalculatorOperator { add, subtract, multiply, divide }

class CalculatorState {
  /// The last committed running total.
  final double accumulator;

  /// The operator awaiting a second operand, if any.
  final CalculatorOperator? pendingOperator;

  /// Raw text of the operand currently being typed. Empty when nothing has
  /// been typed since the last operator/equals/clear.
  final String currentInput;

  /// Set by [CalculatorEngine.inputOperator]/[CalculatorEngine.equals] when
  /// committing would divide by zero. Digit input clears it and starts a
  /// fresh entry.
  final bool hasError;

  const CalculatorState({
    this.accumulator = 0,
    this.pendingOperator,
    this.currentInput = '',
    this.hasError = false,
  });

  CalculatorState copyWith({
    double? accumulator,
    CalculatorOperator? pendingOperator,
    bool clearPendingOperator = false,
    String? currentInput,
    bool? hasError,
  }) {
    return CalculatorState(
      accumulator: accumulator ?? this.accumulator,
      pendingOperator: clearPendingOperator
          ? null
          : (pendingOperator ?? this.pendingOperator),
      currentInput: currentInput ?? this.currentInput,
      hasError: hasError ?? this.hasError,
    );
  }

  /// The best current running total for real-time sync — `null` only while
  /// [hasError], or if the operand being typed would divide by zero (a
  /// non-destructive preview: the underlying committed state isn't marked
  /// as an error until an operator/equals is actually pressed, so the user
  /// can keep typing to fix it, e.g. "0" then ".5").
  double? get liveValue {
    if (hasError) return null;
    if (currentInput.isEmpty) return accumulator;
    final typed = double.tryParse(currentInput) ?? 0;
    if (pendingOperator == null) return typed;
    return CalculatorEngine._apply(accumulator, pendingOperator!, typed);
  }

  /// What the dialog's display should show.
  String get display {
    if (hasError) return 'Error';
    if (currentInput.isNotEmpty) return currentInput;
    return CalculatorEngine.formatNumber(accumulator);
  }
}

class CalculatorEngine {
  const CalculatorEngine._();

  static CalculatorState initial(double seed) => CalculatorState(accumulator: seed);

  static CalculatorState inputDigit(CalculatorState state, String digit) {
    if (state.hasError) {
      return CalculatorState(currentInput: digit);
    }
    if (state.currentInput == '0') {
      return state.copyWith(currentInput: digit);
    }
    return state.copyWith(currentInput: state.currentInput + digit);
  }

  static CalculatorState inputDecimal(CalculatorState state) {
    if (state.hasError) {
      return const CalculatorState(currentInput: '0.');
    }
    // Multiple decimal points are invalid — ignore the extra press rather
    // than producing an unparsable operand.
    if (state.currentInput.contains('.')) return state;
    final next = state.currentInput.isEmpty ? '0.' : '${state.currentInput}.';
    return state.copyWith(currentInput: next);
  }

  static CalculatorState backspace(CalculatorState state) {
    if (state.hasError) return const CalculatorState();
    if (state.currentInput.isNotEmpty) {
      return state.copyWith(
        currentInput: state.currentInput.substring(
          0,
          state.currentInput.length - 1,
        ),
      );
    }
    if (state.pendingOperator != null) {
      return state.copyWith(clearPendingOperator: true);
    }
    return state;
  }

  static CalculatorState clear(CalculatorState state) => const CalculatorState();

  /// Pressing an operator repeatedly (or right after another operator, with
  /// no new digits typed) just replaces the pending operator rather than
  /// erroring — standard calculator behavior for "multiple operators".
  static CalculatorState inputOperator(
    CalculatorState state,
    CalculatorOperator op,
  ) {
    if (state.hasError) return state;

    if (state.currentInput.isEmpty) {
      return state.copyWith(pendingOperator: op);
    }

    final typed = double.tryParse(state.currentInput) ?? 0;
    if (state.pendingOperator == null) {
      return CalculatorState(accumulator: typed, pendingOperator: op);
    }

    final result = _apply(state.accumulator, state.pendingOperator!, typed);
    if (result == null) {
      return const CalculatorState(hasError: true);
    }
    return CalculatorState(accumulator: result, pendingOperator: op);
  }

  static CalculatorState equals(CalculatorState state) {
    if (state.hasError) return state;

    if (state.pendingOperator == null) {
      if (state.currentInput.isEmpty) return state;
      final typed = double.tryParse(state.currentInput) ?? 0;
      return CalculatorState(accumulator: typed);
    }

    final typed = state.currentInput.isEmpty
        ? state.accumulator
        : double.tryParse(state.currentInput) ?? 0;
    final result = _apply(state.accumulator, state.pendingOperator!, typed);
    if (result == null) {
      return const CalculatorState(hasError: true);
    }
    return CalculatorState(accumulator: result);
  }

  static double? _apply(double a, CalculatorOperator op, double b) {
    switch (op) {
      case CalculatorOperator.add:
        return a + b;
      case CalculatorOperator.subtract:
        return a - b;
      case CalculatorOperator.multiply:
        return a * b;
      case CalculatorOperator.divide:
        if (b == 0) return null;
        return a / b;
    }
  }

  static String formatNumber(double value) {
    if (value.isNaN || value.isInfinite) return 'Error';
    if (value == value.truncateToDouble()) {
      return value.truncate().toString();
    }
    var text = value.toStringAsFixed(2);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    return text;
  }
}
