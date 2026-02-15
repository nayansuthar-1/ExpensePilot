import 'package:flutter/material.dart';
import 'category_detail_page.dart';
import '../models/expense.dart';
import 'package:fl_chart/fl_chart.dart';

class OverviewPage extends StatefulWidget {
  final List<Expense> expenses;

  const OverviewPage({super.key, required this.expenses});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

/* ===============================
   PRESS SCALE MICRO INTERACTION
================================ */

class AnimatedCategoryCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color glowColor;

  const AnimatedCategoryCard({
    super.key,
    required this.child,
    required this.onTap,
    required this.glowColor,
  });

  @override
  State<AnimatedCategoryCard> createState() => _AnimatedCategoryCardState();
}

class _AnimatedCategoryCardState extends State<AnimatedCategoryCard>
    with SingleTickerProviderStateMixin {
  double _scale = 1;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _glowAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    // Compress
    setState(() => _scale = 0.92);

    _glowController.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 120));

    setState(() => _scale = 1);

    await Future.delayed(const Duration(milliseconds: 120));

    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.glowColor.withOpacity(
                    0.4 * (1 - _glowAnimation.value),
                  ),
                  blurRadius: 20 * _glowAnimation.value,
                  spreadRadius: 2 * _glowAnimation.value,
                ),
              ],
            ),
            child: GestureDetector(onTap: _handleTap, child: widget.child),
          ),
        );
      },
    );
  }
}

/* ===============================
            OVERVIEW
================================ */

class _OverviewPageState extends State<OverviewPage> {
  Map<String, Map<String, double>> get categoryTotals {
    final Map<String, Map<String, double>> totals = {};  
    
    for (var expense in filteredExpenses) {
      totals.putIfAbsent(
        expense.category,
        () => {"income": 0.0, "expense": 0.0},
      );

      totals[expense.category]![expense.type] =
          totals[expense.category]![expense.type]! + expense.amount;
    }

    return totals;
  }


  double _animationKey = 0;

  @override
  void initState() {
    super.initState();
    _animationKey = DateTime.now().millisecondsSinceEpoch.toDouble();
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case "food":
        return Icons.restaurant;
      case "travel":
        return Icons.flight;
      case "shopping":
        return Icons.shopping_bag;
      case "bills":
        return Icons.receipt_long;
      case "salary":
        return Icons.attach_money;
      case "freelance":
        return Icons.work;
      case "business":
        return Icons.business;
      case "investment":
        return Icons.trending_up;
      default:
        return Icons.category;
    }
  }

  Widget _filterButton(String label) {
    final isSelected = selectedFilter == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? const Color(0xFF2ECC71)
              : Theme.of(context).cardColor,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }


  String selectedFilter = "All Time";

  List<Expense> get filteredExpenses {
    final now = DateTime.now();

    if (selectedFilter == "This Month") {
      return widget.expenses
          .where((e) => e.date.month == now.month && e.date.year == now.year)
          .toList();
    }

    if (selectedFilter == "Last Month") {
      final lastMonth = DateTime(now.year, now.month - 1);
      return widget.expenses
          .where(
            (e) =>
                e.date.month == lastMonth.month &&
                e.date.year == lastMonth.year,
          )
          .toList();
    }

    return widget.expenses;
  }


  Widget monthlyAnalyticsChart() {
    final now = DateTime.now();

    // Last 3 months
    final months = [
      DateTime(now.year, now.month - 2),
      DateTime(now.year, now.month - 1),
      DateTime(now.year, now.month),
    ];

    List<double> incomeData = [];
    List<double> expenseData = [];

    for (var month in months) {
      double income = 0;
      double expense = 0;

      for (var e in widget.expenses) {
        if (e.date.month == month.month && e.date.year == month.year) {
          if (e.type == "income") {
            income += e.amount;
          } else {
            expense += e.amount;
          }
        }
      }

      incomeData.add(income);
      expenseData.add(expense);
    }

    final allValues = [...incomeData, ...expenseData];
    final hasAnyTransaction = allValues.any((value) => value > 0);
    if (!hasAnyTransaction) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).cardColor,
        ),
        child: const SizedBox(
          height: 220,
          child: Center(
            child: Text(
              "No Transaction",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    }

    final maxY = allValues.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).cardColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Last 3 Months",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 220,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 300,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_animationKey),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return BarChart(
                      
                      BarChartData(
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            tooltipRoundedRadius: 14,
                            tooltipPadding: const EdgeInsets.all(8),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              String type = rodIndex == 0
                                  ? "Income"
                                  : "Expense";

                              return BarTooltipItem(
                                "$type\n₹${rod.toY.toStringAsFixed(0)}",
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ),

                        maxY: maxY * 1.2,
                        barGroups: List.generate(3, (index) {
                          return BarChartGroupData(
                            x: index,
                            barsSpace: 8,
                            barRods: [
                              // Income
                              BarChartRodData(
                                toY: incomeData[index] * value,
                                width: 12,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                  topRight: Radius.circular(6),
                                ),
                                color: const Color(0xFF2ECC71),
                              ),
                              // Expense
                              BarChartRodData(
                                toY: expenseData[index] * value,
                                width: 10,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                  topRight: Radius.circular(6),
                                ),
                                color: const Color(0xFFFF5C5C),
                              ),
                            ],
                          );
                        }),
                        gridData: FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              interval: maxY <= 0 ? 1 : (maxY / 5),
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  "₹${(value / 1000).toStringAsFixed(0)}K",
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),

                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                String formatMonth(DateTime date) {
                                  const months = [
                                    "Jan",
                                    "Feb",
                                    "Mar",
                                    "Apr",
                                    "May",
                                    "Jun",
                                    "Jul",
                                    "Aug",
                                    "Sep",
                                    "Oct",
                                    "Nov",
                                    "Dec",
                                  ];
                                  return months[date.month - 1];
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    formatMonth(months[value.toInt()]),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              },
                            ),
                          ),

                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _Legend(color: Color(0xFF2ECC71), text: "Income"),
              SizedBox(width: 16),
              _Legend(color: Color(0xFFFF5C5C), text: "Expense"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(String label, double value, Color color) {
    return Column(
      children: [
        Container(
          height: value == 0 ? 10 : value / 50, // simple scaling
          width: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);

    return Scaffold(
      appBar: AppBar(title: const Text("Overview"), centerTitle: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 🔥 Chart
              monthlyAnalyticsChart(),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _filterButton("This Month"),
                  const SizedBox(width: 8),
                  _filterButton("Last Month"),
                  const SizedBox(width: 8),
                  _filterButton("All Time"),
                ],
              ),

              const SizedBox(height: 16),


              // 🔥 Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),

                itemCount: categoryTotals.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (context, index) {
                  final entry = categoryTotals.entries.elementAt(index);
                  final income = entry.value["income"]!;
                  final expense = entry.value["expense"]!;
                  final net = income - expense;

                  final percentage = totalAmount == 0
                      ? 0.0
                      : ((income + expense) / totalAmount).toDouble();

                  final isIncomeCategory = income > expense;

                  final color = isIncomeCategory
                      ? const Color(0xFF2ECC71)
                      : const Color(0xFFFF5C5C);

                  return AnimatedCategoryCard(
                    glowColor: color,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CategoryDetailPage(
                            category: entry.key,
                            expenses: filteredExpenses
                                .where((e) => e.category == entry.key)
                                .toList(),
                          ),
                        ),
                      );
                    },

                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Theme.of(context).cardColor,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          /* ===============================
                           CIRCULAR RING
                    =============================== */
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                height: 90,
                                width: 90,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: percentage),
                                  duration: const Duration(milliseconds: 900),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, _) {
                                    return CircularProgressIndicator(
                                      value: value,
                                      strokeWidth: 8,
                                      backgroundColor: color.withOpacity(0.15),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        color,
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Inner shadow circle
                              Container(
                                height: 64,
                                width: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).cardColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 6,
                                      offset: const Offset(2, 2),
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withOpacity(
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? 0.02
                                            : 0.6,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(-2, -2),
                                    ),
                                  ],
                                ),
                              ),

                              // Icon + Animated %
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getCategoryIcon(entry.key),
                                    size: 22,
                                    color: color,
                                  ),
                                  const SizedBox(height: 2),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(
                                      begin: 0,
                                      end: percentage * 100,
                                    ),
                                    duration: const Duration(milliseconds: 900),
                                    builder: (context, value, _) {
                                      return Text(
                                        "${value.toStringAsFixed(0)}%",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          Text(
                            entry.key,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            "₹${net.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;

  const _Legend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}
