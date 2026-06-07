import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/core/animations/staggered_entrance.dart';
import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/core/theme/k_text_styles.dart';
import 'package:keyframes_app/core/widgets/widgets.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/service_listing.dart';
import 'package:keyframes_app/features/admin_dashboard/admin_controller.dart';

/// The admin service-listings management screen (Requirements 11.5, 11.6).
///
/// Lists the catalog from [adminServicesProvider] and supports full CRUD:
/// **create** via the floating action button, **read** in the list, **update**
/// via the per-row edit action, and **delete** via a confirm dialog — all
/// persisting through the [ServiceRepository] data layer. Each row also exposes
/// an active toggle that calls [ServiceRepository.setActive] (Requirement
/// 11.6). Create/edit open the [AdminListingEditScreen] via a
/// [MaterialPageRoute] push.
///
/// NOTE: the catalog stream surfaces active-only listings (see
/// [adminServicesProvider]); toggling a listing inactive removes it from this
/// list. This is a documented limitation of the current data layer.
class AdminListingsScreen extends ConsumerWidget {
  /// Creates the admin listings management screen.
  const AdminListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ServiceListing>> servicesAsync =
        ref.watch(adminServicesProvider);

    return Scaffold(
      backgroundColor: KColors.offWhite,
      appBar: AppBar(
        title: const Text('Listings'),
        backgroundColor: KColors.offWhite,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: KColors.navy800,
        foregroundColor: KColors.white,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AdminListingEditScreen(),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New listing'),
      ),
      body: SafeArea(
        top: false,
        child: servicesAsync.when(
          data: (List<ServiceListing> services) {
            if (services.isEmpty) {
              return const _ListingsEmpty();
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                KSpace.lg,
                KSpace.md,
                KSpace.lg,
                KSpace.xxxl,
              ),
              itemCount: services.length,
              itemBuilder: (BuildContext context, int index) {
                final ServiceListing listing = services[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: KSpace.md),
                  child: StaggeredEntrance(
                    index: index,
                    child: _ListingCard(
                      listing: listing,
                      onEdit: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AdminListingEditScreen(listing: listing),
                        ),
                      ),
                      onToggleActive: (bool value) =>
                          _setActive(context, ref, listing, value),
                      onDelete: () => _confirmDelete(context, ref, listing),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const _ListingsLoading(),
          error: (Object error, StackTrace _) => KErrorView(
            message: 'We could not load listings right now.',
            onRetry: () => ref.invalidate(adminServicesProvider),
          ),
        ),
      ),
    );
  }

  Future<void> _setActive(
    BuildContext context,
    WidgetRef ref,
    ServiceListing listing,
    bool active,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(serviceRepositoryProvider).setActive(listing.id, active);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not update the listing. Please try again.'),
            backgroundColor: KColors.danger,
          ),
        );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ServiceListing listing,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete listing?'),
        content: Text(
          'This will permanently remove "${listing.title}" from the catalog.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: KColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(serviceRepositoryProvider).delete(listing.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Deleted "${listing.title}".'),
            backgroundColor: KColors.success,
          ),
        );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not delete the listing. Please try again.'),
            backgroundColor: KColors.danger,
          ),
        );
    }
  }
}

/// A single listing row with edit, delete, and an active toggle.
class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.listing,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final ServiceListing listing;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return KCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      listing.title,
                      style: KTextStyles.titleMd,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: KSpace.xs),
                    Text(
                      categoryLabel(listing.category),
                      style: KTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Text(
                '\$${listing.basePrice.toStringAsFixed(0)}',
                style: KTextStyles.titleMd.copyWith(color: KColors.navy800),
              ),
            ],
          ),
          if (listing.tagline.isNotEmpty) ...<Widget>[
            const SizedBox(height: KSpace.sm),
            Text(
              listing.tagline,
              style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const Divider(height: KSpace.xl),
          Row(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Switch(
                    value: listing.active,
                    activeColor: KColors.success,
                    onChanged: onToggleActive,
                  ),
                  Text(
                    listing.active ? 'Active' : 'Inactive',
                    style: KTextStyles.label.copyWith(color: KColors.slate700),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
                color: KColors.navy600,
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: KColors.danger,
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Empty state when there are no listings.
class _ListingsEmpty extends StatelessWidget {
  const _ListingsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.design_services_rounded,
              size: 56,
              color: KColors.slate500,
            ),
            const SizedBox(height: KSpace.lg),
            Text('No listings yet', style: KTextStyles.headingMd),
            const SizedBox(height: KSpace.sm),
            Text(
              'Tap "New listing" to add your first service to the catalog.',
              textAlign: TextAlign.center,
              style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton while listings load.
class _ListingsLoading extends StatelessWidget {
  const _ListingsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KSpace.lg,
        KSpace.md,
        KSpace.lg,
        KSpace.xxxl,
      ),
      children: <Widget>[
        for (int i = 0; i < 4; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: KSpace.md),
            child: KShimmer.box(height: 150),
          ),
      ],
    );
  }
}

/// The create/update form for a [ServiceListing] (Requirement 11.5).
///
/// When [listing] is `null` the screen creates a new listing; otherwise it
/// edits the supplied one. On save it builds a [ServiceListing] (reusing the
/// existing id, or an empty id so the data layer allocates one for a create)
/// and persists it through [ServiceRepository.upsert], then pops.
class AdminListingEditScreen extends ConsumerStatefulWidget {
  /// Creates the edit screen; pass [listing] to edit, omit to create.
  const AdminListingEditScreen({this.listing, super.key});

  /// The listing being edited, or `null` when creating a new one.
  final ServiceListing? listing;

  @override
  ConsumerState<AdminListingEditScreen> createState() =>
      _AdminListingEditScreenState();
}

class _AdminListingEditScreenState
    extends ConsumerState<AdminListingEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _taglineController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _galleryController;
  late final TextEditingController _priceController;
  late final TextEditingController _estimatedDaysController;

  late ServiceCategory _category;
  late bool _active;
  bool _saving = false;

  bool get _isEditing => widget.listing != null;

  @override
  void initState() {
    super.initState();
    final ServiceListing? listing = widget.listing;
    _titleController = TextEditingController(text: listing?.title ?? '');
    _taglineController = TextEditingController(text: listing?.tagline ?? '');
    _descriptionController =
        TextEditingController(text: listing?.description ?? '');
    _galleryController =
        TextEditingController(text: (listing?.gallery ?? const <String>[]).join('\n'));
    _priceController = TextEditingController(
      text: listing != null ? listing.basePrice.toStringAsFixed(2) : '',
    );
    _estimatedDaysController = TextEditingController(
      text: listing != null ? listing.estimatedDays.toString() : '',
    );
    _category = listing?.category ?? ServiceCategory.itServices;
    _active = listing?.active ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _taglineController.dispose();
    _descriptionController.dispose();
    _galleryController.dispose();
    _priceController.dispose();
    _estimatedDaysController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final List<String> gallery = _galleryController.text
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();

    final double basePrice =
        double.tryParse(_priceController.text.trim()) ?? 0.0;
    final int estimatedDays =
        int.tryParse(_estimatedDaysController.text.trim()) ?? 0;

    final ServiceListing draft = ServiceListing(
      id: widget.listing?.id ?? '',
      title: _titleController.text.trim(),
      tagline: _taglineController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _category,
      basePrice: basePrice,
      gallery: gallery,
      deliverables: widget.listing?.deliverables ?? const <String>[],
      thumbnailUrl: widget.listing?.thumbnailUrl,
      active: _active,
      estimatedDays: estimatedDays,
    );

    setState(() => _saving = true);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(serviceRepositoryProvider).upsert(draft);
      if (!mounted) {
        return;
      }
      navigator.pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not save the listing. Please try again.'),
            backgroundColor: KColors.danger,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.offWhite,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit listing' : 'New listing'),
        backgroundColor: KColors.offWhite,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              KSpace.lg,
              KSpace.lg,
              KSpace.lg,
              KSpace.xxxl,
            ),
            children: <Widget>[
              _LabeledField(
                label: 'Title',
                child: TextFormField(
                  controller: _titleController,
                  decoration: _inputDecoration('e.g. Mobile App Development'),
                  validator: (String? value) {
                    final String text = (value ?? '').trim();
                    if (text.length < 3 || text.length > 80) {
                      return 'Title must be 3 to 80 characters.';
                    }
                    return null;
                  },
                ),
              ),
              _LabeledField(
                label: 'Category',
                child: DropdownButtonFormField<ServiceCategory>(
                  value: _category,
                  decoration: _inputDecoration(null),
                  items: <DropdownMenuItem<ServiceCategory>>[
                    for (final ServiceCategory category
                        in ServiceCategory.values)
                      DropdownMenuItem<ServiceCategory>(
                        value: category,
                        child: Text(categoryLabel(category)),
                      ),
                  ],
                  onChanged: (ServiceCategory? value) {
                    if (value != null) {
                      setState(() => _category = value);
                    }
                  },
                ),
              ),
              _LabeledField(
                label: 'Tagline',
                child: TextFormField(
                  controller: _taglineController,
                  decoration: _inputDecoration('A short, catchy summary'),
                ),
              ),
              _LabeledField(
                label: 'Description',
                child: TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 6,
                  decoration:
                      _inputDecoration('Describe what this service includes'),
                ),
              ),
              _LabeledField(
                label: 'Gallery URLs (one per line)',
                child: TextFormField(
                  controller: _galleryController,
                  minLines: 2,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  decoration:
                      _inputDecoration('https://…\nhttps://…'),
                ),
              ),
              _LabeledField(
                label: 'Base price',
                child: TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: _inputDecoration('e.g. 499'),
                  validator: (String? value) {
                    final double? parsed =
                        double.tryParse((value ?? '').trim());
                    if (parsed == null || parsed < 0) {
                      return 'Enter a base price of 0 or more.';
                    }
                    return null;
                  },
                ),
              ),
              _LabeledField(
                label: 'Estimated days',
                child: TextFormField(
                  controller: _estimatedDaysController,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: _inputDecoration('e.g. 14'),
                ),
              ),
              const SizedBox(height: KSpace.sm),
              SwitchListTile(
                value: _active,
                activeColor: KColors.success,
                contentPadding: EdgeInsets.zero,
                title: Text('Active', style: KTextStyles.titleMd),
                subtitle: Text(
                  'Active listings are visible to clients in the catalog.',
                  style: KTextStyles.caption,
                ),
                onChanged: (bool value) => setState(() => _active = value),
              ),
              const SizedBox(height: KSpace.xl),
              KPrimaryButton(
                label: _isEditing ? 'Save changes' : 'Create listing',
                icon: Icons.check_rounded,
                expanded: true,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
      filled: true,
      fillColor: KColors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: KSpace.md,
        vertical: KSpace.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KSpace.rLg),
        borderSide: BorderSide.none,
      ),
    );
  }
}

/// A form field with a label above it.
class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: KTextStyles.label.copyWith(
              color: KColors.slate700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: KSpace.sm),
          child,
        ],
      ),
    );
  }
}

/// Human-readable label for a [ServiceCategory].
String categoryLabel(ServiceCategory category) {
  switch (category) {
    case ServiceCategory.itServices:
      return 'IT Services';
    case ServiceCategory.graphicDesign:
      return 'Graphic Design';
  }
}
