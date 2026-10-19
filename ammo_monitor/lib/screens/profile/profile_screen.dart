import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '/providers/theme_provider.dart';
import '../login.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool notificationOn = true;
  String selectedLanguage = 'English';

  UserModel? get _user => Provider.of<AuthProvider>(context, listen: false).user;

  String get _displayName {
    final name = _user?.displayName.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Operator';
  }

  String get _email {
    final email = _user?.email.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'Transportation Monitor';
  }

  String get _avatarText {
    final name = _displayName.trim();
    if (name.isEmpty) return 'O';
    return name.characters.first.toUpperCase();
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EditProfileScreen(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  void _showLanguagePopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _LanguageSheet(
          selectedLanguage: selectedLanguage,
          onSelected: (language) {
            setState(() => selectedLanguage = language);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showInfoSnackBar(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title feature will be updated later.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out of this account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    await Provider.of<AuthProvider>(context, listen: false).signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;

    final backgroundColor =
        isDark ? const Color(0xFF111827) : const Color(0xFFF6F8FC);
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF1D2533);
    final secondaryText = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopBar(
                isDark: isDark,
                titleColor: primaryText,
              ),

              const SizedBox(height: 18),

              _ProfileHeaderCard(
                cardColor: cardColor,
                isDark: isDark,
                avatarText: _avatarText,
                displayName: _displayName,
                email: _email,
                onEdit: _openEditProfile,
              ),

              const SizedBox(height: 22),

              _SectionTitle(
                title: 'General',
                color: primaryText,
              ),

              const SizedBox(height: 10),

              _MenuGroup(
                cardColor: cardColor,
                children: [
                  _MenuSwitchTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    subtitle: notificationOn ? 'Enabled' : 'Disabled',
                    value: notificationOn,
                    isDark: isDark,
                    onChanged: (value) {
                      setState(() => notificationOn = value);
                    },
                  ),
                  _MenuDivider(isDark: isDark),
                  _MenuActionTile(
                    icon: Icons.language_rounded,
                    title: 'Language',
                    trailingText: selectedLanguage,
                    isDark: isDark,
                    onTap: _showLanguagePopup,
                  ),
                  _MenuDivider(isDark: isDark),
                  _MenuSwitchTile(
                    icon: Icons.dark_mode_outlined,
                    title: 'Theme',
                    subtitle: isDark ? 'Dark mode' : 'Light mode',
                    value: isDark,
                    isDark: isDark,
                    onChanged: themeProvider.setTheme,
                  ),
                ],
              ),

              const SizedBox(height: 22),

              _SectionTitle(
                title: 'Account & Security',
                color: primaryText,
              ),

              const SizedBox(height: 10),

              _MenuGroup(
                cardColor: cardColor,
                children: [
                  _MenuActionTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change password',
                    subtitle: 'Update your account password',
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuDivider(isDark: isDark),
                  _MenuActionTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Account status',
                    subtitle: _user != null
                        ? 'Active'
                        : 'Offline',
                    isDark: isDark,
                    onTap: () => _showInfoSnackBar('Account status'),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              _SectionTitle(
                title: 'Support',
                color: primaryText,
              ),

              const SizedBox(height: 10),

              _MenuGroup(
                cardColor: cardColor,
                children: [
                  _MenuActionTile(
                    icon: Icons.support_agent_outlined,
                    title: 'Help & Support',
                    subtitle: 'Get help when using the system',
                    isDark: isDark,
                    onTap: () => _showInfoSnackBar('Help & Support'),
                  ),
                  _MenuDivider(isDark: isDark),
                  _MenuActionTile(
                    icon: Icons.email_outlined,
                    title: 'Contact us',
                    subtitle: 'Send feedback to the development team',
                    isDark: isDark,
                    onTap: () => _showInfoSnackBar('Contact us'),
                  ),
                  _MenuDivider(isDark: isDark),
                  _MenuActionTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy policy',
                    subtitle: 'View privacy and data usage policy',
                    isDark: isDark,
                    onTap: () => _showInfoSnackBar('Privacy policy'),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              _LogoutButton(
                onTap: _logout,
              ),

              const SizedBox(height: 12),

              Center(
                child: Text(
                  'IoT Transportation Monitoring · v1.0.0',
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool isDark;
  final Color titleColor;

  const _TopBar({
    required this.isDark,
    required this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Profile',
          style: TextStyle(
            color: titleColor,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE7ECF4),
            ),
          ),
          child: Icon(
            Icons.settings_outlined,
            color: isDark ? Colors.white : const Color(0xFF1D2533),
          ),
        ),
      ],
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final Color cardColor;
  final bool isDark;
  final String avatarText;
  final String displayName;
  final String email;
  final VoidCallback onEdit;

  const _ProfileHeaderCard({
    required this.cardColor,
    required this.isDark,
    required this.avatarText,
    required this.displayName,
    required this.email,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Container(
            width: 86,
            height: 86,
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
                avatarText,
                style: const TextStyle(
                  fontSize: 34,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1D2533),
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C70D1),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionTitle({
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final Color cardColor;
  final List<Widget> children;

  const _MenuGroup({
    required this.cardColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
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

class _MenuActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final bool isDark;
  final VoidCallback onTap;

  const _MenuActionTile({
    required this.icon,
    required this.title,
    required this.isDark,
    required this.onTap,
    this.subtitle,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1D2533);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF6B7280);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              _MenuIcon(
                icon: icon,
                isDark: isDark,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (trailingText != null) ...[
                Text(
                  trailingText!,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
              ],

              Icon(
                Icons.chevron_right_rounded,
                color: subtitleColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _MenuSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1D2533);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          _MenuIcon(
            icon: icon,
            isDark: isDark,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Switch(
            value: value,
            activeThumbColor: const Color(0xFF1C70D1),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _MenuIcon extends StatelessWidget {
  final IconData icon;
  final bool isDark;

  const _MenuIcon({
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: const Color(0xFF1C70D1),
        size: 22,
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  final bool isDark;

  const _MenuDivider({
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      endIndent: 14,
      color: isDark ? Colors.white10 : const Color(0xFFE7ECF4),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    return Material(
      color: isDark ? const Color(0xFF1F2937) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFFFD9D9),
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: Color(0xFFE53935),
              ),
              SizedBox(width: 12),
              Text(
                'Log out',
                style: TextStyle(
                  color: Color(0xFFE53935),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFE53935),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageSheet extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onSelected;

  const _LanguageSheet({
    required this.selectedLanguage,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    final backgroundColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1D2533);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : const Color(0xFFE7ECF4),
              borderRadius: BorderRadius.circular(999),
            ),
          ),

          const SizedBox(height: 18),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Select Language',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(height: 12),

          _LanguageOption(
            title: 'English',
            selected: selectedLanguage == 'English',
            onTap: () => onSelected('English'),
          ),
          _LanguageOption(
            title: 'Vietnamese',
            selected: selectedLanguage == 'Vietnamese',
            onTap: () => onSelected('Vietnamese'),
          ),
          _LanguageOption(
            title: 'Japanese',
            selected: selectedLanguage == 'Japanese',
            onTap: () => onSelected('Japanese'),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final textColor = isDark ? Colors.white : const Color(0xFF1D2533);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: selected
          ? const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF1C70D1),
            )
          : Icon(
              Icons.circle_outlined,
              color: isDark ? Colors.white24 : const Color(0xFFE7ECF4),
            ),
    );
  }
}