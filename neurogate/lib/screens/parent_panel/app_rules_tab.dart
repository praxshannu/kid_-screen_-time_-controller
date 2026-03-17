import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_state.dart';

class AppRulesTab extends StatefulWidget {
  const AppRulesTab({super.key});

  @override
  State<AppRulesTab> createState() => _AppRulesTabState();
}

class _AppRulesTabState extends State<AppRulesTab> {
  static const platform = MethodChannel('com.neurogate/apps');
  List<dynamic> _apps = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchApps();
  }

  Future<void> _fetchApps() async {
    try {
      final List<dynamic>? result =
          await platform.invokeMethod('getInstalledApps');
      if (mounted) {
        setState(() {
          _apps = result ?? [];
          _isLoading = false;
        });
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get apps: '${e.message}'.");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> get _filteredApps {
    if (_searchQuery.isEmpty) return _apps;
    return _apps.where((app) {
      final name = (app as Map)['name']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.apps, color: Colors.purpleAccent, size: 24),
                ),
                const SizedBox(width: 14),
                const Text(
                  'App Rules',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'Tag each app as Taxed, Free, or Blocked to control access.',
              style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search apps…',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  prefixIcon: Icon(Icons.search,
                      color: Colors.white.withOpacity(0.3), size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (q) => setState(() => _searchQuery = q),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // App list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredApps.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No apps found on device.'
                              : 'No apps match "$_searchQuery".',
                          style: const TextStyle(color: Colors.white38),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        itemCount: _filteredApps.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (context, index) {
                          final app =
                              _filteredApps[index] as Map<dynamic, dynamic>;
                          final String name = app['name'] ?? 'Unknown';
                          final String packageName =
                              app['packageName'] ?? '';
                          final AppTag tag = appState.getAppTag(packageName);

                          return _AppRuleItem(
                            name: name,
                            packageName: packageName,
                            currentTag: tag,
                            onTagChanged: (newTag) {
                              appState.setAppTag(packageName, newTag);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _AppRuleItem extends StatelessWidget {
  const _AppRuleItem({
    required this.name,
    required this.packageName,
    required this.currentTag,
    required this.onTagChanged,
  });

  final String name;
  final String packageName;
  final AppTag currentTag;
  final ValueChanged<AppTag> onTagChanged;

  Color get _tagColor {
    switch (currentTag) {
      case AppTag.taxed:
        return Colors.amber;
      case AppTag.free:
        return Colors.greenAccent;
      case AppTag.blocked:
        return Colors.redAccent;
    }
  }

  IconData get _tagIcon {
    switch (currentTag) {
      case AppTag.taxed:
        return Icons.toll;
      case AppTag.free:
        return Icons.lock_open;
      case AppTag.blocked:
        return Icons.block;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // App icon placeholder
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _tagColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_tagIcon, color: _tagColor, size: 20),
          ),
          const SizedBox(width: 14),
          // App info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  packageName,
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Tag dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _tagColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _tagColor.withOpacity(0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AppTag>(
                value: currentTag,
                isDense: true,
                dropdownColor: const Color(0xFF1E293B),
                icon: Icon(Icons.arrow_drop_down,
                    color: _tagColor, size: 18),
                style: TextStyle(color: _tagColor, fontSize: 12),
                items: const [
                  DropdownMenuItem(
                      value: AppTag.taxed,
                      child: Text('Taxed',
                          style: TextStyle(color: Colors.amber))),
                  DropdownMenuItem(
                      value: AppTag.free,
                      child: Text('Free',
                          style: TextStyle(color: Colors.greenAccent))),
                  DropdownMenuItem(
                      value: AppTag.blocked,
                      child: Text('Blocked',
                          style: TextStyle(color: Colors.redAccent))),
                ],
                onChanged: (newTag) {
                  if (newTag != null) onTagChanged(newTag);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
