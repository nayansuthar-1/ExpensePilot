import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_notifier.dart';
import 'delete_account_page.dart';



class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final user = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  File? _profileImage;

  bool _isLoading = false;


  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
    );

    if (image == null) return;

    final file = File(image.path);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path', file.path);

    setState(() {
      _profileImage = file;
      profileImageNotifier.value = file;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile photo updated")),
    );

    Navigator.pop(context, true); // ADD THIS
  }


  @override
  void initState() {
    super.initState();
    _nameController.text = user?.displayName ?? "";
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

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    // 
    // Update full name instantly
    profileNameNotifier.value = newName;

    // Update Firebase in background (no await = instant UI)
    FirebaseAuth.instance.currentUser?.updateDisplayName(newName);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Name updated")));

    Navigator.pop(context, true);
  }




  Future<void> _sendVerificationEmail() async {
    if (user == null) return;

    await user!.sendEmailVerification();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Verification email sent")));
  }

  Future<void> _resetPassword() async {
    if (user == null) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Reset email sent to ${user!.email}")),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.message}")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  //////////////////////////////////////////////////////


  @override
  Widget build(BuildContext context) {
    final isVerified = user?.emailVerified ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              //  PROFILE SECTION
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : (user?.photoURL != null
                                ? NetworkImage(user!.photoURL!) as ImageProvider
                                : null),
                      child: _profileImage == null && user?.photoURL == null
                          ? const Icon(Icons.person, size: 40)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF2ECC71),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Display Name",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: _updateName,
                child: const Text("Update Name"),
              ),

              const SizedBox(height: 30),

              // 🔐 ACCOUNT INFO
              const Text(
                "Account Security",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: Icon(
                    isVerified ? Icons.verified : Icons.warning,
                    color: isVerified ? Colors.green : Colors.orange,
                  ),
                  title: const Text("Email Verification"),
                  subtitle: Text(
                    isVerified
                        ? "Your email is verified"
                        : "Your email is NOT verified",
                  ),
                  trailing: !isVerified
                      ? TextButton(
                          onPressed: _sendVerificationEmail,
                          child: const Text("Verify"),
                        )
                      : null,
                ),
              ),

              // const SizedBox(height: 12),

              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(Icons.key),
                  title: const Text("Change Password"),
                  subtitle: const Text("Reset your password via email"),
                  onTap: _resetPassword,
                ),
              ),

              // const SizedBox(height: 12),

              const SizedBox(height: 30),

              const Text(
                "Danger Zone",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),

              const SizedBox(height: 12),

              Card(
                color: Colors.red.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    "Delete Account",
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text("This action cannot be undone"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeleteAccountPage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
