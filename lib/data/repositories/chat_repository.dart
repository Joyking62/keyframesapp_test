import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_config.dart';
import '../mock_data.dart';
import '../models/models.dart';

abstract class ChatRepository {
  Stream<List<ChatThread>> watchThreads(
      {required String uid, required bool isAdmin});

  Future<void> sendMessage(String threadId, String uid, String text);
}

/// ---- Demo implementation (with a simulated auto-reply) ----
class MockChatRepository implements ChatRepository {
  final List<ChatThread> _threads = MockData.seedThreadsForClient();
  final _controller = StreamController<List<ChatThread>>.broadcast();

  void _emit() => _controller.add(List.unmodifiable(_threads));

  @override
  Stream<List<ChatThread>> watchThreads(
      {required String uid, required bool isAdmin}) async* {
    yield List.unmodifiable(_threads);
    yield* _controller.stream;
  }

  @override
  Future<void> sendMessage(String threadId, String uid, String text) async {
    final idx = _threads.indexWhere((t) => t.id == threadId);
    if (idx == -1) return;
    final t = _threads[idx];
    final msg = ChatMessage(
      id: 'm${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      fromMe: true,
      time: DateTime.now(),
    );
    _threads[idx] = t.copyWith(messages: [...t.messages, msg]);
    _emit();

    // Simulated reply so the demo feels alive.
    Future.delayed(const Duration(milliseconds: 1400), () {
      final i = _threads.indexWhere((e) => e.id == threadId);
      if (i == -1) return;
      final th = _threads[i];
      _threads[i] = th.copyWith(messages: [
        ...th.messages,
        ChatMessage(
          id: 'm${DateTime.now().millisecondsSinceEpoch}',
          text: 'Got it — our team will update you shortly. 👍',
          fromMe: false,
          time: DateTime.now(),
        ),
      ]);
      _emit();
    });
  }
}

/// ---- Firebase implementation ----
///
/// Data model:
///   chats/{threadId} { participants: [uid...], clientName, subtitle,
///                      online, lastText, lastTime }
///     messages/{msgId} { text, senderId, time, read }
///
/// `watchThreads` combines each thread doc with a live listener on its
/// `messages` subcollection so the UI keeps working with fully-populated
/// ChatThread objects.
class FirebaseChatRepository implements ChatRepository {
  FirebaseChatRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection(FsCollections.chats);

  @override
  Stream<List<ChatThread>> watchThreads(
      {required String uid, required bool isAdmin}) {
    final controller = StreamController<List<ChatThread>>();

    final Query<Map<String, dynamic>> query = isAdmin
        ? _chats.orderBy('lastTime', descending: true)
        : _chats
            .where('participants', arrayContains: uid)
            .orderBy('lastTime', descending: true);

    final threadData = <String, Map<String, dynamic>>{};
    final threadMsgs = <String, List<ChatMessage>>{};
    final msgSubs = <String, StreamSubscription<dynamic>>{};
    StreamSubscription<dynamic>? threadsSub;

    void emit() {
      final list = threadData.entries.map((e) {
        final d = e.value;
        return ChatThread(
          id: e.key,
          name: isAdmin
              ? (d['clientName'] ?? 'Client') as String
              : 'Keyframes Team',
          subtitle: (d['subtitle'] ?? '') as String,
          online: (d['online'] ?? false) as bool,
          messages: threadMsgs[e.key] ?? const [],
        );
      }).toList()
        ..sort((a, b) => b.last.time.compareTo(a.last.time));
      if (!controller.isClosed) controller.add(list);
    }

    threadsSub = query.snapshots().listen((snap) {
      final currentIds = snap.docs.map((d) => d.id).toSet();

      // Drop threads that disappeared.
      for (final goneId in threadData.keys.toList()) {
        if (!currentIds.contains(goneId)) {
          threadData.remove(goneId);
          threadMsgs.remove(goneId);
          msgSubs.remove(goneId)?.cancel();
        }
      }

      // Add/refresh threads and ensure a message listener per thread.
      for (final doc in snap.docs) {
        threadData[doc.id] = doc.data();
        if (!msgSubs.containsKey(doc.id)) {
          msgSubs[doc.id] = _chats
              .doc(doc.id)
              .collection(FsCollections.messages)
              .orderBy('time')
              .snapshots()
              .listen((msgSnap) {
            threadMsgs[doc.id] = msgSnap.docs
                .map((m) => ChatMessage.fromMap(m.id, m.data(), uid))
                .toList();
            emit();
          });
        }
      }
      emit();
    });

    controller.onCancel = () {
      threadsSub?.cancel();
      for (final s in msgSubs.values) {
        s.cancel();
      }
    };

    return controller.stream;
  }

  @override
  Future<void> sendMessage(String threadId, String uid, String text) async {
    final now = DateTime.now();
    final thread = _chats.doc(threadId);
    await thread.collection(FsCollections.messages).add({
      'text': text,
      'senderId': uid,
      'time': now,
      'read': false,
    });
    await thread.set(
      {'lastText': text, 'lastTime': now},
      SetOptions(merge: true),
    );
  }
}
