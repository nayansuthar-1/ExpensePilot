import 'package:flutter/material.dart';

class AddExpenseSheet extends StatefulWidget {
  final void Function(
    String title,
    double amount,
    String category,
    DateTime date,
  )
  onAddExpense;
  const AddExpenseSheet({super.key, required this.onAddExpense});

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now();
  final List<String> _categories = [
    'Food',
    'Travel',
    'Shopping',
    'Bills',
    'Other',
  ];

  void _pickDate() async {
  final pickedDate = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),
  );

  if (pickedDate != null) {
    setState(() {
      _selectedDate = pickedDate;
    });
  }
}


  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Add New Expense',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(labelText: 'Amount'),
            keyboardType: TextInputType.number,
          ),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            items: _categories
                .map(
                  (category) =>
                      DropdownMenuItem(value: category, child: Text(category)),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategory = value!;
              });
            },
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              ),
              TextButton(
                onPressed: _pickDate,
                child: const Text('Choose Date'),
              ),
            ],
          ),


          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final enteredTitle = _titleController.text;
              final enteredAmount = double.tryParse(_amountController.text);

              if (enteredTitle.isEmpty ||
                  enteredAmount == null ||
                  enteredAmount <= 0) {
                return;
              }

              widget.onAddExpense(
                enteredTitle,
                enteredAmount,
                _selectedCategory,
                _selectedDate,
              );

              Navigator.pop(context, 'Expense Added');
            },
            child: const Text('Add Expense'),
          ),
        ],
      ),
    );
  }
}
