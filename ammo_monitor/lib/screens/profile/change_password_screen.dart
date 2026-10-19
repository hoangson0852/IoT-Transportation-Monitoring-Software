import 'package:flutter/material.dart';
import 'success_update_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  bool showOld = false;
  bool showNew = false;
  bool showConfirm = false;

  final oldCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Change password",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Ensure it differs from previous ones for security",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),

            const SizedBox(height: 25),

            // Old password
            const Text("Password", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _passwordField(
              controller: oldCtrl,
              hint: "Enter your password",
              show: showOld,
              onToggle: () => setState(() => showOld = !showOld),
            ),

            const SizedBox(height: 18),

            // New password
            const Text("New password", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _passwordField(
              controller: newCtrl,
              hint: "Enter your password",
              show: showNew,
              onToggle: () => setState(() => showNew = !showNew),
            ),

            const SizedBox(height: 18),

            // Confirm password
            const Text("Confirm password", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _passwordField(
              controller: confirmCtrl,
              hint: "Enter your password",
              show: showConfirm,
              onToggle: () => setState(() => showConfirm = !showConfirm),
            ),

            const SizedBox(height: 40),

            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  // Check empty fields
                  if (oldCtrl.text.isEmpty || newCtrl.text.isEmpty || confirmCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please fill in all fields.")),
                    );
                    return;
                  }

                  // Check password match
                  if (newCtrl.text != confirmCtrl.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("New password and confirm password do not match.")),
                    );
                    return;
                  }

                  // If everything is correct → go to success screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SuccessUpdateScreen(),
                    ),
                  );
                },
                child: const Text(
                  "Confirm",
                  style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Password input UI
  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool show,
    required VoidCallback onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: !show,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.grey),
              ),
            ),
          ),
          GestureDetector(
            onTap: onToggle,
            child: Icon(
              show ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
