import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '/providers/theme_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final dobCtrl = TextEditingController();
  final addressCtrl = TextEditingController();

  String? genderValue;
  bool isSaving = false;

  UserModel? get _user => Provider.of<AuthProvider>(context, listen: false).user;

  @override
  void initState() {
    super.initState();

    final user = _user;
    nameCtrl.text = user?.displayName ?? '';
    emailCtrl.text = user?.email ?? '';
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    dobCtrl.dispose();
    addressCtrl.dispose();
    super.dispose();
  }

  Future<void> pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2003, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: 'Select date of birth',
    );

    if (picked == null) return;

    final formatted =
        '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';

    setState(() => dobCtrl.text = formatted);
  }

  Future<void> saveProfile() async {
    final name = nameCtrl.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Please enter your name.');
      return;
    }

    setState(() => isSaving = true);

    try {
      await AuthService().updateDisplayName(name);

      if (!mounted) return;

      _showSnackBar('Profile updated successfully.');
      Navigator.pop(context);
    } catch (_) {
      _showSnackBar('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _avatarText {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return 'O';
    return name.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    final backgroundColor =
        isDark ? const Color(0xFF111827) : const Color(0xFFF6F8FC);
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF1D2533);
    final secondaryText = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: backgroundColor,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: primaryText,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE7ECF4),
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.045),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: nameCtrl,
                    builder: (_, __) {
                      return Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF1C70D1),
                              Color(0xFF4BA3FF),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1C70D1).withOpacity(0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _avatarText,
                            style: const TextStyle(
                              fontSize: 34,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  Text(
                    'Personal Information',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Update your basic account information',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            _FormCard(
              cardColor: cardColor,
              isDark: isDark,
              children: [
                _ProfileField(
                  label: 'Name',
                  controller: nameCtrl,
                  icon: Icons.person_outline_rounded,
                  hint: 'Enter your name',
                  isDark: isDark,
                ),
                _ProfileField(
                  label: 'Email',
                  controller: emailCtrl,
                  icon: Icons.email_outlined,
                  hint: 'Email address',
                  isDark: isDark,
                  keyboardType: TextInputType.emailAddress,
                  readOnly: true,
                ),
                _ProfileField(
                  label: 'Phone number',
                  controller: phoneCtrl,
                  icon: Icons.phone_outlined,
                  hint: 'Enter phone number',
                  isDark: isDark,
                  keyboardType: TextInputType.phone,
                ),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: pickDateOfBirth,
                        child: AbsorbPointer(
                          child: _ProfileField(
                            label: 'Date of birth',
                            controller: dobCtrl,
                            icon: Icons.cake_outlined,
                            hint: 'dd/mm/yyyy',
                            isDark: isDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GenderField(
                        value: genderValue,
                        isDark: isDark,
                        onChanged: (value) {
                          setState(() => genderValue = value);
                        },
                      ),
                    ),
                  ],
                ),
                _ProfileField(
                  label: 'Address',
                  controller: addressCtrl,
                  icon: Icons.location_on_outlined,
                  hint: 'Enter address',
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isSaving ? null : saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C70D1),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF9CC8F6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final Color cardColor;
  final bool isDark;
  final List<Widget> children;

  const _FormCard({
    required this.cardColor,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 2),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE7ECF4),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 12,
              offset: const Offset(0, 7),
            ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool isDark;
  final TextInputType keyboardType;
  final bool readOnly;

  const _ProfileField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    required this.isDark,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF1D2533);
    final hintColor = isDark ? Colors.white38 : const Color(0xFF9CA3AF);
    final fillColor = isDark ? const Color(0xFF111827) : const Color(0xFFF6F8FC);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE7ECF4);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF1C70D1),
          ),
          labelStyle: TextStyle(
            color: hintColor,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: TextStyle(
            color: hintColor,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: borderColor,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF1C70D1),
              width: 1.4,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: borderColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _GenderField extends StatelessWidget {
  final String? value;
  final bool isDark;
  final ValueChanged<String?> onChanged;

  const _GenderField({
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF1D2533);
    final hintColor = isDark ? Colors.white38 : const Color(0xFF9CA3AF);
    final fillColor = isDark ? const Color(0xFF111827) : const Color(0xFFF6F8FC);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE7ECF4);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: hintColor,
        ),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: 'Gender',
          prefixIcon: const Icon(
            Icons.wc_outlined,
            color: Color(0xFF1C70D1),
          ),
          labelStyle: TextStyle(
            color: hintColor,
            fontWeight: FontWeight.w600,
          ),
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: borderColor,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF1C70D1),
              width: 1.4,
            ),
          ),
        ),
        items: const [
          DropdownMenuItem(
            value: 'male',
            child: Text('Male'),
          ),
          DropdownMenuItem(
            value: 'female',
            child: Text('Female'),
          ),
          DropdownMenuItem(
            value: 'other',
            child: Text('Other'),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}