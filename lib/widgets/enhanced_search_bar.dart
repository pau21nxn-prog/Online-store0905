import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'search_autocomplete_widget.dart';
import '../common/theme.dart';

class EnhancedSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final Function(String)? onSearchSubmitted;
  final Function(String)? onSearchChanged;
  final String? hintText;
  final bool enabled;
  final bool showVoiceSearch;
  final bool showCameraSearch;
  final bool showBarcode;
  final VoidCallback? onVoiceSearch;
  final VoidCallback? onCameraSearch;
  final VoidCallback? onBarcodeSearch;
  final VoidCallback? onFiltersPressed;
  final bool hasActiveFilters;
  final EdgeInsetsGeometry? margin;
  final double? elevation;

  const EnhancedSearchBar({
    super.key,
    this.controller,
    this.onSearchSubmitted,
    this.onSearchChanged,
    this.hintText = 'Search products...',
    this.enabled = true,
    this.showVoiceSearch = true,
    this.showCameraSearch = false,
    this.showBarcode = false,
    this.onVoiceSearch,
    this.onCameraSearch,
    this.onBarcodeSearch,
    this.onFiltersPressed,
    this.hasActiveFilters = false,
    this.margin,
    this.elevation = 2,
  });

  @override
  State<EnhancedSearchBar> createState() => _EnhancedSearchBarState();
}

class _EnhancedSearchBarState extends State<EnhancedSearchBar> 
    with TickerProviderStateMixin {
  late TextEditingController _controller;
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
    
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _filterAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _filterAnimationController, curve: Curves.elasticOut),
    );
    
    if (widget.hasActiveFilters) {
      _filterAnimationController.forward();
    }
  }

  @override
  void didUpdateWidget(EnhancedSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasActiveFilters != oldWidget.hasActiveFilters) {
      if (widget.hasActiveFilters) {
        _filterAnimationController.forward();
      } else {
        _filterAnimationController.reverse();
      }
    }
  }

  void _onTextChanged() {
    widget.onSearchChanged?.call(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin ?? const EdgeInsets.all(AppTheme.spacing16),
      child: Material(
        elevation: widget.elevation ?? 2,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            color: Colors.white,
            border: Border.all(
              color: _controller.text.isNotEmpty 
                  ? AppTheme.primaryOrange.withOpacity(0.3)
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              // Main search field
              Expanded(
                child: SearchAutocompleteWidget(
                  controller: _controller,
                  hintText: widget.hintText,
                  enabled: widget.enabled,
                  onSuggestionSelected: (suggestion) {
                    widget.onSearchSubmitted?.call(suggestion);
                  },
                  onSearchSubmitted: (query) {
                    widget.onSearchSubmitted?.call(query);
                  },
                  prefixIcon: _buildSearchIcon(),
                ),
              ),
              
              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchIcon() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Icon(
        Icons.search,
        color: _controller.text.isNotEmpty 
            ? AppTheme.primaryOrange 
            : Colors.grey.shade500,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Voice search
        if (widget.showVoiceSearch)
          _buildActionButton(
            icon: _isListening ? Icons.mic : Icons.mic_none,
            onPressed: _handleVoiceSearch,
            tooltip: 'Voice Search',
            isActive: _isListening,
          ),
        
        // Camera search
        if (widget.showCameraSearch)
          _buildActionButton(
            icon: Icons.camera_alt_outlined,
            onPressed: widget.onCameraSearch,
            tooltip: 'Search by Image',
          ),
        
        // Barcode scanner
        if (widget.showBarcode)
          _buildActionButton(
            icon: Icons.qr_code_scanner,
            onPressed: widget.onBarcodeSearch,
            tooltip: 'Scan Barcode',
          ),
        
        // Filters
        if (widget.onFiltersPressed != null)
          AnimatedBuilder(
            animation: _filterAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _filterAnimation.value,
                child: _buildActionButton(
                  icon: Icons.tune,
                  onPressed: widget.onFiltersPressed,
                  tooltip: 'Filters',
                  isActive: widget.hasActiveFilters,
                  badge: widget.hasActiveFilters,
                ),
              );
            },
          ),
        
        const SizedBox(width: AppTheme.spacing8),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    bool isActive = false,
    bool badge = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              Icon(
                icon,
                color: isActive 
                    ? AppTheme.primaryOrange 
                    : Colors.grey.shade600,
                size: 24,
              ),
              if (badge)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleVoiceSearch() {
    if (!widget.enabled) return;
    
    HapticFeedback.lightImpact();
    
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  void _startListening() {
    setState(() {
      _isListening = true;
    });

    // In a real implementation, you would start speech recognition here
    // For now, we'll simulate it
    _simulateVoiceSearch();
  }

  void _stopListening() {
    setState(() {
      _isListening = false;
    });
  }

  void _simulateVoiceSearch() {
    // Simulate voice recognition
    Future.delayed(const Duration(seconds: 2), () {
      if (_isListening) {
        _controller.text = 'wireless headphones';
        _stopListening();
        widget.onSearchSubmitted?.call(_controller.text);
      }
    });
  }

  @override
  void dispose() {
    _filterAnimationController.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }
}

// Search suggestions overlay (alternative implementation)
class SearchSuggestionsOverlay extends StatelessWidget {
  final List<String> suggestions;
  final Function(String) onSuggestionTap;
  final VoidCallback onClose;

  const SearchSuggestionsOverlay({
    super.key,
    required this.suggestions,
    required this.onSuggestionTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppTheme.radius12),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radius12),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Suggestions',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                  ),
                ],
              ),
            ),
            
            // Suggestions list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.search, size: 20),
                    title: Text(suggestion),
                    onTap: () => onSuggestionTap(suggestion),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Quick search chips for popular searches
class QuickSearchChips extends StatelessWidget {
  final List<String> quickSearches;
  final Function(String) onChipTap;

  const QuickSearchChips({
    super.key,
    required this.quickSearches,
    required this.onChipTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Searches',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: quickSearches.map((search) {
              return ActionChip(
                label: Text(search),
                onPressed: () => onChipTap(search),
                backgroundColor: Colors.grey.shade100,
                labelStyle: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
                side: BorderSide(color: Colors.grey.shade300),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}