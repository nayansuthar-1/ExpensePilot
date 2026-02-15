import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_service.dart';
import 'export_data_page.dart';
import 'account_page.dart';
import 'help_support_page.dart';
import 'about_page.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_notifier.dart';


class ProfilePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const ProfilePage({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _localDarkMode = false;
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _localDarkMode = widget.isDarkMode;
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_path');

    if (path != null && File(path).existsSync()) {
      setState(() {
        _profileImage = File(path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(title: const Text("Profile"), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🔹 USER INFO CARD
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
            child: ListTile(
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!)
                    : (user?.photoURL != null
                          ? NetworkImage(user!.photoURL!) as ImageProvider
                          : null),
                child: _profileImage == null && user?.photoURL == null
                    ? const Icon(Icons.person, size: 28)
                    : null,
              ),

              title: ValueListenableBuilder<String>(
                valueListenable: profileNameNotifier,
                builder: (context, fullName, _) {
                  return Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
              subtitle: Text(user?.email ?? ""),
            ),
          ),

          const SizedBox(height: 20),

          // 🔹 DARK MODE
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text("Dark Mode"),
            value: _localDarkMode,
            onChanged: (value) {
              setState(() {
                _localDarkMode = value;
              });

              widget.onToggleTheme();
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text("Export Data"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ExportDataPage()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("Account"),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountPage()),
              );

              if (result == true) {
                Navigator.pop(context, true);
              }
            },
          ),

          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text("Help & Support"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpSupportPage()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About App"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutPage()),
              );
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout"),
            onTap: () async {
              await authService.signOut();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
