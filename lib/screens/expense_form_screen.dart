import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../currency/currency_formatter.dart';
import '../models/expense.dart';
import '../models/expense_payer.dart';
import '../models/expense_share.dart';
import '../models/participant.dart';
import '../models/split_type.dart';
import '../providers/expense_providers.dart';
import '../providers/group_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/split_type_selector.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  final String groupId;
  final Expense? expense;

  const ExpenseFormScreen({super.key, required this.groupId, this.expense});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late SplitType _splitType;
  final Set<String> _selectedParticipantIds = {};
  final Map<String, TextEditingController> _customAmountControllers = {};
  final Map<String, TextEditingController> _percentageControllers = {};
  final Map<String, TextEditingController> _payerAmountControllers = {};
  bool _controllersInitialized = false;
  String? _errorText;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.expense?.title ?? '');
    _amountController = TextEditingController(
      text: widget.expense != null ? widget.expense!.totalAmount.toString() : '',
    );
    _splitType = widget.expense?.splitType ?? SplitType.equal;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    for (final c in _customAmountControllers.values) {
      c.dispose();
    }
    for (final c in _percentageControllers.values) {
      c.dispose();
    }
    for (final c in _payerAmountControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureControllers(
    List<Participant> participants,
    List<ExpensePayer> existingPayers,
    List<ExpenseShare> existingShares,
  ) {
    if (_controllersInitialized) return;
    _controllersInitialized = true;

    if (widget.expense != null) {
      _selectedParticipantIds.addAll(existingShares.map((s) => s.participantId));
    }

    final total = widget.expense?.totalAmount ?? 0;
    for (final p in participants) {
      final existingShare = existingShares.where((s) => s.participantId == p.id);
      final shareAmount = existingShare.isEmpty ? null : existingShare.first.shareAmount;
      _customAmountControllers[p.id] = TextEditingController(
        text: shareAmount != null && _splitType == SplitType.custom
            ? shareAmount.toString()
            : '',
      );
      final pct = (shareAmount != null && total > 0) ? (shareAmount * 100 / total) : null;
      _percentageControllers[p.id] = TextEditingController(
        text: pct != null && _splitType == SplitType.percentage ? _trimPercentage(pct) : '',
      );

      final existingPayer = existingPayers.where((payer) => payer.participantId == p.id);
      final paidAmount = existingPayer.isEmpty ? null : existingPayer.first.paidAmount;
      _payerAmountControllers[p.id] = TextEditingController(
        text: paidAmount != null ? paidAmount.toString() : '',
      );
    }
  }

  String _trimPercentage(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final participants = ref.watch(participantsProvider(widget.groupId));
    final existingPayers = widget.expense != null
        ? ref.watch(expensePayersProvider(widget.expense!.id))
        : const <ExpensePayer>[];
    final existingShares = widget.expense != null
        ? ref.watch(expenseSharesProvider(widget.expense!.id))
        : const <ExpenseShare>[];

    _ensureControllers(participants, existingPayers, existingShares);

    final theme = Theme.of(context);
    final totalAmount = int.tryParse(_amountController.text.trim()) ?? 0;
    final payerTotal = _payerAmountControllers.values.fold<int>(
      0,
      (sum, c) => sum + (int.tryParse(c.text.trim()) ?? 0),
    );
    final payerRemaining = totalAmount - payerTotal;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Expense' : 'Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Expense name'),
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Total amount (MMK)'),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final v = int.tryParse((value ?? '').trim());
                if (v == null) return 'Enter a valid amount';
                if (v < 0) return 'Amount cannot be negative';
                return null;
              },
            ),
            const SizedBox(height: 24),
            Text('Participants', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Who shares this expense?',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final p in participants)
                    CheckboxListTile(
                      value: _selectedParticipantIds.contains(p.id),
                      title: Text(p.name),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _selectedParticipantIds.add(p.id);
                        } else {
                          _selectedParticipantIds.remove(p.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Split type', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SplitTypeSelector(
              value: _splitType,
              onChanged: (type) => setState(() => _splitType = type),
            ),
            if (_splitType != SplitType.equal) ...[
              const SizedBox(height: 16),
              _buildSplitInputs(theme, totalAmount, participants),
            ],
            const SizedBox(height: 24),
            Text('Paid by', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              payerRemaining == 0
                  ? 'Fully allocated'
                  : payerRemaining > 0
                  ? 'Remaining to allocate: ${formatCurrency(payerRemaining)}'
                  : 'Over-allocated by ${formatCurrency(-payerRemaining)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: payerRemaining == 0 ? receiveColor : payColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    for (final p in participants)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(p.name)),
                            SizedBox(
                              width: 120,
                              child: TextFormField(
                                controller: _payerAmountControllers[p.id],
                                decoration: const InputDecoration(
                                  hintText: '0',
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.end,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 16),
              Text(_errorText!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              child: Text(_isEditing ? 'Save Changes' : 'Add Expense'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitInputs(
    ThemeData theme,
    int totalAmount,
    List<Participant> participants,
  ) {
    final selected = participants.where((p) => _selectedParticipantIds.contains(p.id)).toList();
    final isCustom = _splitType == SplitType.custom;
    final controllers = isCustom ? _customAmountControllers : _percentageControllers;

    num allocated = 0;
    for (final p in selected) {
      final raw = controllers[p.id]?.text.trim() ?? '';
      allocated += isCustom ? (int.tryParse(raw) ?? 0) : (double.tryParse(raw) ?? 0);
    }
    final target = isCustom ? totalAmount : 100;
    final remaining = target - allocated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          remaining == 0
              ? 'Fully allocated'
              : isCustom
              ? 'Remaining to allocate: ${formatCurrency(remaining.toInt())}'
              : 'Remaining: ${remaining.toStringAsFixed(remaining == remaining.roundToDouble() ? 0 : 2)}%',
          style: theme.textTheme.bodySmall?.copyWith(
            color: remaining == 0 ? receiveColor : payColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                if (selected.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('Select participants above first.'),
                  ),
                for (final p in selected)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(p.name)),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            controller: controllers[p.id],
                            decoration: InputDecoration(
                              hintText: isCustom ? '0' : '0%',
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.end,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _errorText = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedParticipantIds.isEmpty) {
      setState(() => _errorText = 'Select at least one participant.');
      return;
    }

    final participants = ref.read(participantsProvider(widget.groupId));
    final totalAmount = int.parse(_amountController.text.trim());

    final payerAmounts = <String, int>{};
    for (final p in participants) {
      final raw = _payerAmountControllers[p.id]?.text.trim() ?? '';
      final amount = raw.isEmpty ? 0 : int.tryParse(raw);
      if (amount == null) {
        setState(() => _errorText = 'Enter a valid paid amount for ${p.name}.');
        return;
      }
      if (amount > 0) payerAmounts[p.id] = amount;
    }

    Map<String, int>? customAmounts;
    Map<String, double>? percentages;
    if (_splitType == SplitType.custom) {
      customAmounts = {};
      for (final id in _selectedParticipantIds) {
        final raw = _customAmountControllers[id]?.text.trim() ?? '';
        final amount = int.tryParse(raw);
        if (amount == null) {
          setState(() => _errorText = 'Enter a valid custom amount for every selected participant.');
          return;
        }
        customAmounts[id] = amount;
      }
    } else if (_splitType == SplitType.percentage) {
      percentages = {};
      for (final id in _selectedParticipantIds) {
        final raw = _percentageControllers[id]?.text.trim() ?? '';
        final pct = double.tryParse(raw);
        if (pct == null) {
          setState(() => _errorText = 'Enter a valid percentage for every selected participant.');
          return;
        }
        percentages[id] = pct;
      }
    }

    try {
      await ref
          .read(expenseControllerProvider)
          .saveExpense(
            groupId: widget.groupId,
            expenseId: widget.expense?.id,
            title: _titleController.text,
            totalAmount: totalAmount,
            splitType: _splitType,
            payerAmounts: payerAmounts,
            participantIds: _selectedParticipantIds.toList(),
            customAmounts: customAmounts,
            percentages: percentages,
          );
      if (mounted) Navigator.pop(context);
    } on ArgumentError catch (e) {
      setState(() => _errorText = e.message?.toString() ?? e.toString());
    }
  }
}
