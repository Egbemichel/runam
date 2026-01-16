import 'package:flutter/material.dart';

import '../../models/place_models.dart';
import '../../services/mapbox_service.dart';

class LocationSearchScreen extends StatefulWidget {
  final String initialQuery;

  const LocationSearchScreen({super.key, this.initialQuery = ''});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final _controller = TextEditingController();
  final _mapboxService = MapboxService();

  List<Place> _results = [];
  bool _loading = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
  }

  Future<void> _search(String query) async {
    _lastQuery = query;

    if (query.length < 3) {
      setState(() => _results.clear());
      return;
    }

    setState(() => _loading = true);

    try {
      final places = await _mapboxService.searchPlaces(query);
      if (mounted && query == _lastQuery) {
        setState(() {
          _results = places;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _search,
          decoration: const InputDecoration(
            hintText: 'Search location',
            border: InputBorder.none,
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: _results.length,
        itemBuilder: (_, i) {
          final place = _results[i];
          return ListTile(
            leading: const Icon(Icons.location_on),
            title: Text(place.name),
            subtitle: Text(place.formattedAddress),
            onTap: () => Navigator.pop(context, place),
          );
        },
      ),
    );
  }
}
