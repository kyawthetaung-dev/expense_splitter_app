import 'split_type.dart';

class Expense {
  final String id;
  final String groupId;
  final String title;
  final int totalAmount;
  final SplitType splitType;

  /// The percentages exactly as entered, by participant id — only set for
  /// [SplitType.percentage]. Integer shares can't be converted back to these
  /// without drift, so editing an expense reads them from here. Null on
  /// expenses saved before this field existed.
  final Map<String, double>? percentages;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The server's version number, sent back with an edit so that someone
  /// else's change in the meantime is refused rather than overwritten. Always
  /// 0 on this device, where nothing else can edit it.
  final int revision;

  const Expense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.totalAmount,
    required this.splitType,
    this.percentages,
    required this.createdAt,
    required this.updatedAt,
    this.revision = 0,
  });

  Expense copyWith({
    String? title,
    int? totalAmount,
    SplitType? splitType,
    Map<String, double>? percentages,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id,
      groupId: groupId,
      title: title ?? this.title,
      totalAmount: totalAmount ?? this.totalAmount,
      splitType: splitType ?? this.splitType,
      percentages: percentages ?? this.percentages,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      revision: revision,
    );
  }
}
