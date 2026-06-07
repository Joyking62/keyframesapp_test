import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/brand_logo.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final threads = context.watch<AppState>().threads;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Text('Messages',
                    style: Theme.of(context).textTheme.headlineMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.circle, size: 8, color: AppColors.success),
                      SizedBox(width: 6),
                      Text('Team online',
                          style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              itemCount: threads.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 80),
              itemBuilder: (context, i) => _ThreadTile(thread: threads[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread});
  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    final unread = thread.unread;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(threadId: thread.id),
      )),
      leading: Stack(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.navyGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(child: BrandLogo(size: 34)),
          ),
          if (thread.online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.offWhite, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(thread.name,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(thread.subtitle,
              style: const TextStyle(
                  color: AppColors.amberDeep,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            thread.last.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: unread > 0 ? AppColors.ink : AppColors.slate,
              fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(DateFormat('h:mm a').format(thread.last.time),
              style: const TextStyle(color: AppColors.slate, fontSize: 11)),
          const SizedBox(height: 6),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                gradient: AppColors.amberGradient,
                shape: BoxShape.circle,
              ),
              child: Text('$unread',
                  style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            )
          else
            const Icon(Icons.done_all_rounded,
                size: 16, color: AppColors.slate),
        ],
      ),
    );
  }
}
