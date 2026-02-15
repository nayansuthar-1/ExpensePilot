import 'package:flutter/material.dart';
import '../models/expense.dart';

class CategoryDetailPage extends StatelessWidget {
  final String category;
  final List<Expense> expenses;

  const CategoryDetailPage({
    super.key,
    required this.category,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: ListView.builder(
        itemCount: expenses.length,
        itemBuilder: (context, index) {
          final expense = expenses[index];

          return ListTile(
            leading: Icon(
              expense.type == "income"
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              color: expense.type == "income" ? Colors.green : Colors.red,
            ),
            title: Text(expense.title),
            subtitle: Text(
              "${expense.date.day}/${expense.date.month}/${expense.date.year}",
            ),
            trailing: Text(
              "₹${expense.amount}",
              style: TextStyle(
                color: expense.type == "income" ? Colors.green : Colors.red,
              ),
            ),
          );
        },
      ),
    );
  }
}
