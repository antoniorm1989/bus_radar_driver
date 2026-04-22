import 'package:flutter/material.dart';

import '../../data/repositories/bus_chat_repository.dart';
import '../../domain/entities/bus_chat_message.dart';
import '../../domain/entities/bus_chat_role.dart';
import '../../domain/entities/chat_user_identity.dart';

class DriverBusChatScreen extends StatefulWidget {
  const DriverBusChatScreen({
    super.key,
    required this.busId,
    required this.busLabel,
    this.routeName,
  });

  final String busId;
  final String busLabel;
  final String? routeName;

  @override
  State<DriverBusChatScreen> createState() => _DriverBusChatScreenState();
}

class _DriverBusChatScreenState extends State<DriverBusChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();

  late final BusChatRepository _repository;
  late final Future<ChatUserIdentity> _identityFuture;

  bool _isSending = false;
  String? _pinningMessageId;
  bool _isPinnedPanelExpanded = false;

  @override
  void initState() {
    super.initState();
    _repository = BusChatRepository.live();
    _identityFuture = _repository.getCurrentIdentity();
    _messageController.addListener(_onComposerChanged);
  }

  @override
  void dispose() {
    _messageController
      ..removeListener(_onComposerChanged)
      ..dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  void _onComposerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _appendEmoji(String emoji) {
    final value = _messageController.value;
    final selection = value.selection;

    final start = selection.start >= 0 ? selection.start : value.text.length;
    final end = selection.end >= 0 ? selection.end : value.text.length;

    final updatedText = value.text.replaceRange(start, end, emoji);
    final caretOffset = start + emoji.length;

    _messageController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: caretOffset),
    );

    _composerFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChatUserIdentity>(
      future: _identityFuture,
      builder: (context, identitySnapshot) {
        final identity = identitySnapshot.data;
        final isIdentityLoading =
            identitySnapshot.connectionState == ConnectionState.waiting;
        final canPin = identity?.canPin ?? false;
        final currentUserId = identity?.userId;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF0B1A34),
            foregroundColor: Colors.white,
            centerTitle: false,
            titleSpacing: 12,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.busLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _buildHeaderSubtitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              StreamBuilder<List<BusChatMessage>>(
                stream: _repository.watchRecentMessages(widget.busId),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return _ChatContextBadge(messageCount: count);
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          backgroundColor: const Color(0xFFF3F6FB),
          body: SafeArea(
            child: Column(
              children: [
                if (identitySnapshot.hasError)
                  _ChatErrorBanner(
                    message:
                        'No se pudo validar tu identidad de chat. Reintenta en unos segundos.',
                  ),
                StreamBuilder<List<BusChatMessage>>(
                  stream: _repository.watchPinnedMessages(widget.busId),
                  builder: (context, pinnedSnapshot) {
                    final pinnedMessages = pinnedSnapshot.data ?? const <BusChatMessage>[];
                    if (pinnedMessages.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return _PinnedMessagesPanel(
                      messages: pinnedMessages,
                      canUnpinMessage: (message) {
                        if (!canPin || currentUserId == null) {
                          return false;
                        }
                        return message.userId == currentUserId;
                      },
                      pinningMessageId: _pinningMessageId,
                      isExpanded: _isPinnedPanelExpanded,
                      onToggleExpanded: () {
                        setState(
                          () => _isPinnedPanelExpanded = !_isPinnedPanelExpanded,
                        );
                      },
                      onUnpin: _togglePinned,
                    );
                  },
                ),
                Expanded(
                  child: StreamBuilder<List<BusChatMessage>>(
                    stream: _repository.watchRecentMessages(widget.busId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const _CenteredInfo(
                          icon: Icons.error_outline_rounded,
                          title: 'No se pudo cargar el chat',
                          subtitle: 'Revisa tu conexion e intenta nuevamente.',
                        );
                      }

                      final messages = snapshot.data ?? const <BusChatMessage>[];
                      if (messages.isEmpty) {
                        return const _EmptyChatState();
                      }

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMine =
                              currentUserId != null && message.userId == currentUserId;

                          return _MessageBubble(
                            message: message,
                            isMine: isMine,
                            isPinning: _pinningMessageId == message.id,
                            onLongPress: canPin && isMine
                                ? () => _showMessageActions(
                                    message,
                                    canPin: canPin,
                                  )
                                : null,
                          );
                        },
                      );
                    },
                  ),
                ),
                _QuickEmojiBar(onEmojiTap: _appendEmoji),
                _Composer(
                  controller: _messageController,
                  focusNode: _composerFocusNode,
                  isSending: _isSending,
                  isEnabled: !isIdentityLoading && identity != null,
                  onSend: _sendMessage,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildHeaderSubtitle() {
    final route = (widget.routeName ?? '').trim();
    if (route.isEmpty) {
      return 'Ruta sin nombre';
    }
    return route;
  }

  Future<void> _showMessageActions(
    BusChatMessage message, {
    required bool canPin,
  }) async {
    if (!canPin || _pinningMessageId != null) {
      return;
    }

    final selection = await showModalBottomSheet<_MessageAction>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                message.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
              ),
              title: Text(
                message.isPinned ? 'Desfijar mensaje' : 'Fijar mensaje',
              ),
              subtitle: Text(
                message.isPinned
                    ? 'Quitarlo de mensajes fijados'
                    : 'Mantenerlo visible para todos',
              ),
              onTap: () => Navigator.pop(sheetContext, _MessageAction.togglePin),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );

    if (selection == _MessageAction.togglePin) {
      await _togglePinned(message);
    }
  }

  Future<void> _togglePinned(BusChatMessage message) async {
    if (_pinningMessageId != null) {
      return;
    }

    setState(() => _pinningMessageId = message.id);

    try {
      if (message.isPinned) {
        await _repository.unpinMessage(busId: widget.busId, messageId: message.id);
      } else {
        await _repository.pinMessage(busId: widget.busId, messageId: message.id);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el anclado: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _pinningMessageId = null);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    setState(() => _isSending = true);

    try {
      await _repository.sendMessage(
        busId: widget.busId,
        text: text,
      );

      _messageController.clear();
      _composerFocusNode.requestFocus();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el mensaje: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }
}

enum _MessageAction { togglePin }

class _PinnedMessagesPanel extends StatelessWidget {
  const _PinnedMessagesPanel({
    required this.messages,
    required this.canUnpinMessage,
    required this.pinningMessageId,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onUnpin,
  });

  final List<BusChatMessage> messages;
  final bool Function(BusChatMessage message) canUnpinMessage;
  final String? pinningMessageId;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<BusChatMessage> onUnpin;

  @override
  Widget build(BuildContext context) {
    final visibleMessages = isExpanded ? messages.take(4).toList() : messages.take(1).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F9FF),
        border: Border(
          top: BorderSide(color: Color(0xFF0E5A92), width: 1.15),
          bottom: BorderSide(color: Color(0xFF0E5A92), width: 1.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.push_pin_rounded,
                    color: Color(0xFF0E5A92),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mensajes pineados (${messages.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0E4D7A),
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF0E4D7A),
                  ),
                ],
              ),
            ),
          ),
          for (final message in visibleMessages)
            _PinnedMessageTile(
              message: message,
              canUnpin: canUnpinMessage(message),
              isBusy: pinningMessageId == message.id,
              onUnpin: () => onUnpin(message),
            ),
          if (messages.length > 1 && !isExpanded)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 2, 12, 8),
              child: Text(
                'Toca para ver mas mensajes fijados',
                style: TextStyle(fontSize: 12, color: Color(0xFF3C5E82)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PinnedMessageTile extends StatelessWidget {
  const _PinnedMessageTile({
    required this.message,
    required this.canUnpin,
    required this.isBusy,
    required this.onUnpin,
  });

  final BusChatMessage message;
  final bool canUnpin;
  final bool isBusy;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final visual = _bubbleStyle(message, false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
      child: Container(
        decoration: BoxDecoration(
          color: visual.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: visual.border, width: visual.borderWidth),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SenderGlyph(
                message: message,
                isMine: false,
                compact: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _senderTitle(message),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: visual.headerColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_shouldShowOnBoardPill(message)) ...[
                          const SizedBox(width: 6),
                          const _OnBoardPill(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.text,
                      style: TextStyle(
                        fontSize: 13,
                        color: visual.textColor,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (canUnpin)
                IconButton(
                  iconSize: 20,
                  tooltip: 'Desfijar',
                  onPressed: isBusy ? null : onUnpin,
                  icon: isBusy
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: visual.headerColor,
                          ),
                        )
                      : Icon(
                          Icons.close_rounded,
                          color: visual.headerColor,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return const _CenteredInfo(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Sin mensajes',
      subtitle: 'Inicia la conversacion con pasajeros y administradores.',
    );
  }
}

class _CenteredInfo extends StatelessWidget {
  const _CenteredInfo({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 62, color: const Color(0xFF5B7188)),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFF1E3752),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF4A6078),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.isPinning,
    required this.onLongPress,
  });

  final BusChatMessage message;
  final bool isMine;
  final bool isPinning;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final visual = _bubbleStyle(message, isMine);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: IntrinsicWidth(
            child: GestureDetector(
              onLongPress: onLongPress,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: visual.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: visual.border, width: visual.borderWidth),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SenderGlyph(
                                message: message,
                                isMine: isMine,
                                compact: false,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _senderTitle(message),
                                  style: TextStyle(
                                    color: visual.headerColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_shouldShowOnBoardPill(message)) ...[
                                const SizedBox(width: 6),
                                const _OnBoardPill(),
                              ],
                              if (message.isPinned) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.push_pin_rounded,
                                  size: 14,
                                  color: visual.headerColor,
                                ),
                              ],
                              if (isPinning) ...[
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: visual.headerColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            message.text,
                            style: TextStyle(
                              color: visual.textColor,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _formatMessageTime(message.createdAt),
                        style: const TextStyle(
                          color: Color(0xFF5F7084),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatMessageTime(DateTime? createdAt) {
    if (createdAt == null) {
      return 'enviando...';
    }

    final local = createdAt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.isEnabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final bool isEnabled;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    final canSend = isEnabled && hasText && !isSending;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFDDE4EE))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: isEnabled,
              minLines: 1,
              maxLines: 4,
              maxLength: 700,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                counterText: '',
                hintText: isEnabled
                    ? 'Escribe un mensaje...'
                    : 'Esperando identidad de chat...',
              ),
              onSubmitted: (_) {
                if (canSend) {
                  onSend();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: canSend ? onSend : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(50, 50),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

class _ChatErrorBanner extends StatelessWidget {
  const _ChatErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEEEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF2CACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB3261E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8B1E18),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatContextBadge extends StatelessWidget {
  const _ChatContextBadge({required this.messageCount});

  final int messageCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF274566),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            '$messageCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickEmojiBar extends StatelessWidget {
  const _QuickEmojiBar({required this.onEmojiTap});

  final ValueChanged<String> onEmojiTap;

  static const _quickEmojis = ['🙂', '😅', '🚌', '🧊', '❄️', '🙌', '👍', '🙏'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) {
          final emoji = _quickEmojis[index];
          return InkWell(
            onTap: () => onEmojiTap(emoji),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD7DFEA)),
                borderRadius: BorderRadius.circular(999),
                color: Colors.white,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _quickEmojis.length,
      ),
    );
  }
}

class _SenderGlyph extends StatelessWidget {
  const _SenderGlyph({
    required this.message,
    required this.isMine,
    required this.compact,
  });

  final BusChatMessage message;
  final bool isMine;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon = _roleIcon(message);
    final size = compact ? 21.0 : 28.0;
    final backgroundColor = isMine ? Colors.white : const Color(0xFF0D5D97);
    final iconColor = isMine ? const Color(0xFF0D5D97) : Colors.white;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: compact ? 13 : 16,
        color: iconColor,
      ),
    );
  }
}

_StringBubbleStyle _bubbleStyle(BusChatMessage message, bool isMine) {
  if (isMine) {
    return const _StringBubbleStyle(
      background: Color(0xFF0E2E4C),
      border: Color(0xFF0E2E4C),
      borderWidth: 1.2,
      textColor: Colors.white,
      headerColor: Colors.white,
    );
  }

  if (message.role == BusChatRole.admin) {
    return const _StringBubbleStyle(
      background: Colors.white,
      border: Color(0xFF0D5D97),
      borderWidth: 2.0,
      textColor: Color(0xFF0E4D7A),
      headerColor: Color(0xFF0D5D97),
    );
  }

  return const _StringBubbleStyle(
    background: Colors.white,
    border: Color(0xFF2F7DB7),
    borderWidth: 1.1,
    textColor: Color(0xFF0E4D7A),
    headerColor: Color(0xFF0B4A75),
  );
}

String _senderTitle(BusChatMessage message) {
  if (message.isAnonymous) {
    return message.displayName;
  }

  return _ChatIdentityFormatter.shortProfileName(message.displayName);
}

IconData _roleIcon(BusChatMessage message) {
  if (message.role == BusChatRole.admin) {
    return Icons.admin_panel_settings_rounded;
  }
  if (message.role == BusChatRole.driver) {
    return Icons.directions_bus_rounded;
  }
  if (message.isAnonymous) {
    return Icons.visibility_off_rounded;
  }
  return Icons.person_rounded;
}

bool _shouldShowOnBoardPill(BusChatMessage message) {
  // Read-only display: this value is produced by passenger app at send time.
  return message.role == BusChatRole.user && message.isOnBoard == true;
}

class _OnBoardPill extends StatelessWidget {
  const _OnBoardPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
      decoration: BoxDecoration(
        color: const Color(0xFF066B57),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF20D39A), width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Color(0xFF20D39A)),
          SizedBox(width: 5),
          Text(
            'A bordo',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StringBubbleStyle {
  const _StringBubbleStyle({
    required this.background,
    required this.border,
    required this.borderWidth,
    required this.textColor,
    required this.headerColor,
  });

  final Color background;
  final Color border;
  final double borderWidth;
  final Color textColor;
  final Color headerColor;
}

class _ChatIdentityFormatter {
  static String shortProfileName(
    String rawName, {
    String fallback = 'Usuario',
  }) {
    final cleaned = rawName.trim();
    if (cleaned.isEmpty) {
      return fallback;
    }

    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return fallback;
    }

    if (words.length >= 4) {
      return '${_toNameCase(words.first)} ${_toNameCase(words[words.length - 2])}';
    }

    if (words.length >= 2) {
      return '${_toNameCase(words.first)} ${_toNameCase(words.last)}';
    }

    return _toNameCase(words.first);
  }

  static String _toNameCase(String value) {
    return value
        .split('-')
        .where((part) => part.isNotEmpty)
        .map(_capitalizeWord)
        .join('-');
  }

  static String _capitalizeWord(String word) {
    if (word.isEmpty) {
      return word;
    }

    final lower = word.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }
}
