import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:dotted_border/dotted_border.dart';
import '../../../app/theme.dart';
import '../../../components/runam_slider.dart';

class ErrandInProgressScreen extends StatefulWidget {
  final Map<String, dynamic> errand;
  final bool isRunner; // Pass true for Runner's view, false for Buyer's view

  const ErrandInProgressScreen({
    super.key,
    required this.errand,
    this.isRunner = true,
  });

  @override
  State<ErrandInProgressScreen> createState() => _ErrandInProgressScreenState();
}

class _ErrandInProgressScreenState extends State<ErrandInProgressScreen> {
  mapbox.MapboxMap? mapboxMap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Map Background
          mapbox.MapWidget(
            cameraOptions: mapbox.CameraOptions(
              zoom: 14.0,
              center: mapbox.Point(coordinates: mapbox.Position(11.5021, 3.8480)),
            ),
            onMapCreated: (map) => mapboxMap = map,
          ),

          // 2. Back Button
          Positioned(
            top: 50,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppTheme.primary700, width: 1.5),
                ),
                child: Icon(IconsaxPlusLinear.arrow_left_2, color: AppTheme.primary700),
              ),
            ),
          ),

          // 3. Chat Floating Button
          Positioned(
            bottom: widget.isRunner ? 430 : 250, // Adjust based on sheet content height
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppTheme.primary700, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Row(
                children: [
                  Icon(IconsaxPlusLinear.messages_3, color: AppTheme.primary700),
                  const SizedBox(width: 8),
                  Text("chat", style: TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          // 4. Content Sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 30),
              decoration: BoxDecoration(
                color: AppTheme.secondary300,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: widget.isRunner ? _buildRunnerView() : _buildBuyerView(),
            ),
          ),
        ],
      ),
    );
  }

  // IMAGE 2: BUYER'S PERSPECTIVE
  Widget _buildBuyerView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserHeader(isBuyer: true),
        const SizedBox(height: 20),
        Text("Where your runner's at",
            style: TextStyle(color: AppTheme.primary700, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _buildProgressBar(),
        const SizedBox(height: 25),
        RunAmSlider(
          buttonText: "Cancel",
          circleColor: Colors.red,
          borderColor: AppTheme.primary700,
          textStyle: TextStyle(color: AppTheme.primary700, fontSize: 28, fontWeight: FontWeight.w900),
          onComplete: () {},
        ),
        const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text("Cancelling will come with charges",
                style: TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // IMAGE 3: RUNNER'S PERSPECTIVE
  Widget _buildRunnerView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserHeader(isBuyer: false),
        const SizedBox(height: 20),
        // Tasks from your logic
        _buildTaskItem("Buy bread", "200", true),
        _buildTaskItem("Deposit Document", "2000", false),
        _buildTaskItem("Buy soap", "500", false),
        const SizedBox(height: 10),
        Text("In 24mins", style: TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        DottedBorder(
          options: RoundedRectDottedBorderOptions(
            radius: const Radius.circular(16),
            dashPattern: const [5, 5],
            strokeWidth: 2,
            color: AppTheme.primary700,
            padding: const EdgeInsets.all(10),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {},
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(IconsaxPlusLinear.export, color: AppTheme.primary700),
                SizedBox(width: 8),
                Text(
                  "Upload image (optional)",
                  style: TextStyle(color: AppTheme.primary700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text("Where you're at",
            style: TextStyle(color: AppTheme.primary700, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        _buildProgressBar(),
      ],
    );
  }

  Widget _buildUserHeader({required bool isBuyer}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          CircleAvatar(radius: 26, backgroundImage: AssetImage('assets/images/ghost.png')),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isBuyer) Text("From The ICT University", style: TextStyle(color: AppTheme.primary700.withOpacity(0.6), fontSize: 12)),
                Text(isBuyer ? "Joshua | M" : "Michel | M",
                    style: TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          if (!isBuyer) ...[
            Image.asset('assets/images/cash-icon.png', width: 20),
            const SizedBox(width: 4),
            Text("cash", style: TextStyle(color: AppTheme.primary700, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
          Container(height: 30, width: 2, color: AppTheme.primary700, margin: const EdgeInsets.symmetric(horizontal: 10)),
          Text("XAF 2700", style: TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: AppTheme.primary700, shape: BoxShape.circle),
          child: const Icon(Icons.check, color: Colors.white, size: 20),
        ),
        Expanded(child: Container(height: 4, color: AppTheme.primary700)),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary700.withOpacity(0.3))),
          child: Icon(Icons.refresh, color: AppTheme.primary700.withOpacity(0.3), size: 20),
        ),
        Expanded(child: Container(height: 4, color: AppTheme.primary700.withOpacity(0.3))),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary700.withOpacity(0.3))),
          child: Icon(Icons.more_horiz, color: AppTheme.primary700.withOpacity(0.3), size: 20),
        ),
      ],
    );
  }

  Widget _buildTaskItem(String label, String price, bool checked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.primary700.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.w500))),
          Text("XAF", style: TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(border: Border.all(color: AppTheme.primary700.withOpacity(0.2)), borderRadius: BorderRadius.circular(10)),
            child: Text(price, style: TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: checked ? AppTheme.primary700 : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.primary700),
            ),
            child: checked ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
          ),
        ],
      ),
    );
  }
}