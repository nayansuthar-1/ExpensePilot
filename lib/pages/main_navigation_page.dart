import 'package:flutter/material.dart';
import '../homepage.dart';
import 'overview_page.dart';
import 'add_page.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import 'package:flutter/services.dart';

enum TimeFilter { thisMonth, lastMonth, allTime }

class MainNavigationPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const MainNavigationPage({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;
  final ExpenseService _expenseService = ExpenseService();

  // ........filtered time..........//
  TimeFilter _selectedFilter = TimeFilter.thisMonth;

  List<Expense> _applyFilter(List<Expense> expenses) {
    final now = DateTime.now();

    if (_selectedFilter == TimeFilter.allTime) {
      return expenses;
    }

    if (_selectedFilter == TimeFilter.thisMonth) {
      return expenses.where((expense) {
        return expense.date.month == now.month && expense.date.year == now.year;
      }).toList();
    }

    if (_selectedFilter == TimeFilter.lastMonth) {
      final lastMonth = DateTime(now.year, now.month - 1);

      return expenses.where((expense) {
        return expense.date.month == lastMonth.month &&
            expense.date.year == lastMonth.year;
      }).toList();
    }

    return expenses;
  }

  Future<void> _handleAddExpense(Expense expense) async {
    await _expenseService.addExpense(expense);
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: color.withOpacity(0.12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.2),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      isDark
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
    );

    return Scaffold(
      body: StreamBuilder<List<Expense>>(
        stream: _expenseService.streamExpenses(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allExpenses = snapshot.data!;
          final filteredExpenses = _applyFilter(allExpenses);

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0.5, 0),
                end: Offset.zero,
              ).animate(animation);

              return SlideTransition(
                position: offsetAnimation,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: _selectedIndex == 0
                ? HomePage(
                    key: const ValueKey(0),
                    onToggleTheme: widget.onToggleTheme,
                    isDarkMode: widget.isDarkMode,
                    displayExpenses: filteredExpenses, //  visible list
                    allExpenses: allExpenses, //  full list for comparison
                    selectedFilter: _selectedFilter,
                    onFilterChanged: (filter) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                  )
                : OverviewPage(key: const ValueKey(1), expenses: allExpenses),
          );
        },
      ),

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            // ADD button (middle)
            if (index == 1) {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xFF121212),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Add Transaction",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 24),

                        _buildOptionCard(
                          icon: Icons.arrow_upward,
                          title: "Expense",
                          subtitle: "Track your spending",
                          color: Colors.redAccent,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddPage(
                                  type: "expense",
                                  onAddExpense: _handleAddExpense,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        _buildOptionCard(
                          icon: Icons.arrow_downward,
                          title: "Income",
                          subtitle: "Record your earnings",
                          color: Colors.greenAccent,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddPage(
                                  type: "income",
                                  onAddExpense: _handleAddExpense,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              );

              return; // 🔥 VERY IMPORTANT
            }

            // HOME
            if (index == 0) {
              setState(() {
                _selectedIndex = 0;
              });
            }

            // OVERVIEW (index 2 in bottom nav → index 1 in stack)
            if (index == 2) {
              setState(() {
                _selectedIndex = 1;
              });
            }
          },

          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          selectedItemColor: const Color(0xFF2ECC71), // emerald
          unselectedItemColor: Colors.grey,
          elevation: 10,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: "Home",
            ),

            BottomNavigationBarItem(
              icon: Transform.translate(
                offset: const Offset(0, -8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2ECC71),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? const Color(0xFF2ECC71).withOpacity(
                                0.6,
                              ) // glow in dark
                            : Colors.black26,
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: isDark ? Offset(0, 0) : Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
              label: "Add",
            ),

            const BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: "Overview",
            ),
          ],
        ),
      ),
    );
  }
}
