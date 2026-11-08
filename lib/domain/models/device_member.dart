/// A person who can see a crop. The creator ([isOwner]) is its only
/// administrator; everyone else is a guest who joined by setting up the same
/// GreenBox from their own account.
class DeviceMember {
  final String userId;
  final String email;
  final bool isOwner;

  /// Whether this member is the signed-in user.
  final bool isMe;

  const DeviceMember({
    required this.userId,
    required this.email,
    required this.isOwner,
    required this.isMe,
  });
}
