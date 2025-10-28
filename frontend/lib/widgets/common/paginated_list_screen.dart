import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../../config/dashboard_constants.dart';
import 'state_widgets.dart';

/// Generic paginated list screen widget that handles loading, error, empty states,
/// search, and pull-to-refresh functionality.
///
/// Example usage:
/// ```dart
/// PaginatedListScreen<Address>(
///   title: 'Manage Addresses',
///   appBarColor: Colors.blue,
///   loadItems: (token) => addressService.getAddresses(token),
///   itemBuilder: (address) => AddressCard(address: address),
///   emptyIcon: Icons.location_off,
///   emptyTitle: 'No addresses yet',
///   emptyMessage: 'Add your first delivery address',
///   floatingActionButton: FloatingActionButton(...),
/// )
/// ```
class PaginatedListScreen<T> extends StatefulWidget {
  /// Screen title displayed in AppBar
  final String title;

  /// AppBar background color
  final Color appBarColor;

  /// Function to load items from API. Receives token if provided.
  final Future<List<T>> Function(String? token) loadItems;

  /// Builder function for individual list items
  final Widget Function(T item, int index) itemBuilder;

  /// Optional search filter function
  final bool Function(T item, String query)? searchFilter;

  /// Empty state configuration
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final Widget? emptyAction;

  /// Error state configuration
  final IconData? errorIcon;

  /// Optional floating action button
  final Widget? floatingActionButton;

  /// Optional auth token for API calls
  final String? token;

  /// Whether to enable search functionality
  final bool enableSearch;

  /// Search hint text
  final String searchHint;

  /// Optional leading widget in AppBar
  final Widget? leading;

  /// Custom padding for list items
  final EdgeInsets? listPadding;

  /// Whether to use card layout for items
  final bool useCardLayout;

  /// Callback when screen needs to refresh (e.g., after navigation)
  final VoidCallback? onRefreshNeeded;

  const PaginatedListScreen({
    super.key,
    required this.title,
    required this.appBarColor,
    required this.loadItems,
    required this.itemBuilder,
    this.searchFilter,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptyMessage,
    this.emptyAction,
    this.errorIcon,
    this.floatingActionButton,
    this.token,
    this.enableSearch = false,
    this.searchHint = 'Search...',
    this.leading,
    this.listPadding,
    this.useCardLayout = false,
    this.onRefreshNeeded,
  });

  @override
  State<PaginatedListScreen<T>> createState() =>
      PaginatedListScreenState<T>();
}

class PaginatedListScreenState<T> extends State<PaginatedListScreen<T>> {
  List<T> _items = [];
  List<T> _filteredItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Load items from API
  Future<void> _loadItems() async {
    developer.log('Loading items for ${widget.title}',
        name: 'PaginatedListScreen');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await widget.loadItems(widget.token);
      developer.log('Loaded ${items.length} items', name: 'PaginatedListScreen');

      if (mounted) {
        setState(() {
          _items = items;
          _filterItems();
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error loading items',
        name: 'PaginatedListScreen',
        error: e,
        stackTrace: stackTrace,
      );

      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Filter items based on search query
  void _filterItems() {
    if (!widget.enableSearch || _searchQuery.isEmpty) {
      _filteredItems = _items;
      return;
    }

    if (widget.searchFilter != null) {
      _filteredItems = _items
          .where((item) => widget.searchFilter!(item, _searchQuery))
          .toList();
    } else {
      _filteredItems = _items;
    }
  }

  /// Handle search query changes
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filterItems();
    });
  }

  /// Build the main body content based on state
  Widget _buildBody() {
    // Loading state
    if (_isLoading) {
      return LoadingStateWidget(message: 'Loading ${widget.title}...');
    }

    // Error state
    if (_errorMessage != null) {
      return ErrorStateWidget(
        message: _errorMessage!,
        onRetry: _loadItems,
        icon: widget.errorIcon,
      );
    }

    // Empty state
    if (_filteredItems.isEmpty) {
      // Show different message if search is active
      if (widget.enableSearch && _searchQuery.isNotEmpty) {
        return EmptyStateWidget(
          icon: Icons.search_off,
          title: 'No results found',
          message: 'Try adjusting your search',
        );
      }

      return EmptyStateWidget(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        message: widget.emptyMessage,
        action: widget.emptyAction,
      );
    }

    // List view with pull-to-refresh
    return RefreshIndicator(
      onRefresh: _loadItems,
      child: ListView.builder(
        padding: widget.listPadding ??
            const EdgeInsets.all(DashboardConstants.cardPaddingSmall),
        itemCount: _filteredItems.length,
        itemBuilder: (context, index) {
          final item = _filteredItems[index];
          final itemWidget = widget.itemBuilder(item, index);

          if (widget.useCardLayout) {
            return Card(
              margin: const EdgeInsets.only(
                  bottom: DashboardConstants.cardPaddingSmall),
              elevation: DashboardConstants.cardElevationSmall,
              child: itemWidget,
            );
          }

          return itemWidget;
        },
      ),
    );
  }

  /// Build search bar
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(DashboardConstants.cardPaddingSmall),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: widget.searchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
                DashboardConstants.cardBorderRadiusSmall),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.appBarColor,
        leading: widget.leading,
      ),
      body: Column(
        children: [
          if (widget.enableSearch) _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }

  /// Public method to trigger reload (can be called by parent)
  void reload() {
    _loadItems();
  }
}
