import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/buttons.dart';
import '../../widgets/glass_card.dart';

class PreOrderScreen extends StatefulWidget {
  const PreOrderScreen({super.key, required this.service, required this.tier});
  final ServiceItem service;
  final ServiceTier tier;

  @override
  State<PreOrderScreen> createState() => _PreOrderScreenState();
}

class _PreOrderScreenState extends State<PreOrderScreen> {
  final _brief = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _contact = 'In-app chat';
  bool _submitting = false;

  @override
  void dispose() {
    _brief.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await context.read<AppState>().placePreOrder(
          service: widget.service,
          tier: widget.tier,
          brief: _brief.text,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    _showSuccess();
  }

  void _showSuccess() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _SuccessSheet(
        service: widget.service,
        tier: widget.tier,
      ),
    ).then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    final t = widget.tier;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm pre-order')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
          children: [
            // Summary card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(s.icon, color: AppColors.amberBright),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                        Text('${t.name} · ${t.deliveryDays} days',
                            style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  Text('\$${t.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: AppColors.amberBright,
                          fontWeight: FontWeight.w800,
                          fontSize: 20)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Tell us about your project',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Share goals, references and any must-haves.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brief,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText:
                    'e.g. I need a clean food-delivery app with login, cart and live tracking…',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().length < 10)
                  ? 'Please add a few details (min 10 chars)'
                  : null,
            ),
            const SizedBox(height: 22),
            Text('Preferred contact',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: ['In-app chat', 'Email', 'Phone call']
                  .map((c) => ChoiceChip(
                        label: Text(c),
                        selected: _contact == c,
                        onSelected: (_) => setState(() => _contact = c),
                        labelStyle: TextStyle(
                          color:
                              _contact == c ? Colors.white : AppColors.navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 22),
            // Price breakdown
            SoftCard(
              child: Column(
                children: [
                  _row('Package (${t.name})', '\$${t.price.toStringAsFixed(0)}'),
                  const SizedBox(height: 8),
                  _row('Platform fee', '\$0'),
                  const Divider(height: 22),
                  _row('Total', '\$${t.price.toStringAsFixed(0)}', bold: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.lock_rounded, size: 15, color: AppColors.slate),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'No payment is taken now. This reserves your slot — our team confirms scope in chat first.',
                    style: TextStyle(color: AppColors.slate, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(
            20, 14, 20, 16 + MediaQuery.of(context).padding.bottom),
        color: Colors.white,
        child: GradientButton(
          label: 'Place pre-order',
          loading: _submitting,
          icon: Icons.check_circle_rounded,
          onPressed: _submit,
        ),
      ),
    );
  }

  Widget _row(String l, String r, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 17 : 14,
      color: bold ? AppColors.navy : AppColors.ink,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(l, style: style), Text(r, style: style)],
    );
  }
}

class _SuccessSheet extends StatefulWidget {
  const _SuccessSheet({required this.service, required this.tier});
  final ServiceItem service;
  final ServiceTier tier;

  @override
  State<_SuccessSheet> createState() => _SuccessSheetState();
}

class _SuccessSheetState extends State<_SuccessSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
        ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: AppColors.amberGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 48, color: AppColors.navy),
            ),
          ),
          const SizedBox(height: 20),
          Text('Pre-order placed!',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Your slot for ${widget.service.title} (${widget.tier.name}) is reserved. '
            'Our team will reach out in chat to confirm the details.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: 'View my orders',
            icon: Icons.receipt_long_rounded,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
