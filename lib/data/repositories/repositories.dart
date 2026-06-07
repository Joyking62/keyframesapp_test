import '../../core/app_config.dart';
import 'auth_repository.dart';
import 'chat_repository.dart';
import 'orders_repository.dart';

export 'auth_repository.dart';
export 'chat_repository.dart';
export 'orders_repository.dart';

/// Bundles the three repositories and picks the right implementations based on
/// [kUseFirebase]. This is the single place where the data source is chosen.
class Repositories {
  final AuthRepository auth;
  final OrdersRepository orders;
  final ChatRepository chat;

  Repositories({
    required this.auth,
    required this.orders,
    required this.chat,
  });

  factory Repositories.create() {
    if (kUseFirebase) {
      return Repositories(
        auth: FirebaseAuthRepository(),
        orders: FirebaseOrdersRepository(),
        chat: FirebaseChatRepository(),
      );
    }
    return Repositories(
      auth: MockAuthRepository(),
      orders: MockOrdersRepository(),
      chat: MockChatRepository(),
    );
  }
}
