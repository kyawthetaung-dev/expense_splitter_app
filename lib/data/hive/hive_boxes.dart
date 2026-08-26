import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../models/expense.dart';
import '../../models/expense_payer.dart';
import '../../models/expense_share.dart';
import '../../models/group.dart';
import '../../models/group_participant.dart';
import '../../models/participant.dart';
import '../../models/settlement.dart';
import 'expense_adapter.dart';
import 'expense_payer_adapter.dart';
import 'expense_share_adapter.dart';
import 'group_adapter.dart';
import 'group_participant_adapter.dart';
import 'hive_type_ids.dart';
import 'participant_adapter.dart';
import 'settlement_adapter.dart';
import 'settlement_status_adapter.dart';
import 'split_type_adapter.dart';

class HiveBoxes {
  static const groups = 'groups';
  static const participants = 'participants';
  static const groupParticipants = 'groupParticipants';
  static const expenses = 'expenses';
  static const expensePayers = 'expensePayers';
  static const expenseShares = 'expenseShares';
  static const settlements = 'settlements';

  static bool _initialized = false;

  static void _registerAdapters() {
    _registerIfNeeded(HiveTypeIds.group, GroupAdapter());
    _registerIfNeeded(HiveTypeIds.participant, ParticipantAdapter());
    _registerIfNeeded(HiveTypeIds.expense, ExpenseAdapter());
    _registerIfNeeded(HiveTypeIds.expensePayer, ExpensePayerAdapter());
    _registerIfNeeded(HiveTypeIds.expenseShare, ExpenseShareAdapter());
    _registerIfNeeded(HiveTypeIds.settlement, SettlementAdapter());
    _registerIfNeeded(HiveTypeIds.splitType, SplitTypeAdapter());
    _registerIfNeeded(HiveTypeIds.settlementStatus, SettlementStatusAdapter());
    _registerIfNeeded(HiveTypeIds.groupParticipant, GroupParticipantAdapter());
  }

  static void _registerIfNeeded<T>(int typeId, TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(typeId)) {
      Hive.registerAdapter(adapter);
    }
  }

  static Future<void> _openBoxes() async {
    await Future.wait([
      Hive.openBox<Group>(groups),
      Hive.openBox<Participant>(participants),
      Hive.openBox<GroupParticipant>(groupParticipants),
      Hive.openBox<Expense>(expenses),
      Hive.openBox<ExpensePayer>(expensePayers),
      Hive.openBox<ExpenseShare>(expenseShares),
      Hive.openBox<Settlement>(settlements),
    ]);
  }

  /// Registers all TypeAdapters and opens every box, storing data under the
  /// platform's application-documents directory. Safe to call more than
  /// once — a second call is a no-op.
  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _registerAdapters();
    await _openBoxes();
    _initialized = true;
  }

  /// Test-only: closes any currently open boxes, points Hive at [path]
  /// (e.g. a fresh temp dir), and reopens all boxes there, giving each test
  /// a clean, isolated store. Bypasses `initFlutter`'s `path_provider`
  /// platform channel, which isn't available under plain `flutter test`.
  static Future<void> initForTest(String path) async {
    await Hive.close();
    Hive.init(path);
    _registerAdapters();
    await _openBoxes();
    _initialized = true;
  }

  static Box<Group> get groupsBox => Hive.box<Group>(groups);
  static Box<Participant> get participantsBox =>
      Hive.box<Participant>(participants);
  static Box<GroupParticipant> get groupParticipantsBox =>
      Hive.box<GroupParticipant>(groupParticipants);
  static Box<Expense> get expensesBox => Hive.box<Expense>(expenses);
  static Box<ExpensePayer> get expensePayersBox =>
      Hive.box<ExpensePayer>(expensePayers);
  static Box<ExpenseShare> get expenseSharesBox =>
      Hive.box<ExpenseShare>(expenseShares);
  static Box<Settlement> get settlementsBox => Hive.box<Settlement>(settlements);
}
