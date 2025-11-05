import 'package:flutter/material.dart';
import '../../models/system_setting.dart';
import '../../services/system_settings_service.dart';
import '../../widgets/settings/setting_card.dart';

/// System Settings Management Screen for Admins
///
/// Provides interface for viewing and editing system-wide configuration settings.
/// Settings are organized by category with tabbed navigation and support for
/// batch updates, validation, and unsaved changes tracking.
class SystemSettingsScreen extends StatefulWidget {
  final String token;

  const SystemSettingsScreen({
    super.key,
    required this.token,
  });

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final SystemSettingsService _settingsService = SystemSettingsService();

  // State
  Map<String, List<SystemSetting>> _settingsByCategory = {};
  List<String> _categories = [];
  Map<String, String> _pendingChanges = {}; // key -> new value
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Load all settings from API
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _settingsService.getSettings(widget.token);

      setState(() {
        _settingsByCategory = response.settings;
        _categories = response.categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// Save a single setting change (tracked in pending changes)
  void _onSettingChanged(String key, String newValue) {
    setState(() {
      _pendingChanges[key] = newValue;
    });
  }

  /// Undo changes to a specific setting
  void _undoSetting(String key) {
    setState(() {
      _pendingChanges.remove(key);
    });
  }

  /// Save all pending changes in batch
  Future<void> _saveAllChanges() async {
    if (_pendingChanges.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final response = await _settingsService.batchUpdateSettings(
        widget.token,
        _pendingChanges,
      );

      final result = response.data;
      if (result == null) {
        throw Exception('No data in batch update response');
      }

      if (result.allSucceeded) {
        // All succeeded
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Successfully updated ${result.successCount} settings',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        setState(() {
          _pendingChanges.clear();
          _isSaving = false;
        });
        await _loadSettings(); // Reload to get updated values
      } else {
        // Some failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️  ${result.successCount} succeeded, ${result.failureCount} failed',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'View Errors',
                onPressed: () => _showErrorDialog(result.errors),
              ),
            ),
          );
        }
        setState(() {
          _isSaving = false;
          // Remove successfully updated keys from pending
          for (final key in result.updatedKeys) {
            _pendingChanges.remove(key);
          }
        });
        await _loadSettings(); // Reload to get updated values
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isSaving = false;
      });
    }
  }

  /// Show dialog with error details
  void _showErrorDialog(List<BatchUpdateError> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Errors'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: errors.length,
            itemBuilder: (context, index) {
              final error = errors[index];
              return ListTile(
                leading: const Icon(Icons.error, color: Colors.red),
                title: Text(error.key),
                subtitle: Text(error.message),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Discard all pending changes
  void _discardChanges() {
    setState(() {
      _pendingChanges.clear();
    });
  }

  /// Get current value for a setting (pending or original)
  SystemSetting _getSettingWithPendingValue(SystemSetting setting) {
    if (_pendingChanges.containsKey(setting.settingKey)) {
      return setting.copyWith(
        settingValue: _pendingChanges[setting.settingKey],
      );
    }
    return setting;
  }

  /// Filter settings by search query
  List<SystemSetting> _filterSettings(List<SystemSetting> settings) {
    if (_searchQuery.isEmpty) return settings;

    final query = _searchQuery.toLowerCase();
    return settings.where((setting) {
      return setting.settingKey.toLowerCase().contains(query) ||
          setting.description.toLowerCase().contains(query) ||
          setting.settingValue.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Wrap with DefaultTabController when categories are available
    if (_categories.isNotEmpty) {
      return DefaultTabController(
        length: _categories.length,
        child: Scaffold(
          appBar: _buildAppBar(),
          body: _buildBody(),
          bottomNavigationBar: _pendingChanges.isNotEmpty
              ? _buildBottomActionBar()
              : null,
        ),
      );
    }

    // Without tabs when no categories
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _pendingChanges.isNotEmpty
          ? _buildBottomActionBar()
          : null,
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('System Settings'),
      actions: [
        if (_pendingChanges.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Chip(
              label: Text('${_pendingChanges.length} unsaved'),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadSettings,
          tooltip: 'Refresh',
        ),
      ],
      bottom: _categories.isNotEmpty
          ? TabBar(
              isScrollable: true,
              tabs: _categories.map((category) {
                return Tab(
                  text: _formatCategoryName(category),
                  icon: _getCategoryIcon(category),
                );
              }).toList(),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Error loading settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadSettings,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_categories.isEmpty) {
      return const Center(
        child: Text('No settings available'),
      );
    }

    return Column(
      children: [
        // Search bar
        _buildSearchBar(),
        // Settings list
        Expanded(
          child: TabBarView(
            children: _categories.map((category) {
              return _buildCategorySettings(category);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search settings...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildCategorySettings(String category) {
    final settings = _settingsByCategory[category] ?? [];
    final filteredSettings = _filterSettings(settings);

    if (filteredSettings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No settings in this category'
                  : 'No settings match your search',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSettings,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: filteredSettings.length,
        itemBuilder: (context, index) {
          final setting = filteredSettings[index];
          final isModified = _pendingChanges.containsKey(setting.settingKey);
          final displaySetting = _getSettingWithPendingValue(setting);

          return SettingCard(
            setting: displaySetting,
            onSave: (newValue) => _onSettingChanged(setting.settingKey, newValue),
            isModified: isModified,
            onUndo: isModified
                ? () => _undoSetting(setting.settingKey)
                : null,
          );
        },
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_pendingChanges.length} unsaved changes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'These changes will be saved together',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            OutlinedButton(
              onPressed: _isSaving ? null : _discardChanges,
              child: const Text('Discard'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAllChanges,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save All'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCategoryName(String category) {
    return category[0].toUpperCase() + category.substring(1);
  }

  Icon _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'orders':
        return const Icon(Icons.shopping_cart);
      case 'payments':
        return const Icon(Icons.payment);
      case 'delivery':
        return const Icon(Icons.local_shipping);
      case 'system':
        return const Icon(Icons.settings);
      case 'business':
        return const Icon(Icons.business);
      default:
        return const Icon(Icons.category);
    }
  }
}
