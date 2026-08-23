import 'split_type.dart';

class Expense {
  final String id;
  final String groupId;
  final String title;
  final int totalAmount;
  final SplitType splitType;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Expense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.totalAmount,
    required this.splitType,
    required this.createdAt,
    required this.updatedAt,
  });

  Expense copyWith({
    String? title,
    int? totalAmount,
    SplitType? splitType,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id,
      groupId: groupId,
      title: title ?? this.title,
      totalAmount: totalAmount ?? this.totalAmount,
      splitType: splitType ?? this.splitType,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
