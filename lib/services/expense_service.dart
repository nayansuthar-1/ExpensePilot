import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense.dart';

class ExpenseService {
  //  Getter that always uses current logged-in user
  CollectionReference get _expenseRef {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('expenses');
  }

  //  ADD EXPENSE
  Future<String> addExpense(Expense expense) async {
    final docRef = await _expenseRef.add({
      'title': expense.title,
      'amount': expense.amount,
      'category': expense.category,
      'date': Timestamp.fromDate(expense.date),
      'type': expense.type,
    });

    return docRef.id;
  }

  //  FETCH EXPENSES
  Stream<List<Expense>> streamExpenses() {
    return _expenseRef.orderBy('date', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        return Expense(
          id: doc.id,
          title: data['title'],
          amount: data['amount'],
          category: data['category'],
          date: (data['date'] as Timestamp).toDate(),
          type: data['type'] ?? 'expense',
        );
      }).toList();
    });
  }



  //  DELETE EXPENSE
  Future<void> deleteExpense(String id) async {
    print("Deleting id: $id");

    await _expenseRef.doc(id).delete();
  }

  // UPDATE EXPENSE
  Future<void> updateExpense(Expense expense) async {
    await _expenseRef.doc(expense.id).update({
      'title': expense.title,
      'amount': expense.amount,
      'category': expense.category,
      'date': Timestamp.fromDate(expense.date),
      'type': expense.type,
    });
  }

}
