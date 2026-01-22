import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:dotted_border/dotted_border.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../components/runam_slider.dart';
import '../../../app/router.dart';

class ErrandInProgressScreen extends StatefulWidget {
  final Map<String, dynamic> errand;
  final bool isRunner;

  static const String routeName = "errand-in-progress";
  static const String path = "/errand-in-progress";

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
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  // Track checked state for each task
  late List<bool> _checkedStates;

  // --- Data Helpers ---
  String get userName => widget.isRunner
      ? (widget.errand['userName'] ?? widget.errand['requester']?['firstName'] ?? "Client")
      : (widget.errand['runnerName'] ?? "Your Runner");

  String get avatarUrl => widget.isRunner
      ? (widget.errand['imageUrl'] ?? widget.errand['requester']?['avatar'] ?? "")
      : (widget.errand['runnerAvatar'] ?? "");

  double get totalPrice {
    // Always prefer backend-calculated total price for accuracy
    final price = widget.errand['totalPrice'] ?? widget.errand['quoted_total_price'] ?? widget.errand['price'] ?? 0;
    return (price is num) ? price.toDouble() : double.tryParse(price.toString()) ?? 0.0;
  }

  List<dynamic> get tasks => widget.errand['tasks'] ?? [];

  @override
  void initState() {
    super.initState();
    // Initialize checked states for tasks
    _checkedStates = List.generate(tasks.length, (index) => tasks[index]['completed'] ?? false);
  }

  @override
  void didUpdateWidget(covariant ErrandInProgressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update checked states if tasks change
    if (oldWidget.errand['tasks'] != widget.errand['tasks']) {
      _checkedStates = List.generate(tasks.length, (index) => tasks[index]['completed'] ?? false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutral100,
      body: Stack(
        children: [
          // 1. Map Background (Consistent with HomeScreen)
          mapbox.MapWidget(
            cameraOptions: mapbox.CameraOptions(
              zoom: 15.0,
              center: mapbox.Point(coordinates: mapbox.Position(11.5021, 3.8480)),
            ),
            onMapCreated: (map) => mapboxMap = map,
          ),

          // 2. Chat FAB (Floating above the sheet)
          _buildFloatingChat(),

          // 3. Draggable Sheet (Same Skeleton as HomeScreen)
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.35,
            maxChildSize: 0.9,
            snap: true,
            controller: _sheetController,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: AppTheme.secondary500,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDragHandle(),
                      const SizedBox(height: 20),
                      _buildUserHeader(),
                      const SizedBox(height: 25),

                      Text(widget.isRunner ? "Tasks to complete" : "Errand Progress",
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.primary700, fontWeight: FontWeight.bold)),

                      const SizedBox(height: 15),
                      if (widget.isRunner) ..._buildRunnerTasks() else _buildBuyerStatus(),

                      const SizedBox(height: 30),
                      _buildBottomAction(),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : const AssetImage('assets/images/ghost.png') as ImageProvider,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName, style: const TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.w900, fontSize: 18)),
                Text(widget.isRunner ? "Buyer" : "Runner", style: TextStyle(color: AppTheme.primary700.withAlpha((0.6 * 255).toInt()), fontSize: 12)),
                // put the respective trust score here
              ],
            ),
          ),
          _vDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(children: [
              Image.asset('assets/images/cash.png', width: 22),
              const Text("CASH", style: TextStyle(color: AppTheme.primary700, fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          ),
          _vDivider(),
          const SizedBox(width: 8),
          Text("XAF ${totalPrice.toStringAsFixed(0)}", style: const TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildTaskItem(String label, String price, bool checked, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.w600))),
          Text("XAF $price", style: const TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              setState(() {
                _checkedStates[index] = !_checkedStates[index];
              });
            },
            child: Icon(_checkedStates[index] ? Icons.check_circle : Icons.radio_button_unchecked, color: AppTheme.primary700),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRunnerTasks() {
    return [
      for (int i = 0; i < tasks.length; i++)
        _buildTaskItem(
          tasks[i]['description'] ?? tasks[i].toString(),
          (tasks[i]['price'] ?? 0).toString(),
          _checkedStates[i],
          i,
        ),
      const SizedBox(height: 15),
      Row(
        children: [
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
              onTap: (){
                // Something
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(IconsaxPlusLinear.eye, color: AppTheme.primary700),
                  SizedBox(width: 8),
                  Text(
                    "View image",
                    style: TextStyle(color: AppTheme.primary700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 30,),
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
              onTap: (){
                // Something
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(IconsaxPlusLinear.export, color: AppTheme.primary700),
                  SizedBox(width: 8),
                  Text(
                    "Upload proof",
                    style: TextStyle(color: AppTheme.primary700),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    ];
  }

  Widget _buildBuyerStatus() {
    return Column(
      children: [
        _buildProgressBar(),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              const Icon(IconsaxPlusLinear.location, color: AppTheme.primary700),
              const SizedBox(width: 12),
              Expanded(child: Text("Runner is currently at the store", style: TextStyle(color: AppTheme.primary700.withAlpha((0.8 * 255).toInt())))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction() {
    return RunAmSlider(
      buttonText: widget.isRunner ? "Complete" : "Cancel Errand",
      circleColor: widget.isRunner ? AppTheme.success : Colors.red,
      borderColor: AppTheme.primary700,
      textStyle: const TextStyle(color: AppTheme.primary700, fontSize: 30, fontWeight: FontWeight.w900),
      onComplete: () {
        // Use GoRouter and rootNavigatorKey to go to home
        final navContext = rootNavigatorKey.currentContext ?? context;
        GoRouter.of(navContext).go('/home');
      },
    );
  }

  // --- Helper Widgets ---
  Widget _buildDragHandle() => Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: AppTheme.primary700.withAlpha((0.2 * 255).toInt()), borderRadius: BorderRadius.circular(10))));

  Widget _buildFloatingChat() => Positioned(
    top: MediaQuery.of(context).padding.top + 20,
    right: 20,
    child: FloatingActionButton.extended(
      onPressed: () {},
      backgroundColor: Colors.white,
      label: const Text("Chat", style: TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.w800)),
      icon: const Icon(IconsaxPlusLinear.message, color: AppTheme.primary700),
    ),
  );

  Widget _buildProgressBar() {
    return Row(
      children: [
        _stepIcon(Icons.assignment_turned_in, true),
        _stepLine(true),
        _stepIcon(Icons.directions_run, true),
        _stepLine(false),
        _stepIcon(Icons.home, false),
      ],
    );
  }

  Widget _stepIcon(IconData icon, bool active) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: active ? AppTheme.primary700 : Colors.white, shape: BoxShape.circle, border: Border.all(color: AppTheme.primary700.withAlpha((0.2 * 255).toInt()))),
    child: Icon(icon, color: active ? Colors.white : AppTheme.primary700.withAlpha((0.3 * 255).toInt()), size: 20),
  );

  Widget _stepLine(bool active) => Expanded(child: Container(height: 2, color: active ? AppTheme.primary700 : AppTheme.primary700.withAlpha((0.2 * 255).toInt())));

  Widget _vDivider() => Container(height: 30, width: 1.5, color: AppTheme.primary700.withAlpha((0.2 * 255).toInt()));
}
