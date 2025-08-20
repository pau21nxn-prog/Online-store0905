import 'package:flutter/material.dart';
import 'dart:async';
import '../services/advanced_search_service.dart';
import '../common/theme.dart';

class SearchAutocompleteWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(String)? onSuggestionSelected;
  final Function(String)? onSearchSubmitted;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool showRecentSearches;
  final int maxSuggestions;

  const SearchAutocompleteWidget({
    super.key,
    required this.controller,
    this.onSuggestionSelected,
    this.onSearchSubmitted,
    this.hintText = 'Search products...',
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.showRecentSearches = true,
    this.maxSuggestions = 8,
  });

  @override
  State<SearchAutocompleteWidget> createState() => _SearchAutocompleteWidgetState();
}

class _SearchAutocompleteWidgetState extends State<SearchAutocompleteWidget> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  
  List<SearchSuggestion> _suggestions = [];
  List<String> _recentSearches = [];
  bool _isLoading = false;
  Timer? _debounceTimer;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
    _loadRecentSearches();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _onTextChanged() {
    final query = widget.controller.text;
    if (query == _currentQuery) return;
    
    _currentQuery = query;
    
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      _updateOverlay();
      return;
    }

    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      _updateOverlay();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    try {
      final suggestions = await AdvancedSearchService.getAutocomplete(query);
      
      if (mounted && query == _currentQuery) {
        setState(() {
          _suggestions = suggestions.take(widget.maxSuggestions).toList();
          _isLoading = false;
        });
        _updateOverlay();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
        _updateOverlay();
      }
      debugPrint('Error fetching suggestions: $e');
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: _getTextFieldWidth(),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, _getTextFieldHeight()),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            child: _buildSuggestionsDropdown(),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  double _getTextFieldWidth() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.width ?? 300;
  }

  double _getTextFieldHeight() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.height ?? 48;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: widget.prefixIcon ?? const Icon(Icons.search),
          suffixIcon: _buildSuffixIcon(),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          _hideOverlay();
          _saveRecentSearch(value);
          widget.onSearchSubmitted?.call(value);
        },
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (widget.controller.text.isNotEmpty) {
      return IconButton(
        onPressed: () {
          widget.controller.clear();
          _focusNode.requestFocus();
        },
        icon: const Icon(Icons.clear),
      );
    }

    return widget.suffixIcon;
  }

  Widget _buildSuggestionsDropdown() {
    final hasQuery = _currentQuery.isNotEmpty;
    final hasSuggestions = _suggestions.isNotEmpty;
    final hasRecentSearches = _recentSearches.isNotEmpty && widget.showRecentSearches;

    if (!hasQuery && !hasRecentSearches) {
      return const SizedBox.shrink();
    }

    if (hasQuery && !hasSuggestions && !_isLoading) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: const Text(
          'No suggestions found',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search suggestions
            if (hasSuggestions) ...[
              _buildSectionHeader('Suggestions'),
              ..._suggestions.map((suggestion) => _buildSuggestionTile(suggestion)),
            ],

            // Recent searches (only show when no query or no suggestions)
            if ((!hasQuery || (!hasSuggestions && !_isLoading)) && hasRecentSearches) ...[
              if (hasSuggestions) const Divider(),
              _buildSectionHeader('Recent Searches'),
              ..._recentSearches.take(5).map((search) => _buildRecentSearchTile(search)),
              if (_recentSearches.length > 5)
                _buildClearRecentTile(),
            ],

            // Popular searches (could be added)
            if (!hasQuery && !hasRecentSearches) ...[
              _buildSectionHeader('Popular Searches'),
              ..._getPopularSearches().map((search) => _buildPopularSearchTile(search)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSuggestionTile(SearchSuggestion suggestion) {
    IconData icon;
    Color iconColor;
    
    switch (suggestion.type) {
      case SearchType.products:
        icon = Icons.shopping_bag_outlined;
        iconColor = AppTheme.primaryOrange;
        break;
      case SearchType.suggestions:
        icon = Icons.search;
        iconColor = Colors.grey;
        break;
      case SearchType.autocomplete:
        icon = Icons.trending_up;
        iconColor = Colors.blue;
        break;
    }

    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: iconColor),
      title: _buildHighlightedText(suggestion.text, _currentQuery),
      subtitle: suggestion.type == SearchType.products && suggestion.metadata['productId'] != null
          ? Text('Product', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
          : null,
      trailing: suggestion.popularity > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Popular',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : null,
      onTap: () => _selectSuggestion(suggestion.text),
    );
  }

  Widget _buildRecentSearchTile(String search) {
    return ListTile(
      dense: true,
      leading: Icon(Icons.history, size: 20, color: Colors.grey.shade400),
      title: Text(search),
      trailing: IconButton(
        icon: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
        onPressed: () => _removeRecentSearch(search),
      ),
      onTap: () => _selectSuggestion(search),
    );
  }

  Widget _buildClearRecentTile() {
    return ListTile(
      dense: true,
      leading: Icon(Icons.clear_all, size: 20, color: Colors.grey.shade400),
      title: Text(
        'Clear recent searches',
        style: TextStyle(color: Colors.grey.shade600),
      ),
      onTap: _clearRecentSearches,
    );
  }

  Widget _buildPopularSearchTile(String search) {
    return ListTile(
      dense: true,
      leading: Icon(Icons.trending_up, size: 20, color: Colors.blue.shade400),
      title: Text(search),
      onTap: () => _selectSuggestion(search),
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(text);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) {
      return Text(text);
    }

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: text.substring(index + query.length)),
        ],
      ),
    );
  }

  void _selectSuggestion(String suggestion) {
    widget.controller.text = suggestion;
    _hideOverlay();
    _saveRecentSearch(suggestion);
    widget.onSuggestionSelected?.call(suggestion);
  }

  // Recent searches management
  void _loadRecentSearches() {
    // In a real app, you'd load from SharedPreferences or secure storage
    _recentSearches = [
      'smartphone',
      'laptop',
      'running shoes',
      'wireless headphones',
    ];
  }

  void _saveRecentSearch(String search) {
    if (search.trim().isEmpty) return;
    
    setState(() {
      _recentSearches.remove(search); // Remove if exists
      _recentSearches.insert(0, search); // Add to beginning
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.take(10).toList();
      }
    });
    
    // In a real app, you'd save to SharedPreferences or secure storage
  }

  void _removeRecentSearch(String search) {
    setState(() {
      _recentSearches.remove(search);
    });
    _updateOverlay();
  }

  void _clearRecentSearches() {
    setState(() {
      _recentSearches.clear();
    });
    _updateOverlay();
  }

  List<String> _getPopularSearches() {
    return [
      'iPhone',
      'Samsung Galaxy',
      'Nike shoes',
      'Laptop',
      'Gaming chair',
      'Bluetooth speaker',
    ];
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _hideOverlay();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }
}