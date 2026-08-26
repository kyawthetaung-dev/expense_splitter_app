/// Single source of truth for every Hive `typeId`. Hive requires global
/// uniqueness (0-223) across the whole app — add new entries here only,
/// never reuse or renumber an existing id once data has been persisted
/// with it.
class HiveTypeIds {
  static const group = 0;
  static const participant = 1;
  static const expense = 2;
  static const expensePayer = 3;
  static const expenseShare = 4;
  static const settlement = 5;
  static const splitType = 6;
  static const settlementStatus = 7;
  static const groupParticipant = 8;
}
