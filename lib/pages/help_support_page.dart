import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'privacy_policy_page.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  String _version = "";

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _launchEmail(String subject) async {
    final Uri emailUri = Uri.parse(
      "mailto:nayansuthar969@gmail.com?subject=${Uri.encodeComponent(subject)}",
    );

    await launchUrl(emailUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = "Version ${info.version}";
    });
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildTile({
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Column(
      children: [
        ListTile(
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle) : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
        const Divider(height: 1),
      ],
    );
  }

  void _showFAQDialog(String question, String answer) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(question),
        content: Text(answer),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Help & Support")),
      body: ListView(
        children: [
          /// FAQ SECTION
          _buildSectionTitle("FAQ"),

          _buildTile(
            title: "How do I add an expense?",
            onTap: () => _showFAQDialog(
              "How do I add an expense?",
              "Tap the + button at the bottom of the home screen and enter your expense details.",
            ),
          ),

          _buildTile(
            title: "How do I edit a transaction?",
            onTap: () => _showFAQDialog(
              "How do I edit a transaction?",
              "Tap on any transaction in the list to edit its details.",
            ),
          ),

          _buildTile(
            title: "How is Net Balance calculated?",
            onTap: () => _showFAQDialog(
              "How is Net Balance calculated?",
              "Net Balance = Total Income - Total Expenses.",
            ),
          ),

          /// SUPPORT SECTION
          _buildSectionTitle("Support"),

          _buildTile(
            title: "Contact Support",
            subtitle: "nayansuthar969@gmail.com",
            onTap: () {
              _launchEmail("Support Request - Expense Tracker");
            },
          ),

          _buildTile(
            title: "Report a Bug",
            onTap: () {
              _launchEmail("Bug Report - Expense Tracker");
            },
          ),

          /// LEGAL SECTION
          _buildSectionTitle("Legal"),

          _buildTile(
            title: "Privacy Policy",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              );
            },
          ),

          const SizedBox(height: 30),

          Center(
            child: Text(
              _version,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
