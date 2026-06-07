import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'models/models.dart';

/// Static seed data so the app is fully interactive without a backend.
/// Replace these with Firebase / REST calls when wiring up production.
class MockData {
  MockData._();

  static const categories = <ServiceCategory>[
    ServiceCategory(
      id: 'mobile',
      title: 'Mobile Apps',
      tagline: 'iOS & Android',
      icon: Icons.phone_iphone_rounded,
      gradient: AppColors.navyGradient,
    ),
    ServiceCategory(
      id: 'web',
      title: 'Web Development',
      tagline: 'Sites & web apps',
      icon: Icons.language_rounded,
      gradient: AppColors.navyGradient,
    ),
    ServiceCategory(
      id: 'iot',
      title: 'IoT Projects',
      tagline: 'Smart & embedded',
      icon: Icons.sensors_rounded,
      gradient: AppColors.navyGradient,
    ),
    ServiceCategory(
      id: 'academic',
      title: 'University Projects',
      tagline: 'Mini & major',
      icon: Icons.school_rounded,
      gradient: AppColors.navyGradient,
    ),
    ServiceCategory(
      id: 'design',
      title: 'Graphic Design',
      tagline: 'Logos & posters',
      icon: Icons.brush_rounded,
      gradient: AppColors.amberGradient,
    ),
    ServiceCategory(
      id: 'video',
      title: 'Video Editing',
      tagline: 'Reels & promos',
      icon: Icons.movie_filter_rounded,
      gradient: AppColors.amberGradient,
    ),
  ];

  static const services = <ServiceItem>[
    ServiceItem(
      id: 's1',
      categoryId: 'mobile',
      title: 'Flutter Mobile App',
      summary: 'Cross-platform app with stunning UI/UX',
      description:
          'A complete cross-platform mobile application built in Flutter — '
          'one codebase for iOS & Android with pixel-perfect UI, smooth '
          'animations, API integration and store-ready builds.',
      icon: Icons.phone_iphone_rounded,
      startingPrice: 299,
      deliveryDays: 14,
      rating: 4.9,
      reviews: 128,
      features: [
        'iOS + Android single codebase',
        'Custom UI/UX & animations',
        'REST / Firebase integration',
        'Play Store & App Store ready',
      ],
      tiers: [
        ServiceTier(
          name: 'Basic',
          blurb: 'Up to 4 screens prototype',
          price: 299,
          deliveryDays: 10,
          revisions: 2,
          includes: ['4 screens', 'Static data', 'Source code'],
        ),
        ServiceTier(
          name: 'Standard',
          blurb: 'Full app with backend',
          price: 699,
          deliveryDays: 18,
          revisions: 4,
          includes: ['Up to 12 screens', 'API integration', 'Auth & DB'],
        ),
        ServiceTier(
          name: 'Premium',
          blurb: 'Production launch package',
          price: 1299,
          deliveryDays: 28,
          revisions: 8,
          includes: ['Unlimited screens', 'Admin panel', 'Store publishing'],
        ),
      ],
    ),
    ServiceItem(
      id: 's2',
      categoryId: 'web',
      title: 'Business Website',
      summary: 'Responsive marketing site that converts',
      description:
          'A modern, responsive website for your brand — fast, SEO-friendly '
          'and easy to manage. Built with clean code and a CMS so you can '
          'update content yourself.',
      icon: Icons.language_rounded,
      startingPrice: 149,
      deliveryDays: 7,
      rating: 4.8,
      reviews: 96,
      features: [
        'Fully responsive design',
        'SEO optimised',
        'CMS / easy editing',
        'Contact & analytics',
      ],
      tiers: [
        ServiceTier(
          name: 'Basic',
          blurb: 'Landing page',
          price: 149,
          deliveryDays: 5,
          revisions: 2,
          includes: ['1 page', 'Mobile responsive', 'Contact form'],
        ),
        ServiceTier(
          name: 'Standard',
          blurb: 'Multi-page site',
          price: 399,
          deliveryDays: 10,
          revisions: 4,
          includes: ['Up to 6 pages', 'CMS', 'Basic SEO'],
        ),
        ServiceTier(
          name: 'Premium',
          blurb: 'Web app / e-commerce',
          price: 899,
          deliveryDays: 21,
          revisions: 6,
          includes: ['Dynamic backend', 'Payments', 'Dashboard'],
        ),
      ],
    ),
    ServiceItem(
      id: 's3',
      categoryId: 'iot',
      title: 'IoT Smart Solution',
      summary: 'Sensors, hardware & a control app',
      description:
          'End-to-end IoT builds — sensor hardware, microcontroller firmware, '
          'a cloud dashboard and a companion mobile app to monitor and '
          'control your devices in real time.',
      icon: Icons.sensors_rounded,
      startingPrice: 199,
      deliveryDays: 15,
      rating: 4.7,
      reviews: 54,
      features: [
        'ESP32 / Arduino / RPi',
        'Real-time cloud dashboard',
        'Companion mobile app',
        'Documentation included',
      ],
      tiers: [
        ServiceTier(
          name: 'Basic',
          blurb: 'Single sensor demo',
          price: 199,
          deliveryDays: 10,
          revisions: 2,
          includes: ['1 sensor', 'Serial output', 'Wiring diagram'],
        ),
        ServiceTier(
          name: 'Standard',
          blurb: 'Connected dashboard',
          price: 449,
          deliveryDays: 16,
          revisions: 3,
          includes: ['Multi-sensor', 'Cloud dashboard', 'Mobile view'],
        ),
        ServiceTier(
          name: 'Premium',
          blurb: 'Full product prototype',
          price: 999,
          deliveryDays: 30,
          revisions: 5,
          includes: ['Custom PCB', 'App + cloud', 'Enclosure design'],
        ),
      ],
    ),
    ServiceItem(
      id: 's4',
      categoryId: 'academic',
      title: 'University Mini Project',
      summary: 'Guided final-year & mini projects',
      description:
          'Complete academic project support with clean code, report, and a '
          'walkthrough so you can present with confidence. Available across '
          'web, mobile, ML and IoT domains.',
      icon: Icons.school_rounded,
      startingPrice: 79,
      deliveryDays: 10,
      rating: 4.9,
      reviews: 210,
      features: [
        'Source code + report',
        'PPT & documentation',
        'Plagiarism-safe & original',
        'Explanation session',
      ],
      tiers: [
        ServiceTier(
          name: 'Basic',
          blurb: 'Mini project',
          price: 79,
          deliveryDays: 7,
          revisions: 2,
          includes: ['Working code', 'Short report', 'README'],
        ),
        ServiceTier(
          name: 'Standard',
          blurb: 'Mini + documentation',
          price: 159,
          deliveryDays: 12,
          revisions: 3,
          includes: ['Code + report', 'PPT', 'Demo video'],
        ),
        ServiceTier(
          name: 'Premium',
          blurb: 'Major project',
          price: 349,
          deliveryDays: 25,
          revisions: 5,
          includes: ['Full project', 'Thesis-grade report', 'Viva prep'],
        ),
      ],
    ),
    ServiceItem(
      id: 's5',
      categoryId: 'design',
      title: 'Logo & Brand Identity',
      summary: 'Memorable logos and brand kits',
      description:
          'Distinctive logo design and a complete brand identity — colour '
          'palette, typography, social kit and source files so your brand '
          'looks consistent everywhere.',
      icon: Icons.brush_rounded,
      startingPrice: 49,
      deliveryDays: 4,
      rating: 5.0,
      reviews: 187,
      features: [
        'Unique concepts',
        'Vector source files',
        'Full brand kit',
        'Unlimited formats',
      ],
      tiers: [
        ServiceTier(
          name: 'Basic',
          blurb: 'Logo only',
          price: 49,
          deliveryDays: 3,
          revisions: 3,
          includes: ['2 concepts', 'PNG + JPG', '1 revision round'],
        ),
        ServiceTier(
          name: 'Standard',
          blurb: 'Logo + essentials',
          price: 99,
          deliveryDays: 5,
          revisions: 5,
          includes: ['3 concepts', 'Vector files', 'Social kit'],
        ),
        ServiceTier(
          name: 'Premium',
          blurb: 'Full brand identity',
          price: 199,
          deliveryDays: 8,
          revisions: 8,
          includes: ['Brand guide', 'Stationery', 'All source files'],
        ),
      ],
    ),
    ServiceItem(
      id: 's6',
      categoryId: 'video',
      title: 'Video Editing & Reels',
      summary: 'Scroll-stopping edits & promos',
      description:
          'Professional video editing for reels, ads and promos — motion '
          'graphics, colour grading, captions and sound design that keeps '
          'viewers watching.',
      icon: Icons.movie_filter_rounded,
      startingPrice: 39,
      deliveryDays: 3,
      rating: 4.9,
      reviews: 142,
      features: [
        'Motion graphics',
        'Colour grading',
        'Captions & sound',
        'Multiple aspect ratios',
      ],
      tiers: [
        ServiceTier(
          name: 'Basic',
          blurb: 'Short reel',
          price: 39,
          deliveryDays: 2,
          revisions: 2,
          includes: ['Up to 30s', 'Captions', '1080p export'],
        ),
        ServiceTier(
          name: 'Standard',
          blurb: 'Promo video',
          price: 89,
          deliveryDays: 4,
          revisions: 3,
          includes: ['Up to 90s', 'Motion graphics', 'Sound design'],
        ),
        ServiceTier(
          name: 'Premium',
          blurb: 'Full campaign',
          price: 199,
          deliveryDays: 7,
          revisions: 5,
          includes: ['Up to 3 min', 'Advanced VFX', 'All formats'],
        ),
      ],
    ),
  ];

  static List<ServiceItem> servicesFor(String categoryId) =>
      services.where((s) => s.categoryId == categoryId).toList();

  static ServiceCategory categoryById(String id) =>
      categories.firstWhere((c) => c.id == id);

  // ---- Seed orders (used by both client + admin) ----
  static List<PreOrder> seedOrders() {
    final now = DateTime.now();
    return [
      PreOrder(
        id: 'KF-1042',
        serviceTitle: 'Flutter Mobile App',
        tierName: 'Standard',
        clientName: 'Ravi Teja',
        amount: 699,
        createdAt: now.subtract(const Duration(days: 2)),
        dueDate: now.add(const Duration(days: 16)),
        status: OrderStatus.inProgress,
        brief: 'A food delivery app with login, cart and live order tracking.',
      ),
      PreOrder(
        id: 'KF-1041',
        serviceTitle: 'Logo & Brand Identity',
        tierName: 'Premium',
        clientName: 'Aisha Khan',
        amount: 199,
        createdAt: now.subtract(const Duration(days: 1)),
        dueDate: now.add(const Duration(days: 7)),
        status: OrderStatus.inReview,
        brief: 'Brand identity for an organic skincare startup, earthy tones.',
      ),
      PreOrder(
        id: 'KF-1040',
        serviceTitle: 'Video Editing & Reels',
        tierName: 'Standard',
        clientName: 'Marcus Lee',
        amount: 89,
        createdAt: now.subtract(const Duration(days: 4)),
        dueDate: now.add(const Duration(days: 1)),
        status: OrderStatus.delivered,
        brief: '90-second promo for a gym, energetic, with captions.',
      ),
      PreOrder(
        id: 'KF-1039',
        serviceTitle: 'University Mini Project',
        tierName: 'Standard',
        clientName: 'Priya Sharma',
        amount: 159,
        createdAt: now.subtract(const Duration(days: 9)),
        dueDate: now.subtract(const Duration(days: 1)),
        status: OrderStatus.completed,
        brief: 'IoT-based smart attendance system with report and PPT.',
      ),
      PreOrder(
        id: 'KF-1038',
        serviceTitle: 'IoT Smart Solution',
        tierName: 'Basic',
        clientName: 'Daniel Cruz',
        amount: 199,
        createdAt: now.subtract(const Duration(hours: 6)),
        dueDate: now.add(const Duration(days: 10)),
        status: OrderStatus.pending,
        brief: 'Soil-moisture monitoring demo with a simple dashboard.',
      ),
    ];
  }

  // ---- Seed chat threads ----
  static List<ChatThread> seedThreadsForClient() {
    final now = DateTime.now();
    return [
      ChatThread(
        id: 't1',
        name: 'Keyframes Team',
        subtitle: 'Order KF-1042 · Flutter App',
        online: true,
        messages: [
          ChatMessage(
            id: 'm1',
            text: 'Hi! Thanks for your pre-order. Could you share references?',
            fromMe: false,
            time: now.subtract(const Duration(hours: 5)),
          ),
          ChatMessage(
            id: 'm2',
            text: 'Sure, I like the style of the Swiggy app.',
            fromMe: true,
            time: now.subtract(const Duration(hours: 4, minutes: 50)),
          ),
          ChatMessage(
            id: 'm3',
            text: 'Perfect. We will share the first screens in 3 days. 🚀',
            fromMe: false,
            time: now.subtract(const Duration(hours: 4)),
            read: false,
          ),
        ],
      ),
      ChatThread(
        id: 't2',
        name: 'Keyframes Team',
        subtitle: 'Order KF-1040 · Video Reel',
        messages: [
          ChatMessage(
            id: 'm4',
            text: 'Your reel draft is ready for review ✨',
            fromMe: false,
            time: now.subtract(const Duration(days: 1)),
            read: false,
          ),
        ],
      ),
    ];
  }

  // ---- Admin analytics ----
  static const List<double> weeklyRevenue = [
    420, 680, 540, 910, 770, 1180, 1340
  ];
  static const List<String> weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];
}
