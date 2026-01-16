import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/errand_draft.dart';

class TaskListInput extends StatefulWidget {
  final List<ErrandTaskDraft> tasks;
  final VoidCallback onChanged;

  const TaskListInput({super.key, required this.tasks, required this.onChanged});

  @override
  State<TaskListInput> createState() => _TaskListInputState();
}

class _TaskListInputState extends State<TaskListInput> {
  void _addTask() {
    setState(() {
      widget.tasks.add(ErrandTaskDraft(description: "", price: 0));
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.tasks.asMap().entries.map((entry) {
          int index = entry.key;
          ErrandTaskDraft task = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                // Task Input
                Expanded(
                  flex: 2,
                  child: _buildField(
                    label: "Task",
                    hint: "Enter a task",
                    onChanged: (val) => task.description = val,
                  ),
                ),
                // Dashed Line Connector
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text("----", style: TextStyle(color: Color(0xFF2E2E7E))),
                ),
                // Price Input
                Expanded(
                  flex: 1,
                  child: _buildField(
                    label: "Price",
                    hint: "XAF",
                    isNumber: true,
                    onChanged: (val) => task.price = int.tryParse(val) ?? 0,
                  ),
                ),
              ],
            ),
          );
        }).toList(),

        // Plus Button
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _addTask,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF4FDFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E2E7E).withOpacity(0.2)),
              ),
              child: const Icon(Icons.add, color: Color(0xFF2E2E7E)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required Function(String) onChanged,
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E2E7E), fontSize: 16)),
        const SizedBox(height: 8),
        TextFormField(
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
          onChanged: (v) {
            onChanged(v);
            widget.onChanged();
          },
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF4FDFF),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFF2E2E7E)),
            ),
          ),
        ),
      ],
    );
  }
}