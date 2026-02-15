import 'package:flutter/material.dart';
import '../models/expense.dart';

class ExpenseSearchDelegate extends SearchDelegate<String> {
  final List<Expense> expenses;

  ExpenseSearchDelegate({required this.expenses});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, " "),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    close(context, query);
    return const SizedBox();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filtered = expenses.where((expense) {
      return expense.title.toLowerCase().contains(query.toLowerCase()) ||
          expense.category.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final expense = filtered[index];
        return ListTile(
          title: Text(expense.title),
          subtitle: Text(expense.category),
          onTap: () => close(context, query),
        );
      },
    );
  }
}
