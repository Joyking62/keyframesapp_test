import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../client/chat_screen.dart';

/// Admin inbox — reuses ChatScreen for the conversation view.
class AdminChat extends StatelessWidget {
  const AdminChat({super.key});

  @override
  Widget build(BuildContext context) {
    final threads = context.watch<AppState>().threads;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text('Client inbox',
              style: Theme.of(context).textTheme.headlineMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Respond to client conversations.',
              style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: threads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _InboxTile(thread: threads[i]),
          ),
        ),
      ],
    );
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.thread});
  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(threadId: thread.id),
        )),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.amber.withOpacity(0.2),
          child: const Icon(Icons.person_rounded, color: AppColors.amberDeep),
        ),
        title: Text('Client · ${thread.subtitle}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(thread.last.text,
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(DateFormat('h:mm a').format(thread.last.time),
                style: const TextStyle(fontSize: 10, color: AppColors.slate)),
            const SizedBox(height: 6),
            if (thread.unread > 0)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: AppColors.danger, shape: BoxShape.circle),
                child: Text('${thread.unread}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}
