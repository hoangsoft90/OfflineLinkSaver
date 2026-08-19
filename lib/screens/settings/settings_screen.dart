import 'package:flutter/material.dart';
import '../../repositories/article_repository.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Storage section
                _buildSectionHeader('Storage'),
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('Total Articles'),
                  trailing: Text('$_totalArticles'),
                ),
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('Storage Used'),
                  trailing: Text(_formatBytes(_storageUsage)),
                ),

                const Divider(),

                // About section
                _buildSectionHeader('About'),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Offline Link Saver'),
                  subtitle: Text('Version 1.0.0'),
                ),
                const ListTile(
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('Privacy Policy'),
                  subtitle: Text(
                    'Saved content is stored locally on your device. '
                    'The app does not upload your library to a cloud account. '
                    'No account required.',
                  ),
                ),

                const Divider(),

                // Support section
                _buildSectionHeader('Support'),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & FAQ'),
                  onTap: () {
                    // TODO: Add help screen
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Report a Bug'),
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
