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
  final bool? isOnBoard;
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
    required this.isOnBoard,
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
    final createdAt = createdAtRaw is Timestamp ? createdAtRaw.toDate() : null;
    final userId = (data['userId'] as String? ?? '').trim();
    final role = BusChatRole.fromDynamic(data['role']);
    final safeDisplayName = _safeDisplayName(data['displayName'] as String?);
    final isAnonymousFromData = data['isAnonymous'] == true;
    final inferredAnonymous = safeDisplayName.toLowerCase().startsWith('anon-');
    final isAnonymous = isAnonymousFromData || inferredAnonymous;
    final anonymousSourceId = userId.isNotEmpty ? userId : doc.id;
    final rawIsOnBoard = data['isOnBoard'];
    final rawPinnedByRole = data['pinnedByRole'];

    return BusChatMessage(
      id: doc.id,
      text: (data['text'] as String? ?? '').trim(),
      createdAt: createdAt,
      expiresAt: expiresAtRaw is Timestamp ? expiresAtRaw.toDate() : null,
      pinnedAt: pinnedAtRaw is Timestamp ? pinnedAtRaw.toDate() : null,
      userId: userId,
      displayName: isAnonymous
          ? _dailyAnonymousAlias(
              userId: anonymousSourceId,
              createdAt: createdAt,
            )
          : safeDisplayName,
      role: role,
      isAnonymous: isAnonymous,
      isOnBoard: role == BusChatRole.user && rawIsOnBoard is bool
          ? rawIsOnBoard
          : null,
      isPinned: data['isPinned'] == true,
      pinnedByUserId: (data['pinnedByUserId'] as String? ?? '').trim(),
      pinnedByRole:
          rawPinnedByRole is String && rawPinnedByRole.trim().isNotEmpty
          ? BusChatRole.fromDynamic(rawPinnedByRole)
          : null,
    );
  }

  static String _dailyAnonymousAlias({
    required String userId,
    required DateTime? createdAt,
  }) {
    final sourceDate = (createdAt ?? DateTime.now()).toLocal();
    final yyyy = sourceDate.year.toString().padLeft(4, '0');
    final mm = sourceDate.month.toString().padLeft(2, '0');
    final dd = sourceDate.day.toString().padLeft(2, '0');
    final seed = '$userId|$yyyy-$mm-$dd';

    var hash = 0;
    for (final code in seed.codeUnits) {
      hash = ((hash * 33) ^ code) & 0x7fffffff;
    }

    final token = hash.toRadixString(36).toUpperCase().padLeft(7, '0');
    final shortToken = token.length > 7 ? token.substring(token.length - 7) : token;
    return 'Anon-$shortToken';
  }

  static String _safeDisplayName(String? rawDisplayName) {
    final value = (rawDisplayName ?? '').trim();
    return value.isEmpty ? 'Chofer' : value;
  }
}
