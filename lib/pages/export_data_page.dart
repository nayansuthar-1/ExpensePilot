import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';


class ExportDataPage extends StatefulWidget {
  const ExportDataPage({super.key});

  @override
  State<ExportDataPage> createState() => _ExportDataPageState();
}

enum ReportType { full, thisMonth, summaryOnly }


class _ExportDataPageState extends State<ExportDataPage> {
  bool _isLoading = false;
  Future<void> _generateReport(
    BuildContext context,
    ReportType reportType,
  ) async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .orderBy('date', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("No expenses to export")));
        return;
      }

      final now = DateTime.now();
      List<QueryDocumentSnapshot> docs = snapshot.docs;

      // ✅ FILTER: THIS MONTH
      if (reportType == ReportType.thisMonth) {
        docs = docs.where((doc) {
          final date = (doc['date'] as Timestamp).toDate();
          return date.month == now.month && date.year == now.year;
        }).toList();
      }

      double totalIncome = 0;
      double totalExpense = 0;

      Map<String, Map<String, double>> monthlyData = {};

      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['amount'] ?? 0).toDouble();
        final type = data['type'] ?? "expense";
        final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();


        if (type == "income") {
          totalIncome += amount;
        } else {
          totalExpense += amount;
        }

        String monthKey =
            "${date.year}-${date.month.toString().padLeft(2, '0')}";

        monthlyData.putIfAbsent(monthKey, () => {"income": 0, "expense": 0});

        if (type == "income") {
          monthlyData[monthKey]!["income"] =
              monthlyData[monthKey]!["income"]! + amount;
        } else {
          monthlyData[monthKey]!["expense"] =
              monthlyData[monthKey]!["expense"]! + amount;
        }
      }

      final netBalance = totalIncome - totalExpense;

      final pdf = pw.Document();
      final formattedDate = DateFormat('dd MMM yyyy').format(now);

      List<List<String>> monthlyTableData = [];

      const monthNames = [
        "",
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December",
      ];

      monthlyData.forEach((month, values) {
        final income = values["income"]!;
        final expense = values["expense"]!;
        final net = income - expense;

        final parts = month.split("-");
        final year = parts[0];
        final monthNumber = int.parse(parts[1]);

        monthlyTableData.add([
          "${monthNames[monthNumber]} $year",
          "${income.toStringAsFixed(2)} rs.",
          "${expense.toStringAsFixed(2)} rs.",
          "${net.toStringAsFixed(2)} rs.",
        ]);
      });

      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Text(
              "Expense Tracker Report",
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 10),
            pw.Text("Generated: $formattedDate"),
            pw.Text("User: ${user.displayName ?? user.email}"),

            pw.SizedBox(height: 20),

            pw.Text("Total Income: ${totalIncome.toStringAsFixed(2)} rs."),
            pw.Text("Total Expense: ${totalExpense.toStringAsFixed(2)} rs."),
            pw.Text("Net Balance: ${netBalance.toStringAsFixed(2)} rs."),

            pw.SizedBox(height: 25),

            pw.Text(
              "Monthly Summary",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 10),

            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              children: [
                // HEADER
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor(0.9, 0.9, 0.9),
                  ),
                  children: [
                    _pdfHeaderCell("Month"),
                    _pdfHeaderCell("Income"),
                    _pdfHeaderCell("Expense"),
                    _pdfHeaderCell("Net Balance"),
                  ],
                ),

                // DATA ROWS
                ...monthlyData.entries.map((entry) {
                  final monthKey = entry.key;
                  final values = entry.value;

                  final income = values["income"] ?? 0;
                  final expense = values["expense"] ?? 0;
                  final net = income - expense;

                  final parts = monthKey.split("-");
                  final year = parts[0];
                  final monthNumber = int.parse(parts[1]);

                  const monthNames = [
                    "",
                    "January",
                    "February",
                    "March",
                    "April",
                    "May",
                    "June",
                    "July",
                    "August",
                    "September",
                    "October",
                    "November",
                    "December",
                  ];

                  final monthName = "${monthNames[monthNumber]} $year";

                  return pw.TableRow(
                    children: [
                      _pdfCell(monthName),

                      // ✅ Income Green
                      _pdfCell(
                        "${income.toStringAsFixed(2)} rs.",
                        textColor: PdfColor(0, 0.6, 0),
                      ),

                      // ✅ Expense Red
                      _pdfCell(
                        "${expense.toStringAsFixed(2)} rs.",
                        textColor: PdfColor(0.8, 0, 0),
                      ),

                      // ✅ Net Balance dynamic color
                      _pdfCell(
                        "${net.toStringAsFixed(2)} rs.",
                        textColor: net >= 0
                            ? PdfColor(0, 0.6, 0)
                            : PdfColor(0.8, 0, 0),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),




            pw.SizedBox(height: 25),

            if (reportType != ReportType.summaryOnly) ...[
              pw.Text(
                "Transactions",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                children: [
                  // HEADER
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColor(0.9, 0.9, 0.9),
                    ),
                    children: [
                      _pdfHeaderCell("Title"),
                      _pdfHeaderCell("Category"),
                      _pdfHeaderCell("Type"),
                      _pdfHeaderCell("Amount"),
                      _pdfHeaderCell("Date"),
                    ],
                  ),

                  // DATA ROWS
                  ...docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    final title = data['title'] ?? "N/A";
                    final category = data['category'] ?? "N/A";
                    final type = data['type'] ?? "expense";
                    final amount = (data['amount'] ?? 0).toDouble();
                    final date =
                        (data['date'] as Timestamp?)?.toDate() ??
                        DateTime.now();

                    final isIncome = type == "income";

                    final typeColor = isIncome
                        ? PdfColor(0, 0.6, 0)
                        : PdfColor(0.8, 0, 0);

                    final amountColor = isIncome
                        ? PdfColor(0, 0.6, 0)
                        : PdfColor(0.8, 0, 0);

                    return pw.TableRow(
                      children: [
                        _pdfCell(title),
                        _pdfCell(category),

                        // ✅ TYPE COLORED
                        _pdfCell(type, textColor: typeColor),

                        // ✅ AMOUNT COLORED WITH SIGN
                        _pdfCell(
                          isIncome
                              ? "  ${amount.toStringAsFixed(2)} rs."
                              : "- ${amount.toStringAsFixed(2)} rs.",
                          textColor: amountColor,
                        ),

                        _pdfCell(DateFormat('dd/MM/yyyy').format(date)),
                      ],
                    );
                  }).toList(),
                ],
              ),

            ],
          ],
        ),
      );

      setState(() => _isLoading = false);

      // ✅ PREVIEW BEFORE SHARE
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  pw.Widget _pdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _pdfCell(String text, {PdfColor? textColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(color: textColor ?? PdfColor(0, 0, 0)),
      ),
    );
  }



  Widget _buildExportCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF2ECC71)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Reports')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Generate Professional Reports",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Export your expense data in beautifully formatted PDF reports.",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),

                _buildExportCard(
                  context,
                  title: "Full Report",
                  subtitle: "Includes all transactions and monthly summary",
                  icon: Icons.picture_as_pdf,
                  onTap: () => _generateReport(context, ReportType.full),
                ),
                const SizedBox(height: 16),

                _buildExportCard(
                  context,
                  title: "This Month Report",
                  subtitle: "Only current month transactions",
                  icon: Icons.calendar_month,
                  onTap: () => _generateReport(context, ReportType.thisMonth),
                ),
                const SizedBox(height: 16),

                _buildExportCard(
                  context,
                  title: "Monthly Summary Only",
                  subtitle: "Only summary table without transactions",
                  icon: Icons.table_chart,
                  onTap: () => _generateReport(context, ReportType.summaryOnly),
                ),
              ],
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),

    );
  }
}
