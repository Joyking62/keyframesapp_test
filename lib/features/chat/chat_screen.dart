import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/core/animations/motion.dart';
import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/core/theme/k_text_styles.dart';
import 'package:keyframes_app/core/widgets/widgets.dart';
import 'package:keyframes_app/data/models/conversation.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/message.dart';
import 'package:keyframes_app/features/chat/chat_controller.dart';

/// The client <-> company chat portal screen (Requirement 9).
///
/// Resolves the single [Conversation] for the signed-in client via
/// [conversationProvider] (the company is presented as one entity), streams its
/// messages live via [messagesProvider], and renders them as bubbles: the
/// client's own messages are right-aligned amber, the company/admin's are
/// left-aligned navy (Requirement 9.3). Each bubble shows a timestamp, image
/// previews for image messages, and read-receipt checkmarks on the client's own
/// messages. New bubbles animate in with a scale-and-fade entrance and the list
/// auto-scrolls to the latest message (Requirement 9.7).
///
/// The bottom input bar composes text (send is disabled until the field is
/// non-empty, Requirement 9.4) and picks images via `image_picker`; an image is
/// uploaded through the repository and, on failure, shown with a retry control
/// (Requirements 9.5, 9.8). The conversation is marked read on open
/// (Requirement 12.2).
class ChatScreen extends ConsumerStatefulWidget {
  /// Creates the chat portal screen.
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _markedRead = false;
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Marks the conversation read once, after it first resolves.
  void _markReadOnce(String conversationId) {
    if (_markedRead) {
      return;
    }
    _markedRead = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider(conversationId).notifier).markRead();
    });
  }

  /// Auto-scrolls to the latest message when the message count grows
  /// (Requirement 9.7). With a reversed list, the latest message sits at scroll
  /// offset 0 (the bottom), so we animate back to 0.
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

  Future<void> _pickAndSendImage(String conversationId) async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) {
      return;
    }
    final Uint8List data = await picked.readAsBytes();
    await ref.read(chatControllerProvider(conversationId).notifier).sendImage(
          fileName: picked.name,
          data: data,
          contentType: _inferImageContentType(picked.name),
        );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Conversation> conversationAsync =
        ref.watch(conversationProvider);
    final String? currentUserId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      backgroundColor: KColors.offWhite,
      appBar: AppBar(
        backgroundColor: KColors.navy800,
        foregroundColor: KColors.white,
        title: Row(
          children: <Widget>[
            const CircleAvatar(
              radius: 18,
              backgroundColor: KColors.amber500,
              child: Icon(Icons.support_agent_rounded, color: KColors.navy900),
            ),
            const SizedBox(width: KSpace.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Keyframes Team',
                  style: KTextStyles.titleMd.copyWith(color: KColors.white),
                ),
                Text(
                  'Typically replies within a few hours',
                  style: KTextStyles.caption.copyWith(
                    color: const Color(0xD9FFFFFF),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: conversationAsync.when(
        data: (Conversation conversation) {
          _markReadOnce(conversation.id);
          return _ChatBody(
            conversation: conversation,
            currentUserId: currentUserId,
            scrollController: _scrollController,
            onNewMessageCount: _autoScrollOnNewMessage,
            onPickImage: () => _pickAndSendImage(conversation.id),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: KColors.navy800),
        ),
        error: (Object error, StackTrace _) => KErrorView(
          message: 'We could not open your conversation right now.',
          onRetry: () => ref.invalidate(conversationProvider),
        ),
      ),
    );
  }
}

/// The body once a [Conversation] is resolved: the live message list plus the
/// attachment status strip, typing indicator, and the compose bar.
class _ChatBody extends ConsumerWidget {
  const _ChatBody({
    required this.conversation,
    required this.currentUserId,
    required this.scrollController,
    required this.onNewMessageCount,
    required this.onPickImage,
  });

  final Conversation conversation;
  final String? currentUserId;
  final ScrollController scrollController;
  final ValueChanged<int> onNewMessageCount;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Message>> messagesAsync =
        ref.watch(messagesProvider(conversation.id));
    final ChatState chatState =
        ref.watch(chatControllerProvider(conversation.id));

    // Surface transient send/validation errors as a snackbar, then clear them.
    ref.listen<ChatState>(chatControllerProvider(conversation.id),
        (ChatState? previous, ChatState next) {
      final String? error = next.sendError;
      if (error != null && error != previous?.sendError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: KColors.danger,
            ),
          );
        ref.read(chatControllerProvider(conversation.id).notifier).clearError();
      }
    });

    return Column(
      children: <Widget>[
        Expanded(
          child: messagesAsync.when(
            data: (List<Message> messages) {
              onNewMessageCount(messages.length);
              if (messages.isEmpty) {
                return const _EmptyConversation();
              }
              // Reversed list: newest at the bottom, scroll offset 0 == bottom.
              final List<Message> reversed = messages.reversed.toList();
              return ListView.builder(
                controller: scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpace.lg,
                  vertical: KSpace.md,
                ),
                itemCount: reversed.length,
                itemBuilder: (BuildContext context, int index) {
                  final Message message = reversed[index];
                  final bool isMine = currentUserId != null &&
                      message.senderId == currentUserId;
                  return _MessageBubble(
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
              onRetry: () => ref.invalidate(messagesProvider(conversation.id)),
            ),
          ),
        ),
        // Typing indicator placeholder (Requirement 9.3). Wired to a live
        // presence/typing signal in a later pass; hidden by default.
        const _TypingIndicator(visible: false),
        if (chatState.attachment != null)
          _AttachmentStatusBar(
            attachment: chatState.attachment!,
            onRetry: () => ref
                .read(chatControllerProvider(conversation.id).notifier)
                .retryAttachment(),
            onCancel: () => ref
                .read(chatControllerProvider(conversation.id).notifier)
                .cancelAttachment(),
          ),
        _ComposeBar(
          sending: chatState.sending,
          onSend: (String text) => ref
              .read(chatControllerProvider(conversation.id).notifier)
              .send(text),
          onPickImage: onPickImage,
        ),
      ],
    );
  }
}

/// A single chat message bubble with a scale-and-fade entrance animation
/// (Requirement 9.7). Client (own) messages are right-aligned amber; the
/// company/admin's are left-aligned navy (Requirement 9.3).
class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    super.key,
  });

  final Message message;
  final bool isMine;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: KMotion.fast,
  );
  late final Animation<double> _curved =
      CurvedAnimation(parent: _controller, curve: KMotion.enter);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    // Reduced motion: appear instantly; otherwise play the scale+fade entrance.
    // MediaQuery (via KMotion.isDisabled) must be read here, not in initState.
    if (KMotion.isDisabled(context)) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMine = widget.isMine;
    final Color bubbleColor = isMine ? KColors.amber500 : KColors.navy800;
    final Color textColor = isMine ? KColors.navy900 : KColors.white;
    final Alignment alignment =
        isMine ? Alignment.centerRight : Alignment.centerLeft;

    return ScaleTransition(
      scale: Tween<double>(begin: 0.85, end: 1.0).animate(_curved),
      alignment: alignment,
      child: FadeTransition(
        opacity: _curved,
        child: Align(
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
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(KSpace.rLg),
                topRight: const Radius.circular(KSpace.rLg),
                bottomLeft: Radius.circular(isMine ? KSpace.rLg : KSpace.xs),
                bottomRight: Radius.circular(isMine ? KSpace.xs : KSpace.rLg),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildContent(textColor),
                const SizedBox(height: KSpace.xs),
                _BubbleMeta(
                  message: widget.message,
                  isMine: isMine,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Color textColor) {
    final Message message = widget.message;
    final bool isImage = message.type == MessageType.image;
    if (isImage && (message.mediaUrl?.isNotEmpty ?? false)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(KSpace.rMd),
        child: Image.network(
          message.mediaUrl!,
          width: 200,
          fit: BoxFit.cover,
          loadingBuilder: (
            BuildContext context,
            Widget child,
            ImageChunkEvent? progress,
          ) {
            if (progress == null) {
              return child;
            }
            return const SizedBox(
              width: 200,
              height: 140,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (BuildContext context, Object _, StackTrace? __) =>
              SizedBox(
            width: 200,
            height: 140,
            child: ColoredBox(
              color: KColors.slate200,
              child: const Icon(
                Icons.broken_image_outlined,
                color: KColors.slate500,
              ),
            ),
          ),
        ),
      );
    }

    return Text(
      message.text ?? '',
      style: KTextStyles.bodyMd.copyWith(color: textColor),
    );
  }
}

/// The timestamp and (for the client's own messages) read-receipt row beneath a
/// bubble's content (Requirement 9.3).
class _BubbleMeta extends StatelessWidget {
  const _BubbleMeta({
    required this.message,
    required this.isMine,
  });

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    // Muted meta color derived from the bubble's foreground, chosen as fixed
    // constants (rather than runtime alpha-blending) for broad SDK support.
    final Color metaColor =
        isMine ? KColors.navy600 : const Color(0xB3FFFFFF);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          DateFormat('HH:mm').format(message.sentAt.toLocal()),
          style: KTextStyles.caption.copyWith(color: metaColor),
        ),
        if (isMine) ...<Widget>[
          const SizedBox(width: KSpace.xs),
          Icon(
            message.read ? Icons.done_all_rounded : Icons.done_rounded,
            size: 14,
            color: message.read ? KColors.navy600 : metaColor,
          ),
        ],
      ],
    );
  }
}

/// A friendly empty-conversation state shown before the first message.
class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: KColors.slate200,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: KColors.navy800,
              ),
            ),
            const SizedBox(height: KSpace.lg),
            Text(
              'Start the conversation',
              textAlign: TextAlign.center,
              style: KTextStyles.headingMd,
            ),
            const SizedBox(height: KSpace.sm),
            Text(
              'Say hello to the Keyframes team — ask about a service, share '
              'references, or follow up on an order.',
              textAlign: TextAlign.center,
              style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated typing-indicator placeholder (three pulsing dots). Hidden unless
/// [visible] is true; presence/typing wiring is added in a later pass.
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(KSpace.lg, 0, KSpace.lg, KSpace.sm),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpace.md,
            vertical: KSpace.sm,
          ),
          decoration: BoxDecoration(
            color: KColors.navy800,
            borderRadius: BorderRadius.circular(KSpace.rLg),
          ),
          child: Text(
            'Keyframes is typing…',
            style: KTextStyles.caption.copyWith(color: KColors.white),
          ),
        ),
      ),
    );
  }
}

/// A status strip shown while an image attachment is uploading, or after it has
/// failed — in which case it offers retry / cancel controls (Requirement 9.8).
class _AttachmentStatusBar extends StatelessWidget {
  const _AttachmentStatusBar({
    required this.attachment,
    required this.onRetry,
    required this.onCancel,
  });

  final PendingAttachment attachment;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final bool failed = attachment.phase == AttachmentPhase.failed;
    return Material(
      color: failed ? const Color(0x1AE5484D) : KColors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.lg,
          vertical: KSpace.sm,
        ),
        child: Row(
          children: <Widget>[
            if (failed)
              const Icon(Icons.error_outline_rounded,
                  color: KColors.danger, size: 20)
            else
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            const SizedBox(width: KSpace.sm),
            Expanded(
              child: Text(
                failed
                    ? (attachment.error ?? 'Upload failed.')
                    : 'Uploading ${attachment.fileName}…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KTextStyles.label.copyWith(
                  color: failed ? KColors.danger : KColors.slate700,
                ),
              ),
            ),
            if (failed) ...<Widget>[
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: KTextStyles.label.copyWith(
                    color: KColors.navy800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded, size: 20),
                color: KColors.slate500,
                tooltip: 'Discard',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The bottom compose bar: an attach (image) button, a multiline text field,
/// and a send button that is disabled while the field is empty (Requirement
/// 9.4) or a send is in flight.
class _ComposeBar extends StatefulWidget {
  const _ComposeBar({
    required this.sending,
    required this.onSend,
    required this.onPickImage,
  });

  final bool sending;
  final ValueChanged<String> onSend;
  final VoidCallback onPickImage;

  @override
  State<_ComposeBar> createState() => _ComposeBarState();
}

class _ComposeBarState extends State<_ComposeBar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final bool hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String text = _controller.text.trim();
    if (text.isEmpty || widget.sending) {
      return;
    }
    widget.onSend(text);
    _controller.clear();
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
            IconButton(
              onPressed: widget.sending ? null : widget.onPickImage,
              icon: const Icon(Icons.attach_file_rounded),
              color: KColors.navy600,
              tooltip: 'Attach image',
              constraints: const BoxConstraints(
                minWidth: KSpace.minTouchTarget,
                minHeight: KSpace.minTouchTarget,
              ),
            ),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  style: KTextStyles.bodyMd,
                  decoration: InputDecoration(
                    hintText: 'Message…',
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
            _SendButton(enabled: canSend, onTap: _submit),
          ],
        ),
      ),
    );
  }
}

/// The circular send button; greyed out and non-interactive when disabled.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Send message',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: KMotion.fast,
          width: KSpace.minTouchTarget,
          height: KSpace.minTouchTarget,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: enabled
                ? const LinearGradient(
                    colors: <Color>[KColors.amber400, KColors.amber500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: enabled ? null : KColors.slate200,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.send_rounded,
            color: enabled ? KColors.white : KColors.slate500,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Infers an allowed image MIME type from a file name's extension, defaulting
/// to `image/jpeg`. Mirrors the content types accepted by the chat repository's
/// attachment upload validation.
String _inferImageContentType(String fileName) {
  final String lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.gif')) {
    return 'image/gif';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/jpeg';
}
