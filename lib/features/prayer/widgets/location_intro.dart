import 'package:flutter/material.dart';
import 'package:untitled/core/app_theme.dart';
import 'package:untitled/features/prayer/cities.dart';

/// First visit: explain why we want the location before Android asks, and
/// offer a city list so declining is never a dead end.
class LocationIntro extends StatelessWidget {
  final bool locating;
  final String? error;
  final VoidCallback onUseLocation;
  final VoidCallback onPickCity;
  const LocationIntro({
    super.key,
    required this.locating,
    required this.error,
    required this.onUseLocation,
    required this.onPickCity,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                  color: AppColors.tealSoft, borderRadius: BorderRadius.circular(32)),
              child: Icon(Icons.location_on_rounded, size: 52, color: primary),
            ),
            const SizedBox(height: 22),
            Text('مواقيت دقيقة لمكانك',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)),
            const SizedBox(height: 10),
            Text(
              'نستخدم موقعك التقريبي لحساب مواقيت الصلاة واتجاه القبلة. '
              'يبقى الموقع على جهازك ولا يُرسل لأي مكان.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.7, color: AppColors.subtle),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.amberSoft, borderRadius: BorderRadius.circular(14)),
                child: Text(error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.text)),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: locating ? null : onUseLocation,
                icon: locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location_rounded),
                label: const Text('استخدام موقعي'),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: locating ? null : onPickCity,
              icon: const Icon(Icons.location_city_rounded),
              label: const Text('اختيار المدينة يدويًا'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Searchable city list in a bottom sheet.
Future<City?> pickCity(BuildContext context) {
  return showModalBottomSheet<City>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => const _CitySheet(),
  );
}

class _CitySheet extends StatefulWidget {
  const _CitySheet();

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = _q.isEmpty
        ? cities
        : cities.where((c) => c.name.contains(_q.trim())).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'ابحث عن مدينة',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text('لا توجد مدينة بهذا الاسم',
                        style: TextStyle(color: AppColors.subtle)))
                : ListView.builder(
                    padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
                    itemCount: list.length,
                    itemBuilder: (_, i) => ListTile(
                      leading: Icon(Icons.location_on_outlined, color: AppColors.subtle),
                      title: Text(list[i].name, style: TextStyle(color: AppColors.text)),
                      onTap: () => Navigator.pop(context, list[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
