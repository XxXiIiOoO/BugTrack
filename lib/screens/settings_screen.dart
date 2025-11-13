import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../service/settings_service.dart';
import '../widgets/main_drawer.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings.title'))),
      drawer: const MainDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.t('settings.theme'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(value: ThemeMode.system, label: Text(l10n.t('settings.theme.system')), icon: const Icon(Icons.brightness_auto)),
              ButtonSegment(value: ThemeMode.light,  label: Text(l10n.t('settings.theme.light')),   icon: const Icon(Icons.light_mode)),
              ButtonSegment(value: ThemeMode.dark,   label: Text(l10n.t('settings.theme.dark')),    icon: const Icon(Icons.dark_mode)),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (set) => s.setThemeMode(set.first),
          ),
          const SizedBox(height: 24),

          Text(l10n.t('settings.language'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'ru', label: Text(l10n.t('settings.language.ru'))),
              ButtonSegment(value: 'en', label: Text(l10n.t('settings.language.en'))),
            ],
            selected: {s.languageCode},
            onSelectionChanged: (set) => s.setLanguage(set.first),
          ),
          const SizedBox(height: 24),

          Text(l10n.t('settings.defaultStatus'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: s.defaultStatusFilter.isEmpty ? null : s.defaultStatusFilter,
            items: [
              DropdownMenuItem(value: 'Open', child: Text(l10n.t('status.open'))),
              DropdownMenuItem(value: 'In Progress', child: Text(l10n.t('status.inProgress'))),
              DropdownMenuItem(value: 'Done', child: Text(l10n.t('status.done'))),
            ],
            onChanged: (v) => s.setDefaultStatus(v ?? ''),
            decoration: InputDecoration(
              hintText: l10n.t('common.all'),
              prefixIcon: const Icon(Icons.filter_alt),
            ),
          ),
          const SizedBox(height: 24),

          SwitchListTile(
            title: Text(l10n.t('settings.notifications')),
            value: s.notificationsEnabled,
            onChanged: (v) => s.setNotifications(v),
          ),

          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => s.reset(),
            icon: const Icon(Icons.restore),
            label: Text(l10n.t('settings.reset')),
          ),
        ],
      ),
    );
  }
}
