import 'bus_chat_role.dart';

class ChatUserIdentity {
  final String userId;
  final String displayName;
  final BusChatRole role;

  const ChatUserIdentity({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  bool get canPin => role.canPin;
}
