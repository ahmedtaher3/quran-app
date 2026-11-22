import 'package:flutter/material.dart';
import 'package:untitled/core/app_theme.dart';

/// Section heading in the prayer settings screens.
class SettingsTitle extends StatelessWidget {
  final String text;
  const SettingsTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 18, 8, 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.heading)),
      );
}

/// Rounded card holding a section's rows.
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const SettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}
