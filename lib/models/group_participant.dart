/// Join row linking a common [Participant] to a [Group] they're a member
/// of. A participant may have many of these rows (one per group they
/// belong to); a group may have many too (one per member).
class GroupParticipant {
  final String id;
  final String groupId;
  final String participantId;

  const GroupParticipant({
    required this.id,
    required this.groupId,
    required this.participantId,
  });
}
