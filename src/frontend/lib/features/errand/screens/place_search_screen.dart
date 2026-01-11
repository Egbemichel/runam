import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/mapbox_service.dart';
import '../models/errand_location.dart';


class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({super.key});

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final controller = TextEditingController();
  final mapbox = MapboxService();
  final results = <ErrandLocation>[].obs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search location")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: (q) async {
                if (q.length < 3) {
                  results.clear();
                  return;
                }
                results.assignAll((await mapbox.searchPlaces(q)) as Iterable<ErrandLocation>);
              },
              decoration: const InputDecoration(
                hintText: "Search place",
              ),
            ),
          ),
          Expanded(
            child: Obx(() => ListView.builder(
              itemCount: results.length,
              itemBuilder: (_, i) {
                final place = results[i];
                return ListTile(
                  title: Text(place.address),
                  onTap: () => Get.back(result: place),
                );
              },
            )),
          ),
        ],
      ),
    );
  }
}
