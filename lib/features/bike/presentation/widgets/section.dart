import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, color: AppColors.muted),
      ),
    );
  }
}

/// Cartão branco com título, subtítulo e um controle embaixo.
class SettingCard extends StatelessWidget {
  const SettingCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class NavTile extends StatelessWidget {
  const NavTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Icon(icon, color: AppColors.text),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Linha "rótulo ........ valor" para telas de informação.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
