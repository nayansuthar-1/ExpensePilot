import 'package:expense_tracker/pages/main_navigation_page.dart';
import 'package:flutter/material.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/services/expense_service.dart';
import 'auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pages/profile_page.dart';
import 'pages/profile_notifier.dart';
import 'pages/add_page.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/expense_search_delegate.dart';
import 'package:flutter/services.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;
  final List<Expense> displayExpenses;
  final List<Expense> allExpenses;
  final TimeFilter selectedFilter;
  final void Function(TimeFilter) onFilterChanged;

  const HomePage({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
    required this.displayExpenses,
    required this.allExpenses,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ExpenseService _expenseService = ExpenseService();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey();
  List<Expense> _animatedExpenses = [];
  String? _lastInsertedId;
  String? _lastEditedId;
  bool _firstBuildDone = true;
  File? _profileImage;
  bool _isSearching = false;
  String _searchQuery = "";
  List<Expense> _searchResults = [];
  Timer? _debounce;
  String _selectedTypeFilter = 'all'; // all | income | expense
  String _selectedCategoryFilter = 'all';
  late final PageController _heroController;


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

      // Income categories
      case "salary":
        return Icons.attach_money;

      case "freelance":
        return Icons.work_outline;

      case "business":
        return Icons.business_center;

      case "investment":
        return Icons.trending_up;

      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case "food":
        return Colors.orange;
      case "travel":
        return Colors.blue;
      case "shopping":
        return Colors.purple;
      case "bills":
        return Colors.amber;
      default:
        return const Color(0xFF2ECC71); // fallback emerald
    }
  }

  double get _totalIncome {
    return _animatedExpenses
        .where((e) => e.type == "income")
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get _totalExpense {
    return _animatedExpenses
        .where((e) => e.type == "expense")
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get _netBalance {
    return _totalIncome - _totalExpense;
  }

  double get _thisMonthExpense {
    final now = DateTime.now();

    return widget.allExpenses
        .where(
          (e) =>
              e.type == "expense" &&
              e.date.month == now.month &&
              e.date.year == now.year,
        )
        .fold(0.0, (sum, e) => sum + e.amount);
  }



  double get _lastMonthExpense {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);

    return widget.allExpenses
        .where(
          (e) =>
              e.type == "expense" &&
              e.date.month == lastMonth.month &&
              e.date.year == lastMonth.year,
        )
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get _expenseDifferencePercent {
    final now = DateTime.now();

    DateTime currentMonth;
    DateTime previousMonth;

    if (widget.selectedFilter == TimeFilter.thisMonth) {
      currentMonth = DateTime(now.year, now.month);
      previousMonth = DateTime(now.year, now.month - 1);
    } else if (widget.selectedFilter == TimeFilter.lastMonth) {
      currentMonth = DateTime(now.year, now.month - 1);
      previousMonth = DateTime(now.year, now.month - 2);
    } else {
      return 0;
    }

    final currentExpense = widget.allExpenses
        .where(
          (e) =>
              e.type == "expense" &&
              e.date.month == currentMonth.month &&
              e.date.year == currentMonth.year,
        )
        .fold(0.0, (sum, e) => sum + e.amount);

    final previousExpense = widget.allExpenses
        .where(
          (e) =>
              e.type == "expense" &&
              e.date.month == previousMonth.month &&
              e.date.year == previousMonth.year,
        )
        .fold(0.0, (sum, e) => sum + e.amount);

    if (previousExpense == 0) return 0;

    return ((currentExpense - previousExpense) / previousExpense) * 100;
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Keep existing expense update logic
    if (oldWidget.displayExpenses != widget.displayExpenses) {
      _animatedExpenses = List.from(widget.displayExpenses);
      _animatedExpenses.sort((a, b) => b.date.compareTo(a.date));
    }

    // Sync hero card with filter changes
    if (oldWidget.selectedFilter != widget.selectedFilter) {
      _heroController.animateToPage(
        widget.selectedFilter.index,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildFinanceItem(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: amount),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Text(
              "₹${value.toStringAsFixed(0)}",
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeroContent(TimeFilter filter) {
    double income = 0;
    double expense = 0;

    final now = DateTime.now();

    DateTime currentMonth;
    DateTime previousMonth;

    if (filter == TimeFilter.thisMonth) {
      currentMonth = DateTime(now.year, now.month);
      previousMonth = DateTime(now.year, now.month - 1);
    } else if (filter == TimeFilter.lastMonth) {
      currentMonth = DateTime(now.year, now.month - 1);
      previousMonth = DateTime(now.year, now.month - 2);
    } else {
      currentMonth = DateTime(now.year, now.month);
      previousMonth = DateTime(now.year, now.month - 1);
    }

    double previousExpense = 0;

    for (var e in widget.allExpenses) {
      // Current period
      if (filter == TimeFilter.allTime) {
        if (e.type == "income") {
          income += e.amount;
        } else {
          expense += e.amount;
        }
      } else {
        if (e.date.month == currentMonth.month &&
            e.date.year == currentMonth.year) {
          if (e.type == "income") {
            income += e.amount;
          } else {
            expense += e.amount;
          }
        }
      }

      // Previous month expense for comparison
      if (e.type == "expense" &&
          e.date.month == previousMonth.month &&
          e.date.year == previousMonth.year) {
        previousExpense += e.amount;
      }
    }

    final balance = income - expense;

    double percentChange = 0;
    if (previousExpense != 0 &&
        (filter == TimeFilter.thisMonth || filter == TimeFilter.lastMonth)) {
      percentChange = ((expense - previousExpense) / previousExpense) * 100;
    }

    final isIncrease = percentChange > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          filter.name.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: balance),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Text(
              "₹${value.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: value >= 0 ? Colors.greenAccent : Colors.redAccent,
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // 🔥 Comparison Row (only for monthly views)
        if (filter == TimeFilter.thisMonth || filter == TimeFilter.lastMonth)
          previousExpense == 0
              ? const Text(
                  "No data from previous month",
                  style: TextStyle(color: Colors.white70),
                )
              : Row(
                  children: [
                    Icon(
                      isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isIncrease ? Colors.redAccent : Colors.greenAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: percentChange.abs()),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Text(
                          "${value.toStringAsFixed(0)}% "
                          "${isIncrease ? "more" : "less"} expenses than last month",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isIncrease
                                ? Colors.redAccent
                                : Colors.greenAccent,
                          ),
                        );
                      },
                    ),
                  ],
                ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFinanceItem("Expense", expense, Colors.redAccent),
            _buildFinanceItem("Income", income, Colors.greenAccent),
          ],
        ),
      ],
    );
  }

  Widget _buildInsertAnimation(Widget child) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, -30 * (1 - value)), // slide from top
          child: Opacity(opacity: value, child: child),
        );
      },
    );
  }

  void insertExpenseAnimated(Expense expense) {
    _animatedExpenses.insert(0, expense);
    _listKey.currentState?.insertItem(0);
  }

  @override
  void initState() {
    super.initState();

    _animatedExpenses = List.from(widget.displayExpenses);
    _animatedExpenses.sort((a, b) => b.date.compareTo(a.date));

    _loadProfileImage();
    _loadUserName(); 
    
    _heroController = PageController(initialPage: widget.selectedFilter.index);
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;

    String fullName;

    if (refreshedUser?.displayName != null &&
        refreshedUser!.displayName!.isNotEmpty) {
      fullName = refreshedUser.displayName!;
    } else {
      // Extract from email
      final email = refreshedUser?.email ?? "";
      fullName = email.split('@').first;

      // Save permanently in Firebase
      await refreshedUser?.updateDisplayName(fullName);
    }

    profileNameNotifier.value = fullName;
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_path');

    if (path != null && File(path).existsSync()) {
      final file = File(path);

      setState(() {
        _profileImage = file;
      });

      profileImageNotifier.value = file;
    }
  }

  Widget _buildExpenseItem(Expense expense, int index) {
    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        final removedExpense = expense;
        final removedIndex = index;
        bool isUndo = false;

        setState(() {
          _animatedExpenses.removeAt(index);
        });

        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();

        final controller = messenger.showSnackBar(
          SnackBar(
            content: const Text("Expense deleted"),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: "UNDO",
              onPressed: () {
                isUndo = true;

                setState(() {
                  _lastInsertedId = removedExpense.id;
                  _animatedExpenses.insert(removedIndex, removedExpense);
                });

                Future.delayed(const Duration(milliseconds: 400), () {
                  _lastInsertedId = null;
                });
              },
            ),
          ),
        );

        Future.delayed(const Duration(seconds: 3), () async {
          controller.close();

          if (!isUndo) {
            await _expenseService.deleteExpense(removedExpense.id);
          }
        });
      },

      child: _buildExpenseContainer(expense),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Filter Transactions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _selectedTypeFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'income', child: Text('Income')),
                  DropdownMenuItem(value: 'expense', child: Text('Expense')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedTypeFilter = value!;
                  });
                },
                decoration: const InputDecoration(labelText: "Type"),
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedCategoryFilter,
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('All Categories'),
                  ),
                  ...widget.allExpenses
                      .map((e) => e.category)
                      .toSet()
                      .map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                      ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryFilter = value!;
                  });
                },
                decoration: const InputDecoration(labelText: "Category"),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {});
                },
                child: const Text("Apply Filters"),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Expense> get _filteredExpenses {
    return widget.displayExpenses.where((expense) {
      final matchesSearch =
          expense.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          expense.category.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesType =
          _selectedTypeFilter == 'all' || expense.type == _selectedTypeFilter;

      final matchesCategory =
          _selectedCategoryFilter == 'all' ||
          expense.category == _selectedCategoryFilter;

      return matchesSearch && matchesType && matchesCategory;
    }).toList();
  }

  double get _totalExpenses {
    return _animatedExpenses.fold(0.0, (sum, item) => sum + item.amount);
  }

  Widget _buildExpenseContainer(Expense expense) {
    final isEdited = expense.id == _lastEditedId;
    final isIncome = expense.type == "income";

    final formattedDate =
        "${expense.date.day.toString().padLeft(2, '0')}/"
        "${expense.date.month.toString().padLeft(2, '0')}/"
        "${expense.date.year}";

    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: isEdited ? 1.02 : 1.0,
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF121212)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isEdited
                ? const Color(0xFF2ECC71).withOpacity(0.6)
                : Colors.transparent,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddPage(
                  type: expense.type,
                  expense: expense,
                  onAddExpense: (updatedExpense) async {
                    await _expenseService.updateExpense(updatedExpense);

                    final index = _animatedExpenses.indexWhere(
                      (e) => e.id == updatedExpense.id,
                    );

                    if (index != -1) {
                      setState(() {
                        _animatedExpenses[index] = updatedExpense;
                        _lastEditedId = updatedExpense.id;
                      });

                      Future.delayed(const Duration(milliseconds: 600), () {
                        if (mounted) {
                          setState(() {
                            _lastEditedId = null;
                          });
                        }
                      });
                    }
                  },
                ),
              ),
            );
          },
          child: Row(
            children: [
              /// Category Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getCategoryColor(expense.category).withOpacity(0.15),
                ),
                child: Icon(
                  _getCategoryIcon(expense.category),
                  color: _getCategoryColor(expense.category),
                  size: 22,
                ),
              ),

              const SizedBox(width: 16),

              /// Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${expense.category} • $formattedDate",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              /// Amount Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: isIncome
                      ? Colors.green.withOpacity(0.15)
                      : Colors.redAccent.withOpacity(0.15),
                ),
                child: Text(
                  "${isIncome ? "+" : "-"} ₹${expense.amount.toStringAsFixed(0)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isIncome ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final AuthService _authService = AuthService();

  Future<void> _logout() async {
    Navigator.pop(context); // close drawer
    await _authService.signOut();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();

    _heroController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        systemOverlayStyle: isDark
            ? const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
              )
            : const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
              ),
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset('assets/ExpensePilot_text.png', height: 50),
            const SizedBox(width: 8), 
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = true;
              });
            },
          ),

          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(
                      onToggleTheme: widget.onToggleTheme,
                      isDarkMode: widget.isDarkMode,
                    ),
                  ),
                );

                if (result == true) {
                  setState(() {});
                }
              },
              child: ValueListenableBuilder<File?>(
                valueListenable: profileImageNotifier,
                builder: (context, file, _) {
                  return CircleAvatar(
                    radius: 22,
                    backgroundImage: file != null ? FileImage(file) : null,
                    child: file == null ? const Icon(Icons.person) : null,
                  );
                },
              ),
            ),
          ),
        ],
      ),

      body: Stack(
        children: [
          RefreshIndicator(
            color: const Color(0xFF2ECC71),
            onRefresh: () async {
              HapticFeedback.lightImpact();
              await Future.delayed(const Duration(milliseconds: 600));
              setState(() {});
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // greetings
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ValueListenableBuilder<String>(
                        valueListenable: profileNameNotifier,
                        builder: (context, fullName, _) {
                          final firstName = fullName.isNotEmpty
                              ? fullName.split(" ").first
                              : "User";

                          return Text(
                            "Hello, $firstName",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "track your money",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),

                      DropdownButtonHideUnderline(
                        child: SizedBox(
                          height: 45,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: TimeFilter.values.map((filter) {
                              final isSelected =
                                  widget.selectedFilter == filter;

                              return GestureDetector(
                                onTap: () => widget.onFilterChanged(filter),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin: const EdgeInsets.only(right: 10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    color: isSelected
                                        ? const Color(0xFF2ECC71)
                                        : Theme.of(context).cardColor,
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF2ECC71,
                                              ).withOpacity(0.4),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    filter.name.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Total Expense CARD 0r HERO Card
                SizedBox(
                  height: 240,
                  child: PageView(
                    controller: _heroController,
                    onPageChanged: (index) {
                      HapticFeedback.lightImpact();

                      final newFilter = TimeFilter.values[index];
                      widget.onFilterChanged(newFilter);
                    },
                    children: TimeFilter.values.map((filter) {
                      return Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2ECC71).withOpacity(0.35),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0B0F1A),
                              Color(0xFF1C2B2D),
                              Color(0xFF14532D),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: _buildHeroContent(filter),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 4),

                //  EXPENSE LIST
                _animatedExpenses.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Center(
                          child: Column(
                            children: const [
                              Icon(
                                Icons.receipt_long,
                                size: 60,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                "No transactions yet",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _animatedExpenses.length,
                        itemBuilder: (context, index) {
                          final expense = _animatedExpenses[index];

                          final item = _buildExpenseItem(expense, index);

                          if (expense.id == _lastInsertedId) {
                            return _buildInsertAnimation(item);
                          }

                          return item;
                        },
                      ),

                const SizedBox(height: 100),
              ],
            ),
          ),

          if (_isSearching)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _isSearching = false;
                    _searchQuery = "";
                    _searchResults = [];
                  });
                },
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: 1,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(color: Colors.black.withOpacity(0.18)),
                  ),
                ),
              ),
            ),

          if (_isSearching)
            Positioned.fill(
              child: SafeArea(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Material(
                            borderRadius: BorderRadius.circular(14),
                            elevation: 8,
                            child: TextField(
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: "Search",
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w400,
                                ),
                                prefixIcon: const Icon(Icons.search, size: 20),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () {
                                    FocusScope.of(context).unfocus();
                                    setState(() {
                                      _isSearching = false;
                                      _searchQuery = "";
                                      _searchResults = [];
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    18,
                                  ), //  more rounded
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(
                                        0xFF1C1C1E,
                                      ) // Apple dark surface
                                    : const Color(
                                        0xFFF2F2F7,
                                      ), // Apple light surface
                              ),
                              onChanged: (value) {
                                if (_debounce?.isActive ?? false)
                                  _debounce!.cancel();

                                _debounce = Timer(
                                  const Duration(milliseconds: 350),
                                  () {
                                    final query = value.toLowerCase();

                                    setState(() {
                                      _searchQuery = query;

                                      if (query.isEmpty) {
                                        _searchResults = [];
                                      } else {
                                        _searchResults = _animatedExpenses
                                            .where((expense) {
                                              return expense.title
                                                      .toLowerCase()
                                                      .contains(query) ||
                                                  expense.category
                                                      .toLowerCase()
                                                      .contains(query);
                                            })
                                            .toList();
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        if (_searchQuery.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.55,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF1C1C1E)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.12),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ListView(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  children: _searchResults.isEmpty
                                      ? [
                                          const Padding(
                                            padding: EdgeInsets.all(20),
                                            child: Center(
                                              child: Text(
                                                "No matching results",
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ]
                                      : _searchResults.map((expense) {
                                          return ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 6,
                                                ),
                                            title: Text(expense.title),
                                            subtitle: Text(expense.category),
                                            trailing: Text(
                                              "₹${expense.amount.toStringAsFixed(0)}",
                                              style: TextStyle(
                                                color: expense.type == "income"
                                                    ? Colors.green
                                                    : Colors.redAccent,
                                              ),
                                            ),
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              setState(() {
                                                _isSearching = false;
                                              });
                                            },
                                          );
                                        }).toList(),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
