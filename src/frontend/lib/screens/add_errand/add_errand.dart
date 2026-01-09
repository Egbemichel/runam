
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../app/theme.dart';
import '../../components/runam_slider.dart';

class AddErrandScreen extends StatefulWidget {
  const AddErrandScreen({super.key});

  static const String routeName = "add-errand";
  static const String path = '/add-errand';

  @override
  State<AddErrandScreen> createState() => _AddErrandScreenState();
}

class _AddErrandScreenState extends State<AddErrandScreen>
    with TickerProviderStateMixin {
  int currentStep = 1;
  String? selectedErrandType;
  String? selectedPayment;
  String? selectedSpeed;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController goToController = TextEditingController();
  final TextEditingController returnToController = TextEditingController();
  final TextEditingController instructionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Add listeners to trigger rebuild when text changes
    goToController.addListener(() => setState(() {}));
    returnToController.addListener(() => setState(() {}));
    instructionController.addListener(() => setState(() {}));
  }

  bool get isFormComplete {
    // Step 1: Errand type selected
    if (selectedErrandType == null) return false;

    // Step 2: Locations filled
    if (goToController.text.isEmpty) return false;
    if (selectedErrandType == "Round-trip" && returnToController.text.isEmpty) return false;

    // Step 3: Instructions filled
    if (instructionController.text.isEmpty) return false;

    // Step 4: Speed selected
    if (selectedSpeed == null) return false;

    // Step 5: Payment method selected
    if (selectedPayment == null) return false;

    return true;
  }

  bool _canProceedFromStep(int step) {
    switch (step) {
      case 1:
        return selectedErrandType != null;
      case 2:
        if (goToController.text.isEmpty) return false;
        if (selectedErrandType == "Round-trip" && returnToController.text.isEmpty) return false;
        return true;
      case 3:
        return instructionController.text.isNotEmpty;
      case 4:
        return selectedSpeed != null;
      case 5:
        return selectedPayment != null;
      default:
        return false;
    }
  }

  @override
  void dispose() {
    goToController.dispose();
    returnToController.dispose();
    instructionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                "New Errand",
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppTheme.primary700,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              Image.asset('assets/images/checklist.png', height: 180),
              const SizedBox(height: 20),
              const Text(
                "What do you need done today?",
                style: TextStyle(
                  color: AppTheme.primary700,
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 30),

              _buildStep(1, "What kind of errand?", _buildErrandTypeSelector()),
              _buildStep(2, "Where should they go?", _buildLocationPicker()),
              _buildStep(3, "What are they doing?", _buildInstructionField()),
              _buildStep(4, "How fast do you want it done?", _buildSpeedDropdown()),
              _buildStep(5, "You got cash?", _buildPaymentPicker(), isLast: true),

              const SizedBox(height: 40),
              RunAmSlider(
                buttonText: "Request",
                enabled: isFormComplete,
                onComplete: () {
                  if (_formKey.currentState!.validate()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Running Errand...")),
                    );
                  }
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(int step, String title, Widget content, {bool isLast = false}) {
    bool isActive = currentStep >= step;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? AppTheme.primary700 : Colors.transparent,
                  border: Border.all(color: AppTheme.primary700, width: 2),
                ),
                child: Icon(
                  Icons.check,
                  size: 16,
                  color: isActive ? Colors.white : Colors.transparent,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppTheme.primary700),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary700,
                  ),
                ),
                const SizedBox(height: 12),
                if (currentStep == step) content,
                if (currentStep == step) _buildNavigationButtons(step, isLast),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildErrandTypeSelector() {
    return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          _typeBtn("Round-trip"),
        const SizedBox(width: 10),
        _typeBtn("One-way"),
      ],
      ),
      if (selectedErrandType != null) ...[ const SizedBox(height: 12),
        AnimatedContainer( duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration( color: AppTheme.neutral100,
            borderRadius: BorderRadius.circular(8), ),
          child: Text(
            selectedErrandType == "Round-trip" ? "Runner has to perform the errand; go somewhere, get something, and return to you in person."
                : "Runner has to perform the errand; go somewhere and deliver something, no in-person meeting.",
            style: const TextStyle(
              color: AppTheme.primary700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ],
  );
  }

  Widget _typeBtn(String label) {
    bool isSelected = selectedErrandType == label;
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            selectedErrandType = label;
          }
          );
          },
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: isSelected ? AppTheme.primary500 : AppTheme.primary700,
            width: isSelected? 1.2 : 1),
          backgroundColor: isSelected ? AppTheme.primary500.withValues(alpha: 0.1) : Colors.transparent, ),
        child: Text( label, style: TextStyle(
          color: AppTheme.primary700,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        ),
      ),
    );
  }
  // ---------------- LOCATION ----------------

  Widget _buildLocationPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondary300,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _locationField(
            controller: goToController,
            label: "Go to",
            hint: "Send them to...",
            icon: const Icon(IconsaxPlusLinear.routing),
            required: true,
          ),
          if (selectedErrandType == "Round-trip") ...[
            const SizedBox(height: 14,),
            _locationField(
              controller: returnToController,
              label: "Return to",
              hint: "Your preferred location",
              icon: const Icon(IconsaxPlusLinear.gps),
              required: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _locationField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Icon icon,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              color: AppTheme.primary700,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            )),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                validator: required
                    ? (val) =>
                val == null || val.isEmpty ? "This field is required" : null
                    : null,
                decoration: _inputDecorationIcon(hint, icon),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------- INSTRUCTIONS ----------------

  Widget _buildInstructionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DottedBorder(
          options: RoundedRectDottedBorderOptions(
            radius: const Radius.circular(16),
            dashPattern: [5, 5],
            strokeWidth: 2,
            color: AppTheme.primary700,
            padding: const EdgeInsets.all(10),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: () {},
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(IconsaxPlusLinear.export, color: AppTheme.primary700),
                SizedBox(width: 8),
                Text("Upload image (optional)",
                    style: TextStyle(color: AppTheme.primary700)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: instructionController,
          maxLines: 4,
          validator: (val) =>
          val == null || val.isEmpty ? "Instructions are required" : null,
          decoration: _inputDecoration("Instructions"),
        ),
      ],
    );
  }


  InputDecoration _inputDecorationIcon(String hint, Icon icon) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: icon,
      filled: true,
      fillColor: AppTheme.neutral100,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: const BorderSide(color: AppTheme.primary500, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.2),
      ),
    );
  }

  // ---------------- INPUT DECORATION ----------------

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppTheme.secondary300,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.secondary300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.primary500),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.2),
      ),
    );
  }

  // ---------------- OTHERS ----------------

  Widget _buildSpeedDropdown() {
    return DropdownButtonFormField<String>(
      decoration: _inputDecoration("Speed"),
      value: selectedSpeed,
      items: const [
        DropdownMenuItem(value: "10", child: Text("10 mins")),
        DropdownMenuItem(value: "15", child: Text("15 mins")),
        DropdownMenuItem(value: "30", child: Text("30 mins")),
      ],
      onChanged: (value) {
        setState(() {
          selectedSpeed = value;
        });
      },
      validator: (val) => val == null ? "Please select a speed" : null,
    );
  }

  Widget _buildPaymentPicker() {
    return Row(
      children: [
        _paymentImage('assets/images/cash.png', 'cash'),
        const SizedBox(width: 15),
        _paymentImage('assets/images/online.png', 'online'),
      ],
    );
  }

  Widget _paymentImage(String assetPath, String key) {
    bool isSelected = selectedPayment == key;
    return GestureDetector(
      onTap: () => setState(() => selectedPayment = key),
      child: DottedBorder(
        options: RoundedRectDottedBorderOptions(
          radius: const Radius.circular(16),
          dashPattern: [5, 5],
          color: isSelected ? AppTheme.primary500 : AppTheme.primary700,
        ),
        child: Image.asset(assetPath, width: 56, height: 56),
      ),
    );
  }

  Widget _buildNavigationButtons(int step, bool isLast) {
    bool canProceed = _canProceedFromStep(step);

    return Row(
      children: [
        if (step > 1)
          TextButton(
            onPressed: () => setState(() => currentStep--),
            child: const Text("Back",
              style: TextStyle(
                color: AppTheme.primary700
              ),
            ),
          ),
        const Spacer(),
        if (!isLast)
          ElevatedButton(
            onPressed: canProceed
                ? () => setState(() => currentStep++)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canProceed ? AppTheme.primary500 : Colors.grey.shade300,
            ),
            child: Text("Next",
              style: TextStyle(
                color: canProceed ? AppTheme.primary700 : Colors.grey.shade600,
              ),
            ),
          ),
      ],
    );
  }
}
