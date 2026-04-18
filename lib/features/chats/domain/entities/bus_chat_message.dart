import 'package:cloud_firestore/cloud_firestore.dart';

import 'bus_chat_role.dart';

class BusChatMessage {
  final String id;
  final String text;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? pinnedAt;
  final String userId;
  final String displayName;
  final BusChatRole role;
  final bool isAnonymous;
  final bool isPinned;
  final String pinnedByUserId;
  final BusChatRole? pinnedByRole;

  const BusChatMessage({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.expiresAt,
    required this.pinnedAt,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.isAnonymous,
    required this.isPinned,
    required this.pinnedByUserId,
    required this.pinnedByRole,
  });

  factory BusChatMessage.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    final createdAtRaw = data['createdAt'];
    final expiresAtRaw = data['expiresAt'];
    final pinnedAtRaw = data['pinnedAt'];
    final safeDisplayName = _safeDisplayName(data['displayName'] as String?);
    final isAnonymousFromData = data['isAnonymous'] == true;
    final inferredAnonymous = safeDisplayName.toLowerCase().startsWith('anon-');
    final rawPinnedByRole = data['pinnedByRole'];

    return BusChatMessage(
      id: doc.id,
      text: (data['text'] as String? ?? '').trim(),
      createdAt: createdAtRaw is Timestamp ? createdAtRaw.toDate() : null,
      expiresAt: expiresAtRaw is Timestamp ? expiresAtRaw.toDate() : null,
      pinnedAt: pinnedAtRaw is Timestamp ? pinnedAtRaw.toDate() : null,
      userId: (data['userId'] as String? ?? '').trim(),
      displayName: safeDisplayName,
      role: BusChatRole.fromDynamic(data['role']),
      isAnonymous: isAnonymousFromData || inferredAnonymous,
      isPinned: data['isPinned'] == true,
      pinnedByUserId: (data['pinnedByUserId'] as String? ?? '').trim(),
      pinnedByRole:
          rawPinnedByRole is String && rawPinnedByRole.trim().isNotEmpty
          ? BusChatRole.fromDynamic(rawPinnedByRole)
          : null,
    );
  }

  static String _safeDisplayName(String? rawDisplayName) {
    final value = (rawDisplayName ?? '').trim();
    return value.isEmpty ? 'Chofer' : value;
  }
}
