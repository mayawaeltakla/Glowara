/// عناصر واجهة مشتركة بهوية Glowara.
library glowara.widgets;

import 'package:flutter/material.dart';
import 'package:glowara/core/localization/app_localizations.dart';
import 'package:glowara/core/theme/app_theme.dart';

/// صفحة فرعية موحّدة (AppBar + محتوى).
class GlowPage extends StatelessWidget {
  const GlowPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.fab,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? fab;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: c.scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: actions,
      ),
      floatingActionButton: fab,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// بطاقة سطحية موحّدة.
class GlowCard extends StatelessWidget {
  const GlowCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.gradient,
    this.margin,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? c.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
        boxShadow: <BoxShadow>[
          BoxShadow(color: c.shadow, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: card,
    );
  }
}

/// عنوان قسم مع إجراء اختياري.
class GlowSectionTitle extends StatelessWidget {
  const GlowSectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 18, color: c.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.onSurface,
                  ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// حالة فارغة واضحة.
class GlowEmptyState extends StatelessWidget {
  const GlowEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.primaryContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 32, color: c.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.onSurfaceVariant, height: 1.5),
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// مربع إحصائية صغير.
class GlowStatTile extends StatelessWidget {
  const GlowStatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final color = accent ?? c.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) Icon(icon, size: 16, color: color),
              if (icon != null) const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.onSurface),
          ),
        ],
      ),
    );
  }
}

/// شريط تقدم أنيق.
class GlowProgress extends StatelessWidget {
  const GlowProgress({super.key, required this.value, this.height = 8, this.color});

  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0).toDouble(),
        minHeight: height,
        backgroundColor: c.primaryContainer,
        valueColor: AlwaysStoppedAnimation<Color>(color ?? c.primary),
      ),
    );
  }
}

/// زر اختيار سريع (chip).
class GlowChoiceChip extends StatelessWidget {
  const GlowChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? c.primary : c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 15, color: selected ? c.onPrimary : c.onSurfaceVariant),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? c.onPrimary : c.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// حوار تأكيد.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String? confirmLabel,
}) async {
  final l10n = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel ?? l10n.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// حوار إدخال نص واحد.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String? initialValue,
  String? hint,
  int maxLines = 1,
}) async {
  final controller = TextEditingController(text: initialValue ?? '');
  final l10n = context.l10n;
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: maxLines,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(null),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
          child: Text(l10n.save),
        ),
      ],
    ),
  );
  return result;
}

/// رسالة خطأ بسيطة.
class GlowErrorView extends StatelessWidget {
  const GlowErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off, size: 44, color: c.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: c.onSurfaceVariant)),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
            ],
          ],
        ),
      ),
    );
  }
}

/// شريط تقدم مع نص ونسبة.
class GlowLabeledProgress extends StatelessWidget {
  const GlowLabeledProgress({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final double value;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.glowColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 13, color: c.onSurface)),
            ),
            Text(
              trailing ?? '${(value * 100).round()}%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.primary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GlowProgress(value: value),
      ],
    );
  }
}
