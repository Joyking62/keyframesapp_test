import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Tolerant date parser: handles DateTime, epoch millis (int), and Firestore
/// `Timestamp` (via its `.toDate()` method, called dynamically so this file
/// never needs to import cloud_firestore).
DateTime parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  try {
    return (v as dynamic).toDate() as DateTime;
  } catch (_) {
    return DateTime.now();
  }
}

enum UserRole { client, admin }

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? avatarUrl;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.role = UserRole.client,
    this.avatarUrl,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts.first.characters.take(2).toString();
    return (parts.first.characters.first.toString() +
            parts.last.characters.first.toString())
        .toUpperCase();
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'role': role.name,
        'avatarUrl': avatarUrl,
      };

  factory AppUser.fromMap(String id, Map<String, dynamic> data) => AppUser(
        id: id,
        name: (data['name'] ?? '') as String,
        email: (data['email'] ?? '') as String,
        role: data['role'] == 'admin' ? UserRole.admin : UserRole.client,
        avatarUrl: data['avatarUrl'] as String?,
      );
}

/// A top-level service category (IT or Creative).
class ServiceCategory {
  final String id;
  final String title;
  final String tagline;
  final IconData icon;
  final Gradient gradient;

  const ServiceCategory({
    required this.id,
    required this.title,
    required this.tagline,
    required this.icon,
    required this.gradient,
  });
}

/// A concrete service offering (a "gig"-style package).
class ServiceItem {
  final String id;
  final String categoryId;
  final String title;
  final String summary;
  final String description;
  final IconData icon;
  final double startingPrice;
  final int deliveryDays;
  final double rating;
  final int reviews;
  final List<String> features;
  final List<ServiceTier> tiers;

  const ServiceItem({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.summary,
    required this.description,
    required this.icon,
    required this.startingPrice,
    required this.deliveryDays,
    required this.rating,
    required this.reviews,
    required this.features,
    required this.tiers,
  });
}

class ServiceTier {
  final String name; // Basic / Standard / Premium
  final String blurb;
  final double price;
  final int deliveryDays;
  final int revisions;
  final List<String> includes;

  const ServiceTier({
    required this.name,
    required this.blurb,
    required this.price,
    required this.deliveryDays,
    required this.revisions,
    required this.includes,
  });
}

enum OrderStatus { pending, inReview, inProgress, delivered, completed, cancelled }

OrderStatus orderStatusFromName(String? name) => OrderStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => OrderStatus.pending,
    );

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.pending => 'Pending',
        OrderStatus.inReview => 'In Review',
        OrderStatus.inProgress => 'In Progress',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.completed => 'Completed',
        OrderStatus.cancelled => 'Cancelled',
      };

  Color get color => switch (this) {
        OrderStatus.pending => AppColors.warning,
        OrderStatus.inReview => AppColors.info,
        OrderStatus.inProgress => AppColors.amberDeep,
        OrderStatus.delivered => AppColors.navy500,
        OrderStatus.completed => AppColors.success,
        OrderStatus.cancelled => AppColors.danger,
      };

  IconData get icon => switch (this) {
        OrderStatus.pending => Icons.hourglass_top_rounded,
        OrderStatus.inReview => Icons.fact_check_rounded,
        OrderStatus.inProgress => Icons.timelapse_rounded,
        OrderStatus.delivered => Icons.local_shipping_rounded,
        OrderStatus.completed => Icons.verified_rounded,
        OrderStatus.cancelled => Icons.cancel_rounded,
      };
}

class PreOrder {
  final String id;
  final String serviceTitle;
  final String tierName;
  final String clientId;
  final String clientName;
  final double amount;
  final DateTime createdAt;
  final DateTime dueDate;
  OrderStatus status;
  final String brief;

  PreOrder({
    required this.id,
    required this.serviceTitle,
    required this.tierName,
    this.clientId = '',
    required this.clientName,
    required this.amount,
    required this.createdAt,
    required this.dueDate,
    required this.status,
    required this.brief,
  });

  Map<String, dynamic> toMap() => {
        'serviceTitle': serviceTitle,
        'tierName': tierName,
        'clientId': clientId,
        'clientName': clientName,
        'amount': amount,
        'createdAt': createdAt,
        'dueDate': dueDate,
        'status': status.name,
        'brief': brief,
      };

  factory PreOrder.fromMap(String id, Map<String, dynamic> data) => PreOrder(
        id: id,
        serviceTitle: (data['serviceTitle'] ?? '') as String,
        tierName: (data['tierName'] ?? '') as String,
        clientId: (data['clientId'] ?? '') as String,
        clientName: (data['clientName'] ?? '') as String,
        amount: (data['amount'] ?? 0).toDouble(),
        createdAt: parseDate(data['createdAt']),
        dueDate: parseDate(data['dueDate']),
        status: orderStatusFromName(data['status'] as String?),
        brief: (data['brief'] ?? '') as String,
      );
}

class ChatMessage {
  final String id;
  final String text;
  final bool fromMe; // relative to the current viewer
  final DateTime time;
  final bool read;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.fromMe,
    required this.time,
    this.read = true,
  });

  /// Build from a Firestore message doc. `fromMe` is derived by comparing the
  /// stored `senderId` against the current viewer's uid.
  factory ChatMessage.fromMap(
    String id,
    Map<String, dynamic> data,
    String currentUserId,
  ) =>
      ChatMessage(
        id: id,
        text: (data['text'] ?? '') as String,
        fromMe: (data['senderId'] ?? '') == currentUserId,
        time: parseDate(data['time']),
        read: (data['read'] ?? true) as bool,
      );
}

class ChatThread {
  final String id;
  final String name; // counterpart name (client or "Keyframes Team")
  final String subtitle; // related order/service
  final List<ChatMessage> messages;
  final bool online;

  const ChatThread({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.messages,
    this.online = false,
  });

  ChatMessage get last => messages.isEmpty
      ? ChatMessage(
          id: '_',
          text: '',
          fromMe: false,
          time: DateTime.fromMillisecondsSinceEpoch(0),
        )
      : messages.last;

  int get unread => messages.where((m) => !m.fromMe && !m.read).length;

  ChatThread copyWith({List<ChatMessage>? messages}) => ChatThread(
        id: id,
        name: name,
        subtitle: subtitle,
        online: online,
        messages: messages ?? this.messages,
      );
}
