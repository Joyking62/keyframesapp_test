import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

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
    required this.clientName,
    required this.amount,
    required this.createdAt,
    required this.dueDate,
    required this.status,
    required this.brief,
  });
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

  ChatMessage get last => messages.last;
  int get unread => messages.where((m) => !m.fromMe && !m.read).length;
}
