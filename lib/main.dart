// main.dart — MedHabit (Medical Student Habit Tracker)
// MVP prototype: habits, stats (graphs), notes with folders, PDF library.
// Responsive (mobile/tablet/desktop): BottomNavigationBar on narrow, NavigationRail on wide.
// Persistence: SharedPreferences (JSON). Charts: fl_chart. PDF: pdfx. File picker: file_picker.
// NOTE: This is a single-file scaffold for MVP. For production, split into multiple files.

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
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
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedHabit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: _themeMode,
      home: RootShell(
        onToggleTheme: () {
          setState(() {
            if (_themeMode == ThemeMode.light) {
              _themeMode = ThemeMode.dark;
            } else {
              _themeMode = ThemeMode.light;
            }
          });
        },
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key, required this.onToggleTheme});
  final VoidCallback onToggleTheme;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  final HabitStore habitStore = HabitStore();
  final NotesStore notesStore = NotesStore();
  final LibraryStore libraryStore = LibraryStore();

  @override
  void initState() {
    super.initState();
    () async {
      await habitStore.load();
      await notesStore.load();
      await libraryStore.load();
      if (mounted) setState(() {});
    }();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 900;

    final pages = [
      HomePage(store: habitStore),
      StatsPage(store: habitStore),
      NotesPage(store: notesStore),
      LibraryPage(store: libraryStore),
      const PlaceholderFriends(),
      SettingsPage(onToggleTheme: widget.onToggleTheme),
    ];

    final destinations = const [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.show_chart_outlined), selectedIcon: Icon(Icons.show_chart), label: 'Stats'),
      NavigationDestination(icon: Icon(Icons.note_outlined), selectedIcon: Icon(Icons.note), label: 'Notes'),
      NavigationDestination(icon: Icon(Icons.local_library_outlined), selectedIcon: Icon(Icons.local_library), label: 'Library'),
      NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'Friends'),
      NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
    ];

    if (compact) {
      return Scaffold(
        body: SafeArea(child: pages[_index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          destinations: destinations,
          onDestinationSelected: (i) => setState(() => _index = i),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Home')),
              NavigationRailDestination(icon: Icon(Icons.show_chart_outlined), selectedIcon: Icon(Icons.show_chart), label: Text('Stats')),
              NavigationRailDestination(icon: Icon(Icons.note_outlined), selectedIcon: Icon(Icons.note), label: Text('Notes')),
              NavigationRailDestination(icon: Icon(Icons.local_library_outlined), selectedIcon: Icon(Icons.local_library), label: Text('Library')),
              NavigationRailDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: Text('Friends')),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[_index]),
        ],
      ),
    );
  }
}

// ---------------- HABITS ----------------

enum HabitCategory { study, health, lifestyle, clinical }
enum HabitFrequency { daily, weekly, monthly }

class Habit {
  Habit({
    required this.id,
    required this.title,
    required this.category,
    required this.frequency,
    this.reminderTime,
    Map<String, bool>? completions,
  }) : completions = completions ?? {};

  final String id;
  String title;
  HabitCategory category;
  HabitFrequency frequency;
  TimeOfDay? reminderTime;
  Map<String, bool> completions;

  bool isDone(DateTime day) => completions[_key(day)] ?? false;
  void toggle(DateTime day) {
    final k = _key(day);
    completions[k] = !(completions[k] ?? false);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.name,
        'frequency': frequency.name,
        'reminder': reminderTime == null ? null : {'h': reminderTime!.hour, 'm': reminderTime!.minute},
        'completions': completions,
      };
  static Habit fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'],
        title: j['title'],
        category: HabitCategory.values.firstWhere((e) => e.name == j['category']),
        frequency: HabitFrequency.values.firstWhere((e) => e.name == j['frequency']),
        reminderTime: j['reminder'] == null ? null : TimeOfDay(hour: j['reminder']['h'], minute: j['reminder']['m']),
        completions: (j['completions'] as Map?)?.map((k, v) => MapEntry(k.toString(), v as bool)) ?? {},
      );

  static String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
}

class HabitStore extends ChangeNotifier {
  final List<Habit> _habits = [];
  List<Habit> get habits => List.unmodifiable(_habits);

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('habits');
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _habits
        ..clear()
        ..addAll(list.map(Habit.fromJson));
    } else {
      // Start empty (user asked for empty)
      await save();
    }
    notifyListeners();
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    final data = jsonEncode(_habits.map((e) => e.toJson()).toList());
    await sp.setString('habits', data);
  }

  Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('habits');
    _habits.clear();
    notifyListeners();
  }

  void add(Habit h) {
    _habits.add(h);
    save();
    notifyListeners();
  }

  void remove(String id) {
    _habits.removeWhere((h) => h.id == id);
    save();
    notifyListeners();
  }

  void toggleToday(Habit h) {
    h.toggle(DateTime.now());
    save();
    notifyListeners();
  }

  double completionPercent(DateTime day) {
    if (_habits.isEmpty) return 0;
    final done = _habits.where((h) => h.isDone(day)).length;
    return done / _habits.length;
  }

  List<double> lastNDaysCompletion(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) => completionPercent(now.subtract(Duration(days: n - 1 - i))));
  }
}

// ---------------- HOME ----------------

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});
  final HabitStore store;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEE, MMM d').format(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: Text("Today's Habits — $today")),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          if (widget.store.habits.isEmpty) {
            return const Center(child: Text('No habits yet. Tap + to add.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, i) {
              final h = widget.store.habits[i];
              final done = h.isDone(DateTime.now());
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                leading: Checkbox(value: done, onChanged: (_) => widget.store.toggleToday(h)),
                title: Text(h.title),
                subtitle: Text('${describeEnum(h.category).toUpperCase()} • ${describeEnum(h.frequency)}'),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => widget.store.remove(h.id)),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: widget.store.habits.length,
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showDialog<Habit>(context: context, builder: (_) => HabitDialog());
          if (created != null) widget.store.add(created);
        },
        label: const Text('Add Habit'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class HabitDialog extends StatefulWidget {
  HabitDialog({super.key});

  @override
  State<HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends State<HabitDialog> {
  final titleCtrl = TextEditingController();
  HabitCategory cat = HabitCategory.study;
  HabitFrequency freq = HabitFrequency.daily;
  TimeOfDay? time;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Habit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            DropdownButtonFormField(
              value: cat,
              decoration: const InputDecoration(labelText: 'Category'),
              items: HabitCategory.values.map((e) => DropdownMenuItem(value: e, child: Text(describeEnum(e)))).toList(),
              onChanged: (v) => setState(() => cat = v!),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField(
              value: freq,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: HabitFrequency.values.map((e) => DropdownMenuItem(value: e, child: Text(describeEnum(e)))).toList(),
              onChanged: (v) => setState(() => freq = v!),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Reminder (optional)'),
                    child: Text(time == null ? 'None' : time!.format(context)),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 20, minute: 0));
                    if (picked != null) setState(() => time = picked);
                  },
                  icon: const Icon(Icons.access_time),
                  label: const Text('Pick'),
                )
              ],
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (titleCtrl.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              Habit(
                id: UniqueKey().toString(),
                title: titleCtrl.text.trim(),
                category: cat,
                frequency: freq,
                reminderTime: time,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ---------------- STATS ----------------

class StatsPage extends StatelessWidget {
  const StatsPage({super.key, required this.store});
  final HabitStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Progress')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final last7 = store.lastNDaysCompletion(7);
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last 7 Days', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: 1.8,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 1,
                      gridData: const FlGridData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 0.25, getTitlesWidget: (v, _) => Text('${(v * 100).round()}%'))),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              if (idx < 0 || idx >= last7.length) return const SizedBox.shrink();
                              final day = DateTime.now().subtract(Duration(days: last7.length - 1 - idx));
                              return Text(DateFormat('E').format(day));
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [for (int i = 0; i < last7.length; i++) FlSpot(i.toDouble(), last7[i])],
                          isCurved: true,
                          dotData: const FlDotData(show: false),
                          barWidth: 3,
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Today', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: store.completionPercent(DateTime.now())),
                const SizedBox(height: 8),
                Text('${(store.completionPercent(DateTime.now()) * 100).round()}% of habits done'),
                const SizedBox(height: 24),
                Text('Streak (days with 100% completion)', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in last7)
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: p >= 1.0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------- NOTES ----------------

class NotesStore extends ChangeNotifier {
  final List<Folder> folders = [];

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('notes');
    if (raw != null) {
      final data = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      folders
        ..clear()
        ..addAll(data.map(Folder.fromJson));
    } else {
      // Start empty per request
      await save();
    }
    notifyListeners();
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('notes', jsonEncode(folders.map((f) => f.toJson()).toList()));
  }

  Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('notes');
    folders.clear();
    notifyListeners();
  }
}

class Folder {
  Folder({required this.name, List<Note>? notes}) : notes = notes ?? [];
  String name;
  List<Note> notes;

  Map<String, dynamic> toJson() => {'name': name, 'notes': notes.map((n) => n.toJson()).toList()};
  static Folder fromJson(Map<String, dynamic> j) => Folder(
        name: j['name'],
        notes: ((j['notes'] as List?) ?? []).map((e) => Note.fromJson(e)).toList(),
      );
}

class Note {
  Note({required this.title, this.content = ''});
  String title;
  String content;

  Map<String, dynamic> toJson() => {'title': title, 'content': content};
  static Note fromJson(Map<String, dynamic> j) => Note(title: j['title'], content: j['content'] ?? '');
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, required this.store});
  final NotesStore store;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  int selectedFolder = 0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            onPressed: () async {
              final nameCtrl = TextEditingController();
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('New Folder'),
                  content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Folder name')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
                  ],
                ),
              );
              if (ok == true && nameCtrl.text.trim().isNotEmpty) {
                setState(() => widget.store.folders.add(Folder(name: nameCtrl.text.trim())));
                await widget.store.save();
              }
            },
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'New Folder',
          )
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          if (widget.store.folders.isEmpty) {
            return const Center(child: Text('No folders yet. Create one using + folder.'));
          }
          final folder = widget.store.folders[selectedFolder.clamp(0, widget.store.folders.length - 1)];
          if (wide) {
            return Row(
              children: [
                SizedBox(
                  width: 280,
                  child: _FolderList(store: widget.store, selected: selectedFolder, onSelect: (i) => setState(() => selectedFolder = i)),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _NotesList(folder: folder, onChanged: () => widget.store.save())),
              ],
            );
          }
          return _FolderList(store: widget.store, selected: selectedFolder, onSelect: (i) => setState(() => selectedFolder = i));
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (widget.store.folders.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create a folder first')));
            return;
          }
          final folder = widget.store.folders[selectedFolder];
          final note = await Navigator.push<Note>(context, MaterialPageRoute(builder: (_) => NoteEditor(note: Note(title: 'Untitled'))));
          if (note != null) {
            setState(() => folder.notes.add(note));
            await widget.store.save();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
      ),
    );
  }
}

class _FolderList extends StatelessWidget {
  const _FolderList({required this.store, required this.selected, required this.onSelect});
  final NotesStore store;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: store.folders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final f = store.folders[i];
        final isSel = i == selected;
        return ListTile(
          selected: isSel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tileColor: isSel ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
          title: Text(f.name),
          subtitle: Text('${f.notes.length} notes'),
          onTap: () => onSelect(i),
        );
      },
    );
  }
}

class _NotesList extends StatefulWidget {
  const _NotesList({required this.folder, required this.onChanged});
  final Folder folder;
  final VoidCallback onChanged;
  @override
  State<_NotesList> createState() => _NotesListState();
}

class _NotesListState extends State<_NotesList> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 340,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.folder.notes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final n = widget.folder.notes[i];
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                title: Text(n.title),
                subtitle: Text(_truncate(n.content)),
                onTap: () async {
                  final edited = await Navigator.push<Note>(context, MaterialPageRoute(builder: (_) => NoteEditor(note: n)));
                  if (edited != null) setState(() {});
                  widget.onChanged();
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() => widget.folder.notes.removeAt(i));
                    widget.onChanged();
                  },
                ),
              );
            },
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: widget.folder.notes.isEmpty
              ? const Center(child: Text('Select or create a note'))
              : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        widget.folder.notes.last.content,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
        )
      ],
    );
  }

  String _truncate(String s) => s.length <= 80 ? s : s.substring(0, 80) + '…';
}

class NoteEditor extends StatefulWidget {
  const NoteEditor({super.key, required this.note});
  final Note note;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final TextEditingController title = TextEditingController(text: widget.note.title);
  late final TextEditingController body = TextEditingController(text: widget.note.content);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Note'),
        actions: [
          IconButton(onPressed: () => Navigator.pop(context, Note(title: title.text.trim(), content: body.text)), icon: const Icon(Icons.check)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: body,
                expands: true,
                maxLines: null,
                minLines: null,
                decoration: const InputDecoration(
                  hintText: 'Write your notes... (plain text for MVP)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- PDF LIBRARY ----------------

class LibraryStore extends ChangeNotifier {
  final List<String> files = [];

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    files
      ..clear()
      ..addAll((sp.getStringList('library') ?? []));
    notifyListeners();
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList('library', files);
  }

  Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('library');
    files.clear();
    notifyListeners();
  }
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.store});
  final LibraryStore store;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Library')),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          if (widget.store.files.isEmpty) {
            return const Center(child: Text('No PDFs yet. Use + to add from device.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.store.files.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final path = widget.store.files[i];
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                leading: const Icon(Icons.picture_as_pdf),
                title: Text(_fileName(path)),
                subtitle: Text(path),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewerPage(path: path))),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    setState(() => widget.store.files.removeAt(i));
                    await widget.store.save();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
          if (result != null && result.files.single.path != null) {
            setState(() => widget.store.files.add(result.files.single.path!));
            await widget.store.save();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add PDF'),
      ),
    );
  }

  String _fileName(String path) => path.split(Platform.pathSeparator).last;
}

class PdfViewerPage extends StatefulWidget {
  const PdfViewerPage({super.key, required this.path});
  final String path;

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  late PdfControllerPinch controller;

  @override
  void initState() {
    super.initState();
    controller = PdfControllerPinch(document: PdfDocument.openFile(widget.path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titleFromPath(widget.path))),
      body: PdfViewPinch(controller: controller),
    );
  }

  String _titleFromPath(String p) => p.split(Platform.pathSeparator).last;
}

// ---------------- FRIENDS (placeholder) ----------------

class PlaceholderFriends extends StatelessWidget {
  const PlaceholderFriends({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friends (coming soon)')),
      body: const Center(child: Text('Friends & Competition will be added in v2.')),
    );
  }
}

// ---------------- SETTINGS ----------------

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.onToggleTheme});
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Toggle Light/Dark'),
            subtitle: const Text('Switches the app theme'),
            trailing: IconButton(onPressed: onToggleTheme, icon: const Icon(Icons.brightness_6_outlined)),
          ),
          ListTile(
            title: const Text('Clear All Data'),
            subtitle: const Text('Reset habits, notes, and library'),
            leading: const Icon(Icons.delete_forever_outlined),
            onTap: () async {
              final sure = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Clear All Data?'),
                  content: const Text('This will remove all locally stored habits, notes, and PDFs list.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
                  ],
                ),
              );
              if (sure == true) {
                final sp = await SharedPreferences.getInstance();
                await sp.clear();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data cleared. Restart the app.')));
              }
            },
          ),
          const Divider(),
          const ListTile(
            title: Text('About'),
            subtitle: Text('MedHabit — Habit & Study Companion for Medical Students (v1, offline)'),
          )
        ],
      ),
    );
  }
}
