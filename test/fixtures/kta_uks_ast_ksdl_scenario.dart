import 'package:expense_splitter_app/models/expense.dart';
import 'package:expense_splitter_app/models/expense_payer.dart';
import 'package:expense_splitter_app/models/expense_share.dart';
import 'package:expense_splitter_app/models/group.dart';
import 'package:expense_splitter_app/models/participant.dart';
import 'package:expense_splitter_app/models/split_type.dart';

/// The canonical scenario from the product spec: KTA / UKS / AST / KSDL
/// split three expenses, with KSDL fronting most of the money. Every
/// calculator test asserts against the exact numbers given in the spec.
class KtaUksAstKsdlScenario {
  static const kta = 'kta';
  static const uks = 'uks';
  static const ast = 'ast';
  static const ksdl = 'ksdl';

  static final group = Group(
    id: 'g1',
    name: 'Weekend Trip',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  static const participants = [
    Participant(id: kta, name: 'KTA'),
    Participant(id: uks, name: 'UKS'),
    Participant(id: ast, name: 'AST'),
    Participant(id: ksdl, name: 'KSDL'),
  ];

  static final swimmingPool = Expense(
    id: 'e-pool',
    groupId: 'g1',
    title: 'Swimming Pool',
    totalAmount: 30000,
    splitType: SplitType.equal,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
  static final bbq = Expense(
    id: 'e-bbq',
    groupId: 'g1',
    title: 'BBQ',
    totalAmount: 8500,
    splitType: SplitType.equal,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
  static final gAndG = Expense(
    id: 'e-gg',
    groupId: 'g1',
    title: 'G&G',
    totalAmount: 19600,
    splitType: SplitType.equal,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  static final expenses = [swimmingPool, bbq, gAndG];

  /// Swimming Pool participants exclude KSDL.
  static const swimmingPoolParticipantIds = [kta, uks, ast];
  static const allParticipantIds = [kta, uks, ast, ksdl];

  /// Ground-truth shares, entered by hand from the spec (not computed via
  /// the calculator under test) so calculator tests aren't circular.
  static const shares = [
    // Swimming Pool: 30,000 / 3 = 10,000 each; KSDL excluded.
    ExpenseShare(id: 's1', expenseId: 'e-pool', participantId: kta, shareAmount: 10000),
    ExpenseShare(id: 's2', expenseId: 'e-pool', participantId: uks, shareAmount: 10000),
    ExpenseShare(id: 's3', expenseId: 'e-pool', participantId: ast, shareAmount: 10000),
    // BBQ: 8,500 / 4 = 2,125 each.
    ExpenseShare(id: 's4', expenseId: 'e-bbq', participantId: kta, shareAmount: 2125),
    ExpenseShare(id: 's5', expenseId: 'e-bbq', participantId: uks, shareAmount: 2125),
    ExpenseShare(id: 's6', expenseId: 'e-bbq', participantId: ast, shareAmount: 2125),
    ExpenseShare(id: 's7', expenseId: 'e-bbq', participantId: ksdl, shareAmount: 2125),
    // G&G: 19,600 / 4 = 4,900 each.
    ExpenseShare(id: 's8', expenseId: 'e-gg', participantId: kta, shareAmount: 4900),
    ExpenseShare(id: 's9', expenseId: 'e-gg', participantId: uks, shareAmount: 4900),
    ExpenseShare(id: 's10', expenseId: 'e-gg', participantId: ast, shareAmount: 4900),
    ExpenseShare(id: 's11', expenseId: 'e-gg', participantId: ksdl, shareAmount: 4900),
  ];

  /// Payers, chosen so each expense's payers sum to its own total (the
  /// invariant the app enforces), and so aggregate totals match the spec's
  /// stated paid amounts (KSDL=53,100, KTA=5,000, UKS=AST=0). KSDL paying
  /// for Swimming Pool while not being one of its share-participants
  /// deliberately exercises the "payer not included in this expense's
  /// participants" edge case.
  static const payers = [
    ExpensePayer(id: 'p1', expenseId: 'e-pool', participantId: ksdl, paidAmount: 30000),
    ExpensePayer(id: 'p2', expenseId: 'e-bbq', participantId: kta, paidAmount: 5000),
    ExpensePayer(id: 'p3', expenseId: 'e-bbq', participantId: ksdl, paidAmount: 3500),
    ExpensePayer(id: 'p4', expenseId: 'e-gg', participantId: ksdl, paidAmount: 19600),
  ];

  // Expected results, straight from the spec — for reference in tests.
  static const expectedShareTotals = {kta: 17025, uks: 17025, ast: 17025, ksdl: 7025};
  static const expectedPaidTotals = {kta: 5000, uks: 0, ast: 0, ksdl: 53100};
  static const expectedBalances = {kta: -12025, uks: -17025, ast: -17025, ksdl: 46075};
}
