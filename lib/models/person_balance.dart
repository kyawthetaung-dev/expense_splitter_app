enum BalanceStatus { receive, pay, settled }

class PersonBalance {
  final String participantId;
  final int totalShare;
  final int totalPaid;
  final int balance;
  final BalanceStatus status;

  const PersonBalance({
    required this.participantId,
    required this.totalShare,
    required this.totalPaid,
    required this.balance,
    required this.status,
  });
}
