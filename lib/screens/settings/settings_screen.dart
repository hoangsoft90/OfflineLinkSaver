import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../repositories/article_repository.dart';
import '../../main.dart' show OfflineLinkSaverApp;

class SettingsScreen extends StatefulWidget {
  final ArticleRepository repository;

  const SettingsScreen({
    super.key,
    required this.repository,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _totalArticles = 0;
  int _storageUsage = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final totalArticles = await widget.repository.getTotalArticleCount();
      final storageUsage = await widget.repository.getStorageUsage();

      setState(() {
        _totalArticles = totalArticles;
        _storageUsage = storageUsage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _showLanguagePicker() {
    final l10n = AppLocalizations.of(context);
    final currentLocale = Localizations.localeOf(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.settingsLanguage,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            // System default
            RadioListTile<String>(
              title: const Text('System default'),
              subtitle: Text(
                WidgetsBinding.instance.platformDispatcher.locale.languageCode.toUpperCase(),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              value: '',
              groupValue: currentLocale.languageCode,
              onChanged: (value) {
                OfflineLinkSaverApp.of(context).clearLocale();
                Navigator.pop(context);
              },
            ),

            // English
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: currentLocale.languageCode,
              onChanged: (value) {
                OfflineLinkSaverApp.of(context).setLocale(const Locale('en'));
                Navigator.pop(context);
              },
            ),

            // Vietnamese
            RadioListTile<String>(
              title: const Text('Tiếng Việt'),
              value: 'vi',
              groupValue: currentLocale.languageCode,
              onChanged: (value) {
                OfflineLinkSaverApp.of(context).setLocale(const Locale('vi'));
                Navigator.pop(context);
              },
            ),

            // Chinese (Simplified)
            RadioListTile<String>(
              title: const Text('简体中文'),
              value: 'zh',
              groupValue: currentLocale.languageCode,
              onChanged: (value) {
                OfflineLinkSaverApp.of(context).setLocale(const Locale('zh'));
                Navigator.pop(context);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // ── Language ──
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(l10n.settingsLanguage),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Localizations.localeOf(context).languageCode.toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: _showLanguagePicker,
                ),

                const Divider(),

                // ── Storage section ──
                _buildSectionHeader(l10n.settingsStorage),
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: Text(l10n.settingsTotalArticles),
                  trailing: Text('$_totalArticles'),
                ),
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(l10n.settingsStorageUsed),
                  trailing: Text(_formatBytes(_storageUsage)),
                ),

                const Divider(),

                // ── About section ──
                _buildSectionHeader(l10n.settingsAbout),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.appTitle),
                  subtitle: Text(l10n.settingsVersion('1.0.0')),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l10n.settingsPrivacy),
                  subtitle: Text(
                    l10n.settingsPrivacyText,
                  ),
                ),

                const Divider(),

                // ── Support section ──
                _buildSectionHeader(l10n.settingsSupport),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: Text(l10n.settingsHelp),
                  onTap: () {
                    // TODO: Add help screen
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: Text(l10n.settingsReportBug),
                  onTap: () {
                    // TODO: Add bug report
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
