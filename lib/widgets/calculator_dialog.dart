import 'package:flutter/material.dart';

import '../currency/currency_formatter.dart';
import '../services/calculator_engine.dart';

/// Opens the amount calculator. [onChanged] fires immediately after every
/// keypress that produces a valid running total (rounded to the nearest
/// whole minor unit — the single rounding point for the whole feature), so
/// the caller's Total Amount field stays in real-time sync with no
/// copy/paste required. It does NOT fire while the calculator is showing an
/// error (e.g. divide by zero) — the caller's last good value is left
/// alone. Cancelling explicitly reverts to [initialValue]; any other way of
/// dismissing the dialog (Done, tapping outside, back button) intentionally
/// keeps the live-applied value, since every keystroke already synced it.
Future<void> showCalculatorDialog({
  required BuildContext context,
  required int initialValue,
  required ValueChanged<int> onChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => CalculatorDialog(
      initialValue: initialValue,
      onChanged: onChanged,
    ),
  );
}

class CalculatorDialog extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int> onChanged;

  const CalculatorDialog({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<CalculatorDialog> {
  late CalculatorState _state = CalculatorEngine.initial(
    widget.initialValue.toDouble(),
  );

  void _update(CalculatorState Function(CalculatorState) transform) {
    setState(() => _state = transform(_state));
    final live = _state.liveValue;
    if (live != null) {
      widget.onChanged(live.round());
    }
  }

  void _cancel() {
    widget.onChanged(widget.initialValue);
    Navigator.pop(context);
  }

  String get _expressionLine {
    if (_state.pendingOperator == null) return '';
    final opSymbol = switch (_state.pendingOperator!) {
      CalculatorOperator.add => '+',
      CalculatorOperator.subtract => '−',
      CalculatorOperator.multiply => '×',
      CalculatorOperator.divide => '÷',
    };
    return '${formatCurrency(_state.accumulator.round())} $opSymbol';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.calculate_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Calculator', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel',
                    onPressed: _cancel,
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _expressionLine,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _state.display,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _state.hasError ? theme.colorScheme.error : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buttonRow([
                _CalcButtonSpec('C', flex: 1, onTap: () => _update(CalculatorEngine.clear), kind: _CalcButtonKind.utility),
                _CalcButtonSpec('⌫', flex: 1, onTap: () => _update(CalculatorEngine.backspace), kind: _CalcButtonKind.utility),
                _CalcButtonSpec('÷', flex: 1, onTap: () => _update((s) => CalculatorEngine.inputOperator(s, CalculatorOperator.divide)), kind: _CalcButtonKind.operator),
                _CalcButtonSpec('×', flex: 1, onTap: () => _update((s) => CalculatorEngine.inputOperator(s, CalculatorOperator.multiply)), kind: _CalcButtonKind.operator),
              ]),
              _buttonRow([
                _digit('7'),
                _digit('8'),
                _digit('9'),
                _CalcButtonSpec('−', flex: 1, onTap: () => _update((s) => CalculatorEngine.inputOperator(s, CalculatorOperator.subtract)), kind: _CalcButtonKind.operator),
              ]),
              _buttonRow([
                _digit('4'),
                _digit('5'),
                _digit('6'),
                _CalcButtonSpec('+', flex: 1, onTap: () => _update((s) => CalculatorEngine.inputOperator(s, CalculatorOperator.add)), kind: _CalcButtonKind.operator),
              ]),
              _buttonRow([
                _digit('1'),
                _digit('2'),
                _digit('3'),
                _CalcButtonSpec('=', flex: 1, onTap: () => _update(CalculatorEngine.equals), kind: _CalcButtonKind.equals),
              ]),
              _buttonRow([
                _CalcButtonSpec('0', flex: 3, onTap: () => _update((s) => CalculatorEngine.inputDigit(s, '0')), kind: _CalcButtonKind.digit),
                _CalcButtonSpec('.', flex: 1, onTap: () => _update(CalculatorEngine.inputDecimal), kind: _CalcButtonKind.digit),
              ]),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancel,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Use amount'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _CalcButtonSpec _digit(String label) => _CalcButtonSpec(
    label,
    flex: 1,
    onTap: () => _update((s) => CalculatorEngine.inputDigit(s, label)),
    kind: _CalcButtonKind.digit,
  );

  Widget _buttonRow(List<_CalcButtonSpec> specs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (final spec in specs)
            Expanded(
              flex: spec.flex,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _CalcButton(spec: spec),
              ),
            ),
        ],
      ),
    );
  }
}

enum _CalcButtonKind { digit, operator, equals, utility }

class _CalcButtonSpec {
  final String label;
  final int flex;
  final VoidCallback onTap;
  final _CalcButtonKind kind;

  const _CalcButtonSpec(
    this.label, {
    required this.flex,
    required this.onTap,
    required this.kind,
  });
}

class _CalcButton extends StatelessWidget {
  final _CalcButtonSpec spec;
  const _CalcButton({required this.spec});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = SizedBox(
      height: 48,
      child: Center(
        child: Text(spec.label, style: theme.textTheme.titleMedium),
      ),
    );

    switch (spec.kind) {
      case _CalcButtonKind.digit:
        return FilledButton.tonal(
          onPressed: spec.onTap,
          style: FilledButton.styleFrom(padding: EdgeInsets.zero),
          child: child,
        );
      case _CalcButtonKind.operator:
        return FilledButton.tonal(
          onPressed: spec.onTap,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: theme.colorScheme.secondaryContainer,
          ),
          child: child,
        );
      case _CalcButtonKind.equals:
        return FilledButton(
          onPressed: spec.onTap,
          style: FilledButton.styleFrom(padding: EdgeInsets.zero),
          child: child,
        );
      case _CalcButtonKind.utility:
        return OutlinedButton(
          onPressed: spec.onTap,
          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
          child: child,
        );
    }
  }
}
