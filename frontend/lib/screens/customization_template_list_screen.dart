import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../models/customization_template.dart';
import '../services/customization_template_service.dart';
import '../config/dashboard_constants.dart';
import 'customization_template_form_screen.dart';

/// Customization Template List Screen
///
/// Displays list of customization templates for admins (all templates) or vendors (own + system-wide templates).
/// Provides create, edit, delete, and view functionality with role-based access control.
class CustomizationTemplateListScreen extends StatefulWidget {
  final String token;
  final String userType; // 'admin' or 'vendor'

  const CustomizationTemplateListScreen({
    super.key,
    required this.token,
    required this.userType,
  });

  @override
  State<CustomizationTemplateListScreen> createState() =>
      _CustomizationTemplateListScreenState();
}

class _CustomizationTemplateListScreenState
    extends State<CustomizationTemplateListScreen> {
  final CustomizationTemplateService _templateService =
      CustomizationTemplateService();

  List<CustomizationTemplate> _templates = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isAdmin => widget.userType == 'admin';

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      developer.log(
        'Loading ${_isAdmin ? "admin" : "vendor"} templates',
        name: 'CustomizationTemplateListScreen',
      );

      final templates = _isAdmin
          ? await _templateService.getAdminTemplates(widget.token)
          : await _templateService.getVendorTemplates(widget.token);

      setState(() {
        _templates = templates;
        _isLoading = false;
      });

      developer.log(
        'Loaded ${templates.length} templates',
        name: 'CustomizationTemplateListScreen',
      );
    } catch (e) {
      developer.log(
        'Error loading templates: $e',
        name: 'CustomizationTemplateListScreen',
        error: e,
      );

      setState(() {
        _errorMessage = 'Failed to load templates: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTemplate(CustomizationTemplate template) async {
    // Check if user can delete this template
    if (!_isAdmin && template.isSystemWide) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete system-wide templates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text(
          'Are you sure you want to delete "${template.name}"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete template via API
      if (_isAdmin) {
        await _templateService.deleteAdminTemplate(widget.token, template.id!);
      } else {
        await _templateService.deleteVendorTemplate(widget.token, template.id!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Deleted template "${template.name}"'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload templates
      await _loadTemplates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to delete template: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _navigateToCreateTemplate() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomizationTemplateFormScreen(
          token: widget.token,
          userType: widget.userType,
        ),
      ),
    );

    if (result == true) {
      await _loadTemplates();
    }
  }

  Future<void> _navigateToEditTemplate(CustomizationTemplate template) async {
    // Check if user can edit this template
    if (!_isAdmin && template.isSystemWide) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot edit system-wide templates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomizationTemplateFormScreen(
          token: widget.token,
          userType: widget.userType,
          template: template,
        ),
      ),
    );

    if (result == true) {
      await _loadTemplates();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin
            ? 'Customization Templates (Admin)'
            : 'Customization Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTemplates,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateTemplate,
        icon: const Icon(Icons.add),
        label: const Text('New Template'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Templates',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadTemplates,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.layers_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Templates Yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Create your first customization template'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToCreateTemplate,
              icon: const Icon(Icons.add),
              label: const Text('Create Template'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTemplates,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 80, // Space for FAB
        ),
        itemCount: _templates.length,
        itemBuilder: (context, index) {
          final template = _templates[index];
          return _buildTemplateCard(template);
        },
      ),
    );
  }

  Widget _buildTemplateCard(CustomizationTemplate template) {
    final canEdit = _isAdmin || !template.isSystemWide;

    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          DashboardConstants.cardBorderRadiusSmall,
        ),
      ),
      child: InkWell(
        onTap: () => _navigateToEditTemplate(template),
        borderRadius: BorderRadius.circular(
          DashboardConstants.cardBorderRadiusSmall,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name and badges
              Row(
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  // System-wide badge
                  if (template.isSystemWide)
                    Chip(
                      label: const Text(
                        'System-wide',
                        style: TextStyle(fontSize: 11),
                      ),
                      backgroundColor: Colors.blue.shade100,
                      labelStyle: TextStyle(color: Colors.blue.shade900),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  const SizedBox(width: 8),
                  // Active/Inactive badge
                  Chip(
                    label: Text(
                      template.isActive ? 'Active' : 'Inactive',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: template.isActive
                        ? Colors.green.shade100
                        : Colors.grey.shade300,
                    labelStyle: TextStyle(
                      color: template.isActive
                          ? Colors.green.shade900
                          : Colors.grey.shade700,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (template.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  template.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              // Template info
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _getTemplateInfo(template),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _navigateToEditTemplate(template),
                    icon: Icon(
                      canEdit ? Icons.edit : Icons.visibility,
                      size: 18,
                    ),
                    label: Text(canEdit ? 'Edit' : 'View'),
                  ),
                  if (canEdit) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _deleteTemplate(template),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTemplateInfo(CustomizationTemplate template) {
    final typeDisplay = template.customizationTypeDisplayName;
    final requiredText = template.required ? 'Required' : 'Optional';

    // Show option count for non-text types
    if (template.type != 'text_input') {
      final optionsCount = template.options.length;
      return '$typeDisplay • $optionsCount options • $requiredText';
    } else {
      // For text input, show max length if set
      if (template.maxLength != null) {
        return '$typeDisplay • Max ${template.maxLength} chars • $requiredText';
      } else {
        return '$typeDisplay • $requiredText';
      }
    }
  }
}
