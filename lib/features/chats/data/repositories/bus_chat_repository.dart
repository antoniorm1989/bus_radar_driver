import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/bus_chat_message.dart';
import '../../domain/entities/bus_chat_role.dart';
import '../../domain/entities/chat_user_identity.dart';

class BusChatRepository {
  BusChatRepository(this._firestore, this._auth);

  factory BusChatRepository.live() {
    return BusChatRepository(FirebaseFirestore.instance, FirebaseAuth.instance);
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _messagesCollection(String busId) {
    return _firestore.collection('busChats').doc(busId).collection('messages');
  }

  DocumentReference<Map<String, dynamic>> _chatDocument(String busId) {
    return _firestore.collection('busChats').doc(busId);
  }

  Future<ChatUserIdentity> getCurrentIdentity() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Debes iniciar sesion para usar el chat.');
    }

    final tokenResult = await user.getIdTokenResult();
    final role = BusChatRole.fromDynamic(
      tokenResult.claims?['role'],
      fallback: BusChatRole.driver,
    );

    final safeDisplayName = (user.displayName ?? '').trim().isEmpty
        ? _displayNameFromEmail(user.email)
        : user.displayName!.trim();

    return ChatUserIdentity(
      userId: user.uid,
      displayName: safeDisplayName,
      role: role,
    );
  }

  String _displayNameFromEmail(String? email) {
    final value = (email ?? '').trim();
    if (value.isEmpty) {
      return 'Chofer';
    }
    final parts = value.split('@');
    return parts.first.trim().isEmpty ? 'Chofer' : parts.first.trim();
  }

  Stream<List<BusChatMessage>> watchRecentMessages(
    String busId, {
    int limit = 50,
  }) {
    return _messagesCollection(busId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map(BusChatMessage.fromDocument)
              .where((message) => message.text.isNotEmpty)
              .toList();

          messages.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          return messages;
        });
  }

  Stream<List<BusChatMessage>> watchPinnedMessages(String busId) {
    return _messagesCollection(
      busId,
    ).where('isPinned', isEqualTo: true).limit(30).snapshots().map((snapshot) {
      final messages = snapshot.docs
          .map(BusChatMessage.fromDocument)
          .where((message) => message.text.isNotEmpty)
          .toList();

      messages.sort((a, b) {
        final aTime =
            a.pinnedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.pinnedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return messages;
    });
  }

  Future<void> sendMessage({
    required String busId,
    required String text,
  }) async {
    final safeText = text.trim();
    if (safeText.isEmpty) {
      return;
    }

    if (safeText.length > 700) {
      throw ArgumentError('El mensaje no puede exceder 700 caracteres.');
    }

    final identity = await getCurrentIdentity();

    // Driver chat never computes or writes isOnBoard; passenger app owns that snapshot.
    await _messagesCollection(busId).add({
      'text': safeText,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().toUtc().add(const Duration(hours: 24)),
      ),
      'userId': identity.userId,
      'displayName': identity.displayName,
      'role': identity.role.value,
      'isAnonymous': false,
      'isPinned': false,
    });
  }

  Future<void> pinMessage({
    required String busId,
    required String messageId,
  }) async {
    final identity = await getCurrentIdentity();
    if (!identity.canPin) {
      throw StateError('No tienes permisos para fijar mensajes.');
    }

    final chatRef = _chatDocument(busId);
    final targetMessageRef = _messagesCollection(busId).doc(messageId);
    final targetSnapshot = await targetMessageRef.get();
    if (!targetSnapshot.exists) {
      throw StateError('No se encontro el mensaje para fijar.');
    }

    final previouslyPinned = await _messagesCollection(
      busId,
    ).where('isPinned', isEqualTo: true).limit(20).get();

    final batch = _firestore.batch();
    for (final doc in previouslyPinned.docs) {
      final data = doc.data();
      final rawPinnedByRole = (data['pinnedByRole'] as String? ?? '').trim();
      final sameRole =
          rawPinnedByRole.isEmpty ||
          BusChatRole.fromDynamic(rawPinnedByRole) == identity.role;

      if (doc.id != messageId && sameRole) {
        batch.set(doc.reference, {
          'isPinned': false,
          'pinnedByRole': FieldValue.delete(),
          'pinnedByUserId': FieldValue.delete(),
          'pinnedAt': FieldValue.delete(),
        }, SetOptions(merge: true));
      }
    }

    batch.set(targetMessageRef, {
      'isPinned': true,
      'pinnedByRole': identity.role.value,
      'pinnedByUserId': identity.userId,
      'pinnedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(chatRef, {
      'pinnedMessageId': messageId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> unpinMessage({
    required String busId,
    required String messageId,
  }) async {
    final identity = await getCurrentIdentity();
    if (!identity.canPin) {
      throw StateError('No tienes permisos para desfijar mensajes.');
    }

    final chatRef = _chatDocument(busId);
    final messageRef = _messagesCollection(busId).doc(messageId);
    final messageSnapshot = await messageRef.get();
    final chatSnapshot = await chatRef.get();

    final batch = _firestore.batch();
    if (messageSnapshot.exists) {
      batch.set(messageRef, {
        'isPinned': false,
        'pinnedByRole': FieldValue.delete(),
        'pinnedByUserId': FieldValue.delete(),
        'pinnedAt': FieldValue.delete(),
      }, SetOptions(merge: true));
    }

    final pinnedMessageId = chatSnapshot.data()?['pinnedMessageId'];
    final shouldDeleteLegacyPinnedId = pinnedMessageId == messageId;

    batch.set(chatRef, {
      if (shouldDeleteLegacyPinnedId) 'pinnedMessageId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
