import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../app/theme.dart';
import '../models/place_models.dart';
import '../screens/location/location_search.dart';
import '../services/mapbox_service.dart';

/// A reusable location search field with autocomplete functionality
/// Uses Mapbox Places API for location search
class LocationSearchField extends StatefulWidget {
  /// Text controller for the search field
  final TextEditingController? controller;

  /// Callback when a place is selected from the autocomplete list
  final Function(Place) onPlaceSelected;

  /// Hint text for the search field
  final String hintText;

  /// Label text displayed above the field (optional)
  final String? label;

  /// Icon to display as suffix
  final Widget? suffixIcon;

  /// Minimum characters before search is triggered
  final int minSearchLength;

  /// Whether the field is enabled
  final bool enabled;

  /// Custom decoration (overrides default)
  final InputDecoration? decoration;

  /// Fill color for the text field
  final Color? fillColor;

  /// Border radius for the text field
  final double borderRadius;

  const LocationSearchField({
    super.key,
    this.controller,
    required this.onPlaceSelected,
    this.hintText = 'Search for a location',
    this.label,
    this.suffixIcon,
    this.minSearchLength = 3,
    this.enabled = true,
    this.decoration,
    this.fillColor,
    this.borderRadius = 30,
  });

  @override
  State<LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<LocationSearchField> {
  late TextEditingController _controller;
  final MapboxService _mapboxService = MapboxService();
  final FocusNode _focusNode = FocusNode();

  List<Place> _results = [];
  bool _isSearching = false;
  bool _hasError = false;
  bool _ownsController = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    _lastQuery = query;

    if (query.length < widget.minSearchLength) {
      if (mounted) {
        setState(() {
          _results.clear();
          _hasError = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
        _hasError = false;
      });
    }

    try {
      final places = await _mapboxService.searchPlaces(query);

      // Only update if this is still the latest query and widget is still mounted
      if (mounted && query == _lastQuery) {
        setState(() {
          _results = places;
          _isSearching = false;
          _hasError = places.isEmpty && query.length >= widget.minSearchLength;
        });
      }
    } catch (e) {
      if (mounted && query == _lastQuery) {
        setState(() {
          _isSearching = false;
          _hasError = true;
          _results = [];
        });
      }
      debugPrint('Error searching places: $e');
    }
  }

  void _onPlaceSelected(Place place) {
    _controller.text = place.name;
    widget.onPlaceSelected(place);
    if (mounted) {
      setState(() {
        _results.clear();
        _hasError = false;
      });
    }
    _focusNode.unfocus();
  }

  InputDecoration _buildDecoration() {
    if (widget.decoration != null) {
      return widget.decoration!;
    }

    return InputDecoration(
      hintText: widget.hintText,
      suffixIcon: _isSearching
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : widget.suffixIcon ?? const Icon(IconsaxPlusLinear.gps),
      filled: true,
      fillColor: widget.fillColor ?? const Color(0xFFF8F9FA),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 10,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: const BorderSide(color: AppTheme.primary500, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Optional label
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(
              color: AppTheme.primary700,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Search text field
        TextField(
          controller: _controller,
          readOnly: true,
          enabled: widget.enabled,
          decoration: _buildDecoration(),
          onTap: () async {
            FocusManager.instance.primaryFocus?.unfocus();

            final place = await Navigator.push<Place>(
              context,
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => LocationSearchScreen(
                  initialQuery: _controller.text,
                ),
              ),
            );

            if (place != null) {
              _controller.text = place.name;
              widget.onPlaceSelected(place);
            }
          },
        ),


        // Autocomplete results - simple conditional rendering
        if (_results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final place = _results[index];

                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        IconsaxPlusLinear.location,
                        size: 20,
                        color: AppTheme.primary500,
                      ),
                      title: Text(
                        place.name,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        place.formattedAddress,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _onPlaceSelected(place),
                    );
                  },
                ),
              ),
            ),
          ),

        // Error message when no results or network error
        if (_hasError && !_isSearching && _lastQuery.length >= widget.minSearchLength)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_off, size: 18, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No results found. Check your connection and try again.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

