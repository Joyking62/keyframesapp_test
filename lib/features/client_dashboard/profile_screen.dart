import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/core/theme/k_text_styles.dart';
import 'package:keyframes_app/core/widgets/widgets.dart';
import 'package:keyframes_app/data/models/app_user.dart';

/// The client profile tab (Requirement 10.4).
///
/// Shows the signed-in user's avatar, name, and email, and lets the client:
///
/// * **Edit their profile** — a simple dialog captures a new display name
///   (the underlying persistence is stubbed until the auth repository exposes a
///   profile-update method; see [_showEditProfileDialog]).
/// * **Adjust theme preference** — light / dark / system, persisted via
///   [LocalSource.setThemeMode].
/// * **Toggle notifications** — persisted via
///   [LocalSource.setNotificationsEnabled].
/// * **Sign out** — calls [AuthRepository.signOut] and routes to the login
///   screen.
///
/// Theme and notification controls keep local UI state seeded from the
/// [LocalSource] so the toggles reflect (and persist) the user's choice
/// immediately. A [ConsumerStatefulWidget] is used because these toggles own
/// transient selection state.
class ClientProfileScreen extends ConsumerStatefulWidget {
  /// Creates the client profile screen.
  const ClientProfileScreen({super.key});

  @override
  ConsumerState<ClientProfileScreen> createState() =>
      _ClientProfileScreenState();
}

class _ClientProfileScreenState extends ConsumerState<ClientProfileScreen> {
  late ThemeMode _themeMode;
  late bool _notificationsEnabled;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    final local = ref.read(localSourceProvider);
    _themeMode = local.themeMode;
    _notificationsEnabled = local.notificationsEnabled;
  }

  Future<void> _onThemeModeChanged(ThemeMode? mode) async {
    if (mode == null) {
      return;
    }
    setState(() => _themeMode = mode);
    await ref.read(localSourceProvider).setThemeMode(mode);
  }

  Future<void> _onNotificationsChanged(bool value) async {
    setState(() => _notificationsEnabled = value);
    await ref.read(localSourceProvider).setNotificationsEnabled(value);
  }

  Future<void> _signOut() async {
    if (_signingOut) {
      return;
    }
    setState(() => _signingOut = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
      if (!mounted) {
        return;
      }
      context.go(KRoutes.login);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _signingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    }
  }

  Future<void> _showEditProfileDialog(AppUser user) async {
    final TextEditingController controller =
        TextEditingController(text: user.name);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit profile'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (!mounted || newName == null) {
      return;
    }
    // TODO(profile): persist the display name once AuthRepository exposes a
    // profile-update method. For now we acknowledge the change to the user.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newName.isEmpty
              ? 'Display name cannot be empty.'
              : 'Profile updates are coming soon.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: KColors.offWhite,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: KColors.offWhite,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: user == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  KSpace.lg,
                  KSpace.md,
                  KSpace.lg,
                  KSpace.xxl,
                ),
                children: <Widget>[
                  _ProfileHeader(
                    user: user,
                    onEdit: () => _showEditProfileDialog(user),
                  ),
                  const SizedBox(height: KSpace.lg),
                  _PreferencesCard(
                    themeMode: _themeMode,
                    notificationsEnabled: _notificationsEnabled,
                    onThemeModeChanged: _onThemeModeChanged,
                    onNotificationsChanged: _onNotificationsChanged,
                  ),
                  const SizedBox(height: KSpace.xl),
                  KPrimaryButton(
                    label: 'Sign out',
                    icon: Icons.logout_rounded,
                    loading: _signingOut,
                    expanded: true,
                    onPressed: _signOut,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Avatar + name/email header with an "Edit" affordance.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.onEdit});

  final AppUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto =
        user.photoUrl != null && user.photoUrl!.isNotEmpty;

    return KCard(
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 32,
            backgroundColor: KColors.navy600.withOpacity(0.12),
            backgroundImage:
                hasPhoto ? NetworkImage(user.photoUrl!) : null,
            child: hasPhoto
                ? null
                : Text(
                    _initials(user.name),
                    style: KTextStyles.titleMd.copyWith(
                      color: KColors.navy600,
                    ),
                  ),
          ),
          const SizedBox(width: KSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user.name.isEmpty ? 'Your name' : user.name,
                  style: KTextStyles.titleMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: KSpace.xs),
                Text(
                  user.email,
                  style: KTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, color: KColors.navy600),
            tooltip: 'Edit profile',
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

/// Theme + notification preference controls.
class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({
    required this.themeMode,
    required this.notificationsEnabled,
    required this.onThemeModeChanged,
    required this.onNotificationsChanged,
  });

  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final ValueChanged<ThemeMode?> onThemeModeChanged;
  final ValueChanged<bool> onNotificationsChanged;

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Preferences', style: KTextStyles.titleMd),
          const SizedBox(height: KSpace.md),
          Text(
            'Appearance',
            style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
          ),
          const SizedBox(height: KSpace.sm),
          SegmentedButton<ThemeMode>(
            segments: const <ButtonSegment<ThemeMode>>[
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto_outlined),
              ),
            ],
            selected: <ThemeMode>{themeMode},
            onSelectionChanged: (Set<ThemeMode> selection) {
              onThemeModeChanged(
                selection.isEmpty ? null : selection.first,
              );
            },
          ),
          const Divider(height: KSpace.xl, color: KColors.slate200),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text('Notifications', style: KTextStyles.bodyLg),
            subtitle: Text(
              'Receive updates about your orders.',
              style: KTextStyles.caption,
            ),
            value: notificationsEnabled,
            activeColor: KColors.amber500,
            onChanged: onNotificationsChanged,
          ),
        ],
      ),
    );
  }
}
