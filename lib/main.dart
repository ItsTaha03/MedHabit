import 'package:flutter/material.dart';

void main() {
  runApp(const MedHabitApp());
}

class MedHabitApp extends StatelessWidget {
  const MedHabitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedHabit',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int streak = 0;

  void _incrementStreak() {
    setState(() {
      streak++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MedHabit"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Your Streak:",
              style: TextStyle(fontSize: 24),
            ),
            Text(
              "$streak days",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _incrementStreak,
              child: const Text("Add Day"),
            ),
          ],
        ),
      ),
    );
  }
}
