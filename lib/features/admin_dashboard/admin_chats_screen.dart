import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/core/animations/motion.dart';
import 'package:keyframes_app/core/animations/staggered_entrance.dart';
import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/core/theme/k_text_styles.dart';
import 'package:keyframes_app/core/widgets/widgets.dart';
import 'package:keyframes_app/data/models/conversation.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/message.dart';
import 'package:keyframes_app/features/admin_dashboard/admin_controller.dart';
import 'package:keyframes_app/features/chat/chat_controller.dart';

/// The admin chats inbox (Requirements 11.4, 12.3).
///
/// Lists every client [Conversation] from [adminConversationsProvider]
/// (most-recent-first), rendering each with the client's name, a last-message
/// preview, the relative update time, and an unread badge driven by
/// [Conversation.unreadAdmin] (Requirement 12.3). Tapping a conversation opens
/// the [AdminChatThreadScreen] to reply (Requirement 11.4). Navigation uses a
/// [MaterialPageRoute] push so no app-level route wiring is required here.
class AdminChatsScreen extends ConsumerWidget {
  /// Creates the admin chats inbox screen.
  const AdminChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Conversation>> conversationsAsync =
        ref.watch(adminConversationsProvider);

    return Scaffold(
      backgroundColor: KColors.offWhite,
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: KColors.offWhite,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: conversationsAsync.when(
          data: (List<Conversation> conversations) {
            if (conversations.isEmpty) {
              return const _ChatsEmpty();
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                KSpace.lg,
                KSpace.md,
                KSpace.lg,
                KSpace.xxl,
              ),
              itemCount: conversations.length,
              itemBuilder: (BuildContext context, int index) {
                final Conversation conversation = conversations[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: KSpace.md),
                  child: StaggeredEntrance(
                    index: index,
                    child: _ConversationCard(
                      conversation: conversation,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AdminChatThreadScreen(
                            conversationId: conversation.id,
                            clientName: conversation.clientName,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const _ChatsLoading(),
          error: (Object error, StackTrace _) => KErrorView(
            message: 'We could not load conversations right now.',
            onRetry: () => ref.invalidate(adminConversationsProvider),
          ),
        ),
      ),
    );
  }
}

/// A single conversation row with an unread badge.
class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int unread = conversation.unreadAdmin;
    return KCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 24,
            backgroundColor: KColors.navy800,
            child: Text(
              _initials(conversation.clientName),
              style: KTextStyles.titleMd.copyWith(color: KColors.white),
            ),
          ),
          const SizedBox(width: KSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        conversation.clientName,
                        style: KTextStyles.titleMd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _relativeTime(conversation.updatedAt),
                      style: KTextStyles.caption,
                    ),
                  ],
                ),
                const SizedBox(height: KSpace.xs),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        conversation.lastMessage ?? 'No messages yet',
                        style: KTextStyles.bodyMd.copyWith(
                          color: KColors.slate500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unread > 0) ...<Widget>[
                      const SizedBox(width: KSpace.sm),
                      _UnreadBadge(count: unread),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small amber pill showing the admin's unread message count.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: KSpace.sm),
      decoration: BoxDecoration(
        color: KColors.amber500,
        borderRadius: BorderRadius.circular(KSpace.rPill),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: KTextStyles.caption.copyWith(
          color: KColors.navy900,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Empty state when there are no conversations yet.
class _ChatsEmpty extends StatelessWidget {
  const _ChatsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.forum_rounded,
              size: 56,
              color: KColors.slate500,
            ),
            const SizedBox(height: KSpace.lg),
            Text('No conversations yet', style: KTextStyles.headingMd),
            const SizedBox(height: KSpace.sm),
            Text(
              'Client conversations will appear here as they reach out.',
              textAlign: TextAlign.center,
              style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton while conversations load.
class _ChatsLoading extends StatelessWidget {
  const _ChatsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KSpace.lg,
        KSpace.md,
        KSpace.lg,
        KSpace.xxl,
      ),
      children: <Widget>[
        for (int i = 0; i < 5; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: KSpace.md),
            child: KShimmer.box(height: 88),
          ),
      ],
    );
  }
}

/// A lightweight admin-side conversation thread (Requirement 11.4).
///
/// Streams the messages of [conversationId] via [messagesProvider] and lets the
/// admin reply through the shared [chatControllerProvider], which uses the
/// signed-in admin's id as the message sender. The admin's own messages are
/// right-aligned navy; the client's are left-aligned. The conversation is
/// marked read for the admin on open so the inbox unread badge clears
/// (Requirement 12.3 / 12.2).
class AdminChatThreadScreen extends ConsumerStatefulWidget {
  /// Creates the admin conversation thread for [conversationId].
  const AdminChatThreadScreen({
    required this.conversationId,
    required this.clientName,
    super.key,
  });

  /// The id of the conversation being viewed/replied to.
  final String conversationId;

  /// The client's display name, shown in the app bar.
  final String clientName;

  @override
  ConsumerState<AdminChatThreadScreen> createState() =>
      _AdminChatThreadScreenState();
}

class _AdminChatThreadScreenState
    extends ConsumerState<AdminChatThreadScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _composeController = TextEditingController();
  bool _markedRead = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    // Mark read once after first frame so the admin unread badge clears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_markedRead) {
        return;
      }
      _markedRead = true;
      ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .markRead();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _composeController.dispose();
    super.dispose();
  }

  void _autoScrollOnNewMessage(int count) {
    if (count == _lastMessageCount) {
      return;
    }
    _lastMessageCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        0,
        duration: KMotion.resolve(context, KMotion.medium),
        curve: KMotion.enter,
      );
    });
  }

  Future<void> _send() async {
    final String text = _composeController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _composeController.clear();
    await ref
        .read(chatControllerProvider(widget.conversationId).notifier)
        .send(text);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Message>> messagesAsync =
        ref.watch(messagesProvider(widget.conversationId));
    final ChatState chatState =
        ref.watch(chatControllerProvider(widget.conversationId));
    final String? adminId = ref.watch(currentUserProvider)?.id;

    // Surface transient send/validation errors as a snackbar, then clear them.
    ref.listen<ChatState>(chatControllerProvider(widget.conversationId),
        (ChatState? previous, ChatState next) {
      final String? error = next.sendError;
      if (error != null && error != previous?.sendError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(error), backgroundColor: KColors.danger),
          );
        ref
            .read(chatControllerProvider(widget.conversationId).notifier)
            .clearError();
      }
    });

    return Scaffold(
      backgroundColor: KColors.offWhite,
      appBar: AppBar(
        backgroundColor: KColors.navy800,
        foregroundColor: KColors.white,
        title: Text(
          widget.clientName,
          style: KTextStyles.titleMd.copyWith(color: KColors.white),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: messagesAsync.when(
              data: (List<Message> messages) {
                _autoScrollOnNewMessage(messages.length);
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Say hello!',
                      style:
                          KTextStyles.bodyMd.copyWith(color: KColors.slate500),
                    ),
                  );
                }
                final List<Message> reversed = messages.reversed.toList();
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSpace.lg,
                    vertical: KSpace.md,
                  ),
                  itemCount: reversed.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Message message = reversed[index];
                    final bool isMine =
                        adminId != null && message.senderId == adminId;
                    return _AdminMessageBubble(
                      key: ValueKey<String>(message.id),
                      message: message,
                      isMine: isMine,
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: KColors.navy800),
              ),
              error: (Object error, StackTrace _) => KErrorView(
                message: 'Messages could not be loaded.',
                onRetry: () =>
                    ref.invalidate(messagesProvider(widget.conversationId)),
              ),
            ),
          ),
          _AdminComposeBar(
            controller: _composeController,
            sending: chatState.sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

/// A simple message bubble for the admin thread view.
class _AdminMessageBubble extends StatelessWidget {
  const _AdminMessageBubble({
    required this.message,
    required this.isMine,
    super.key,
  });

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final Color bubbleColor = isMine ? KColors.navy800 : KColors.white;
    final Color textColor = isMine ? KColors.white : KColors.slate700;
    final Alignment alignment =
        isMine ? Alignment.centerRight : Alignment.centerLeft;

    final bool isImage = message.type == MessageType.image &&
        (message.mediaUrl?.isNotEmpty ?? false);

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: KSpace.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.md,
          vertical: KSpace.sm,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.74,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(KSpace.rLg),
          boxShadow: isMine ? const <BoxShadow>[] : KSpace.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(KSpace.rMd),
                child: Image.network(
                  message.mediaUrl!,
                  width: 200,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (BuildContext context, Object _, StackTrace? __) =>
                          const SizedBox(
                    width: 200,
                    height: 140,
                    child: ColoredBox(
                      color: KColors.slate200,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: KColors.slate500,
                      ),
                    ),
                  ),
                ),
              )
            else
              Text(
                message.text ?? '',
                style: KTextStyles.bodyMd.copyWith(color: textColor),
              ),
            const SizedBox(height: KSpace.xs),
            Text(
              DateFormat('HH:mm').format(message.sentAt.toLocal()),
              style: KTextStyles.caption.copyWith(
                color: isMine ? const Color(0xB3FFFFFF) : KColors.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The admin compose bar with a text field and a send button.
class _AdminComposeBar extends StatefulWidget {
  const _AdminComposeBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  State<_AdminComposeBar> createState() => _AdminComposeBarState();
}

class _AdminComposeBarState extends State<_AdminComposeBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() {
    final bool hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canSend = _hasText && !widget.sending;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.sm,
          vertical: KSpace.sm,
        ),
        decoration: const BoxDecoration(
          color: KColors.white,
          boxShadow: KSpace.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: widget.controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  style: KTextStyles.bodyMd,
                  decoration: InputDecoration(
                    hintText: 'Reply to client…',
                    hintStyle:
                        KTextStyles.bodyMd.copyWith(color: KColors.slate500),
                    filled: true,
                    fillColor: KColors.offWhite,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: KSpace.md,
                      vertical: KSpace.sm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KSpace.rLg),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: KSpace.xs),
            Semantics(
              button: true,
              enabled: canSend,
              label: 'Send message',
              child: GestureDetector(
                onTap: canSend ? widget.onSend : null,
                child: AnimatedContainer(
                  duration: KMotion.fast,
                  width: KSpace.minTouchTarget,
                  height: KSpace.minTouchTarget,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: canSend
                        ? const LinearGradient(
                            colors: <Color>[KColors.amber400, KColors.amber500],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: canSend ? null : KColors.slate200,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.send_rounded,
                    color: canSend ? KColors.white : KColors.slate500,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Up-to-two-letter initials derived from a display name.
String _initials(String name) {
  final List<String> parts =
      name.trim().split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

/// A compact relative-time label (e.g. "now", "5m", "3h", "2d") or a date.
String _relativeTime(DateTime time) {
  final Duration diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) {
    return 'now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays}d';
  }
  return DateFormat.MMMd().format(time.toLocal());
}
