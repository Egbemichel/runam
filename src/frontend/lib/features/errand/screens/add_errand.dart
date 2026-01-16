import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/theme.dart';
import '../../../components/location_search_field.dart';
import '../../../components/runam_slider.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/location_controller.dart';
import '../controllers/errand_controllers.dart';
import '../controllers/errand_draft_controller.dart';
import '../components/task_list_input.dart'; // The dynamic task widget

class AddErrandScreen extends StatefulWidget {
  const AddErrandScreen({super.key});
  static const String routeName = "add-errand";
  static const String path = '/add-errand';

  @override
  State<AddErrandScreen> createState() => _AddErrandScreenState();
}

class _AddErrandScreenState extends State<AddErrandScreen> with TickerProviderStateMixin {
  int currentStep = 1;
  String? selectedErrandType;
  String? selectedPayment;
  String? selectedSpeed;
  File? selectedImage;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController goToController = TextEditingController();
  final TextEditingController returnToController = TextEditingController();

  // REMOVED: instructionController

  final ImagePicker _imagePicker = ImagePicker();
  late final AuthController authController;
  final locationController = Get.find<LocationController>();
  late final ErrandController errandController;
  late final ErrandDraftController draftController;

  @override
  void initState() {
    super.initState();
    authController = Get.find<AuthController>();
    errandController = Get.find<ErrandController>();
    draftController = Get.find<ErrandDraftController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedDraft();
    });

    goToController.addListener(_onTextChanged);
    returnToController.addListener(_onTextChanged);
  }

  void _loadSavedDraft() {
    if (!draftController.isInitialized) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _loadSavedDraft();
      });
      return;
    }

    final draft = draftController.draft.value;

    if (draft.type != null) {
      selectedErrandType = draft.type == "ROUND_TRIP" ? "Round-trip" : "One-way";
      errandController.setType(selectedErrandType!);
    }

    if (draft.goTo != null) {
      goToController.text = draft.goTo!.name;
      errandController.setGoTo(draft.goTo!);
    }
    if (draft.returnTo != null) {
      returnToController.text = draft.returnTo!.name;
      errandController.setReturnTo(draft.returnTo!);
    }

    // TASKS are handled by the errandController.draft directly
    // No text controller needed for the list

    if (draft.speed != null) {
      selectedSpeed = draft.speed;
      errandController.setSpeed(draft.speed!);
    }

    if (draft.paymentMethod != null) {
      selectedPayment = draft.paymentMethod;
      errandController.setPayment(draft.paymentMethod!);
    }

    _updateCurrentStep();
    if (mounted) setState(() {});
  }

  void _updateCurrentStep() {
    final d = errandController.draft.value;
    if (selectedErrandType == null) {
      currentStep = 1;
    } else if (goToController.text.isEmpty ||
        (selectedErrandType == "Round-trip" && returnToController.text.isEmpty)) {
      currentStep = 2;
    } else if (d.tasks.isEmpty || d.tasks.any((t) => t.description.isEmpty)) {
      currentStep = 3;
    } else if (selectedSpeed == null) {
      currentStep = 4;
    } else {
      currentStep = 5;
    }
  }

  void _saveDraft() {
    draftController.updateDraft((d) {
      d.type = selectedErrandType == "Round-trip" ? "ROUND_TRIP" : "ONE_WAY";
      d.goTo = errandController.draft.value.goTo;
      d.returnTo = errandController.draft.value.returnTo;
      d.tasks = errandController.draft.value.tasks; // Sync list
      d.speed = selectedSpeed;
      d.paymentMethod = selectedPayment;
    });
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
      _saveDraft();
    }
  }

  bool get isFormComplete => errandController.draft.value.isComplete;

  bool _canProceedFromStep(int step) {
    final d = errandController.draft.value;
    switch (step) {
      case 1: return selectedErrandType != null;
      case 2:
        if (goToController.text.isEmpty) return false;
        if (selectedErrandType == "Round-trip" && returnToController.text.isEmpty) return false;
        return true;
      case 3:
        return d.tasks.isNotEmpty && d.tasks.every((t) => t.description.trim().isNotEmpty && t.price > 0);
      case 4: return selectedSpeed != null;
      case 5: return selectedPayment != null;
      default: return false;
    }
  }

  @override
  void dispose() {
    _saveDraft();
    goToController.removeListener(_onTextChanged);
    returnToController.removeListener(_onTextChanged);
    goToController.dispose();
    returnToController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text("New Errand", style: Theme.of(context).textTheme.displaySmall?.copyWith(color: AppTheme.primary700, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              Image.asset('assets/images/checklist.png', height: 180),
              const SizedBox(height: 30),

              _buildStep(1, "What kind of errand?", _buildErrandTypeSelector()),
              _buildStep(2, "Where should they go?", _buildLocationPicker()),
              _buildStep(3, "What are they doing?", _buildTaskField()), // Updated
              _buildStep(4, "How fast?", _buildSpeedDropdown()),
              _buildStep(5, "Payment", _buildPaymentPicker(), isLast: true),

              const SizedBox(height: 40),
              Obx(() => RunAmSlider(
                buttonText: "Request",
                enabled: isFormComplete,
                onComplete: () async {
                  try {
                    await errandController.createErrand();
                    await draftController.clearDraft();
                    if (mounted) Navigator.of(context).pop();
                  } catch (e) {
                    Get.snackbar("Error", e.toString(), backgroundColor: AppTheme.error);
                  }
                },
              )),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- UPDATED TASK FIELD ---
  Widget _buildTaskField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImagePicker(),
        const SizedBox(height: 16),
        // Binding TaskListInput to the ErrandController's draft
        Obx(() => TaskListInput(
          tasks: errandController.draft.value.tasks,
          onChanged: () {
            errandController.draft.refresh(); // Trigger Obx
            _saveDraft();
            setState(() {}); // Update "Next" button state
          },
        )),
      ],
    );
  }

  // --- IMAGE PICKER HELPER ---
  Widget _buildImagePicker() {
    // Always return a Widget; use a ternary to avoid fallthrough/implicit null returns
    return selectedImage == null
        ? DottedBorder(
            options: RoundedRectDottedBorderOptions(
              radius: const Radius.circular(16),
              dashPattern: const [5, 5],
              strokeWidth: 2,
              color: AppTheme.primary700,
              padding: const EdgeInsets.all(10),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickImage,
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
          )
        : Stack(
            children: [
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primary500, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    selectedImage!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _removeImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary700.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(IconsaxPlusLinear.edit, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "Change",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
  }

  // Helper methods for Steps, TypeSelector, LocationPicker, etc. remain largely similar 
  // but use _canProceedFromStep(step) for validation.

  Widget _buildStep(int step, String title, Widget content, {bool isLast = false}) {
    bool isCompleted = _canProceedFromStep(step);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(shape: BoxShape.circle, color: isCompleted ? AppTheme.primary700 : Colors.transparent, border: Border.all(color: AppTheme.primary700)),
              child: Icon(Icons.check, size: 16, color: isCompleted ? Colors.white : Colors.transparent),
            ),
            if (!isLast) Expanded(child: Container(width: 2, color: AppTheme.primary700)),
          ]),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary700)),
              if (currentStep == step) ...[const SizedBox(height: 12), content, _buildNavigationButtons(step, isLast)],
              const SizedBox(height: 30),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(int step, bool isLast) {
    bool canProceed = _canProceedFromStep(step);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (step > 1) TextButton(onPressed: () => setState(() => currentStep--), child: const Text("Back")),
          const Spacer(),
          if (!isLast) ElevatedButton(
            onPressed: canProceed ? () => setState(() => currentStep++) : null,
            child: const Text("Next"),
          ),
        ],
      ),
    );
  }

  // Placeholder logic for rest of UI components
  Widget _buildErrandTypeSelector() => Row(children: [_typeBtn("Round-trip"), const SizedBox(width: 10), _typeBtn("One-way")]);
  Widget _typeBtn(String label) {
    bool isSelected = selectedErrandType == label;
    return Expanded(child: OutlinedButton(
      style: OutlinedButton.styleFrom(backgroundColor: isSelected ? AppTheme.primary500.withValues(alpha: 0.1) : null),
      onPressed: () { setState(() => selectedErrandType = label); errandController.setType(label); _saveDraft(); },
      child: Text(label),
    ));
  }

  Widget _buildLocationPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.secondary300, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        LocationSearchField(controller: goToController, label: "Go to", onPlaceSelected: (p) { errandController.setGoTo(p); setState(() {}); }),
        if (selectedErrandType == "Round-trip") ...[
          const SizedBox(height: 12),
          LocationSearchField(controller: returnToController, label: "Return to", onPlaceSelected: (p) { errandController.setReturnTo(p); setState(() {}); }),
        ]
      ]),
    );
  }

  Widget _buildSpeedDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedSpeed,
      items: ["10", "15", "30"].map((s) => DropdownMenuItem(value: s, child: Text("$s mins"))).toList(),
      onChanged: (v) { setState(() => selectedSpeed = v); errandController.setSpeed(v!); _saveDraft(); },
      decoration: _inputDecoration("Speed"),
    );
  }

  Widget _buildPaymentPicker() {
    return Row(children: [_paymentImage('assets/images/cash.png', 'CASH'), const SizedBox(width: 15), _paymentImage('assets/images/online.png', 'ONLINE')]);
  }

  Widget _paymentImage(String path, String key) {
    bool isSelected = selectedPayment == key;
    return GestureDetector(
      onTap: () { setState(() => selectedPayment = key); errandController.setPayment(key); _saveDraft(); },
      child: DottedBorder(
        options: RoundedRectDottedBorderOptions(radius: const Radius.circular(16), color: isSelected ? AppTheme.primary500 : AppTheme.primary700),
        child: Image.asset(path, width: 56, height: 56),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(hintText: hint, filled: true, fillColor: AppTheme.secondary300, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none));


  Widget _imageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.secondary300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppTheme.primary700),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.primary700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Select Image Source",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.primary700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _imageSourceOption(
                    icon: IconsaxPlusLinear.camera,
                    label: "Camera",
                    onTap: () async {
                      Navigator.pop(context);
                      final XFile? image = await _imagePicker.pickImage(
                        source: ImageSource.camera,
                        maxWidth: 1080,
                        maxHeight: 1080,
                        imageQuality: 85,
                      );
                      if (image != null) {
                        setState(() {
                          selectedImage = File(image.path);
                        });
                        errandController.setImage(selectedImage);
                      }
                    },
                  ),
                  _imageSourceOption(
                    icon: IconsaxPlusLinear.gallery,
                    label: "Gallery",
                    onTap: () async {
                      Navigator.pop(context);
                      final XFile? image = await _imagePicker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1080,
                        maxHeight: 1080,
                        imageQuality: 85,
                      );
                      if (image != null) {
                        setState(() {
                          selectedImage = File(image.path);
                        });
                        errandController.setImage(selectedImage);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
  void _removeImage() {
    setState(() {
      selectedImage = null;
    });
    errandController.setImage(null);
  }
}