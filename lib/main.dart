import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdfx/pdfx.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MedHabitApp());
}

class MedHabitApp extends StatefulWidget {
  const MedHabitApp({super.key});

  @override
  State<MedHabitApp> createState() => _MedHabitAppState();
}

class _MedHabitAppState extends State<MedHabitApp> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HabitTrackerPage(),
    const StatsPage(),
    const NotesPage(),
    const PdfViewerPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "MedHabit",
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text("MedHabit"),
        ),
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle),
              label: "Habits",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart),
              label: "Stats",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notes),
              label: "Notes",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.picture_as_pdf),
              label: "PDF",
            ),
          ],
        ),
      ),
    );
  }
}

//////////////////// HABITS PAGE ////////////////////

class HabitTrackerPage extends StatefulWidget {
  const HabitTrackerPage({super.key});

  @override
  State<HabitTrackerPage> createState() => _HabitTrackerPageState();
}

class _HabitTrackerPageState extends State<HabitTrackerPage> {
  List<String> _habits = [];
  Map<String, int> _streaks = {};
  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      _habits = prefs!.getStringList("habits") ?? [];
      _streaks = jsonDecode(prefs!.getString("streaks") ?? "{}").cast<String, int>();
    });
  }

  Future<void> _saveHabits() async {
    await prefs!.setStringList("habits", _habits);
    await prefs!.setString("streaks", jsonEncode(_streaks));
  }

  void _addHabit() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text("Add Habit"),
          content: TextField(controller: controller),
          actions: [
            TextButton(
              onPressed: () {
                final habit = controller.text.trim();
                if (habit.isNotEmpty) {
                  setState(() {
                    _habits.add(habit);
                    _streaks[habit] = 0;
                  });
                  _saveHabits();
                }
                Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void _incrementStreak(String habit) {
    setState(() {
      _streaks[habit] = (_streaks[habit] ?? 0) + 1;
    });
    _saveHabits();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final habit in _habits)
          ListTile(
            title: Text(habit),
            subtitle: Text("Streak: ${_streaks[habit] ?? 0}"),
            trailing: IconButton(
              icon: const Icon(Icons.check),
              onPressed: () => _incrementStreak(habit),
            ),
          ),
        ElevatedButton.icon(
          onPressed: _addHabit,
          icon: const Icon(Icons.add),
          label: const Text("New Habit"),
        ),
      ],
    );
  }
}

//////////////////// STATS PAGE ////////////////////

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: [
                  FlSpot(1, 2),
                  FlSpot(2, 3),
                  FlSpot(3, 1),
                  FlSpot(4, 4),
                ],
                isCurved: true,
                dotData: FlDotData(show: true),
                color: Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//////////////////// NOTES PAGE ////////////////////

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  List<String> _notes = [];
  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      _notes = prefs!.getStringList("notes") ?? [];
    });
  }

  Future<void> _saveNotes() async {
    await prefs!.setStringList("notes", _notes);
  }

  void _addNote() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text("Add Note"),
          content: TextField(controller: controller),
          actions: [
            TextButton(
              onPressed: () {
                final note = controller.text.trim();
                if (note.isNotEmpty) {
                  setState(() {
                    _notes.add(note);
                  });
                  _saveNotes();
                }
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final note in _notes) ListTile(title: Text(note)),
        ElevatedButton.icon(
          onPressed: _addNote,
          icon: const Icon(Icons.add),
          label: const Text("New Note"),
        ),
      ],
    );
  }
}

//////////////////// PDF VIEWER ////////////////////

class PdfViewerPage extends StatefulWidget {
  const PdfViewerPage({super.key});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  File? _pdfFile;
  PdfController? _pdfController;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ["pdf"]);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      setState(() {
        _pdfFile = file;
        _pdfController = PdfController(document: PdfDocument.openFile(file.path));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _pdfController == null
          ? ElevatedButton.icon(
              onPressed: _pickPdf,
              icon: const Icon(Icons.upload_file),
              label: const Text("Open PDF"),
            )
          : PdfView(controller: _pdfController!),
    );
  }
}
