import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // Ensure Flutter binding is initialized before using plugins like SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// ---------------------- Data Models ----------------------
class SetEntry {
  int reps;
  double weight;

  SetEntry({required this.reps, required this.weight});

  Map<String, dynamic> toMap() => {'reps': reps, 'weight': weight};
  
  // Explicit casting for safety
  factory SetEntry.fromMap(Map<String, dynamic> map) =>
      SetEntry(reps: map['reps'] as int, weight: map['weight'] as double);
}

class Exercise {
  String name;
  List<SetEntry> sets;

  Exercise({required this.name, required this.sets});

  Map<String, dynamic> toMap() =>
      {'name': name, 'sets': sets.map((s) => s.toMap()).toList()};

  // Explicit casting for safety
  factory Exercise.fromMap(Map<String, dynamic> map) => Exercise(
      name: map['name'] as String,
      sets: List<SetEntry>.from(
          (map['sets'] as List).map((s) => SetEntry.fromMap(s as Map<String, dynamic>))));
}

class DailyWorkout {
  String workoutType;
  String description;
  List<Exercise> exercises;

  DailyWorkout(
      {required this.workoutType,
      required this.description,
      required this.exercises});

  Map<String, dynamic> toMap() => {
        'workoutType': workoutType,
        'description': description,
        'exercises': exercises.map((e) => e.toMap()).toList()
      };

  // Explicit casting for safety and null handling for description
  factory DailyWorkout.fromMap(Map<String, dynamic> map) => DailyWorkout(
      workoutType: map['workoutType'] as String,
      description: map['description'] as String? ?? '', // Default to empty string
      exercises: List<Exercise>.from(
          (map['exercises'] as List).map((e) => Exercise.fromMap(e as Map<String, dynamic>))));
}

// ---------------------- Main App ----------------------
// ---------------------- Main App (FINAL FIX) ----------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Tracker',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFF1E3A8A), 
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepOrange,
          titleTextStyle: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amberAccent,
            foregroundColor: Colors.black,
          ),
        ),
        // FINAL FIX: Changed CardTheme to CardThemeData to satisfy the compiler
        cardTheme: CardThemeData( // <--- THIS LINE IS THE CHANGE
          elevation: 6,
          // Removed 'const' for RoundedRectangleBorder
          shape: RoundedRectangleBorder( 
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ---------------------- Home Page ----------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _selectedDay = DateTime.now();
  // We need a focusedDay for the TableCalendar
  DateTime _focusedDay = DateTime.now(); 
  Map<String, DailyWorkout> _workouts = {};
  final List<String> workoutTypes = const [
    "Iron Back",
    "Chest of Steel",
    "Rock Hard Legs",
    "Boulder Shoulders"
  ];

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  // Utility to get the date key (YYYY-MM-DD)
  String _getDateKey(DateTime day) => day.toIso8601String().split('T')[0];

  Future<void> _loadWorkouts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('workouts');
    if (data != null) {
      final Map<String, dynamic> decoded = jsonDecode(data) as Map<String, dynamic>;
      setState(() {
        _workouts = decoded.map((key, value) =>
            MapEntry(key, DailyWorkout.fromMap(value as Map<String, dynamic>)));
      });
    }
  }

  Future<void> _saveWorkouts() async {
    final prefs = await SharedPreferences.getInstance();
    // Convert the map of DailyWorkout objects to a map of their serializable map representations
    final encoded = jsonEncode(
        _workouts.map((key, value) => MapEntry(key, value.toMap())));
    await prefs.setString('workouts', encoded);
  }

  // ---------------------- Assign Workout Type + Description ----------------------
  Future<void> _assignWorkoutType() async {
    String selected = workoutTypes[0];
    final descController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        // Use StatefulBuilder to allow the DropdownButton to update its value visually
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Select Workout Type'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: selected,
                    items: workoutTypes
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() { // Use the inner setState for the dialog's state
                          selected = value;
                        });
                      }
                    },
                  ),
                  TextField(
                    controller: descController,
                    decoration:
                        const InputDecoration(labelText: 'Description (optional)'),
                  )
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    final dateKey = _getDateKey(_selectedDay);
                    // Use the outer setState for the HomePage's state
                    this.setState(() { 
                      _workouts[dateKey] = DailyWorkout(
                          workoutType: selected,
                          description: descController.text,
                          exercises: []);
                    });
                    _saveWorkouts();
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------- Add Exercise ----------------------
  Future<void> _addExercise() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Exercise'),
        content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Exercise Name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                final dateKey = _getDateKey(_selectedDay);
                final exercise = Exercise(name: nameController.text.trim(), sets: []);
                
                // Only add if the name is not empty
                if (exercise.name.isNotEmpty) {
                   setState(() {
                      _workouts[dateKey]?.exercises.add(exercise);
                    });
                    _saveWorkouts();
                }
                Navigator.pop(context);
              },
              child: const Text('Add'))
        ],
      ),
    );
  }

  // ---------------------- Add Set ----------------------
  Future<void> _addSet(String dateKey, Exercise exercise) async {
    final repsController = TextEditingController();
    final weightController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Set for ${exercise.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: repsController,
                decoration: const InputDecoration(labelText: 'Reps'),
                keyboardType: TextInputType.number),
            TextField(
                controller: weightController,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                final reps = int.tryParse(repsController.text) ?? 0;
                // Use a safe parse for double, accounting for locales that use commas
                final weight = double.tryParse(weightController.text.replaceAll(',', '.')) ?? 0.0; 
                
                // Only save the set if reps or weight is greater than 0
                if (reps > 0 || weight > 0) {
                    setState(() {
                      exercise.sets.add(SetEntry(reps: reps, weight: weight));
                    });
                    _saveWorkouts();
                }
                Navigator.pop(context);
              },
              child: const Text('Add')),
        ],
      ),
    );
  }

  // ---------------------- Exercise History ----------------------
  List<SetEntry> _getExerciseHistory(String exerciseName) {
    // Sort dates descending (most recent first)
    final sortedDates = _workouts.keys.toList()..sort((a, b) => b.compareTo(a));
    List<SetEntry> history = [];
    
    for (var date in sortedDates) {
      // Skip the currently selected day to only show *past* history
      if (date == _getDateKey(_selectedDay)) continue; 
      
      final workout = _workouts[date];
      if (workout != null) {
        // Find the exercise by name
        final exIndex = workout.exercises.indexWhere((e) => e.name == exerciseName);
        if (exIndex != -1) {
             history.addAll(workout.exercises[exIndex].sets);
        }
      }
      // Stop collecting history once we reach 20 sets
      if (history.length >= 20) break; 
    }
    return history;
  }

  @override
  Widget build(BuildContext context) {
    final dateKey = _getDateKey(_selectedDay);
    final dailyWorkout = _workouts[dateKey];

    return Scaffold(
      appBar: AppBar(title: const Text('Gym Tracker: Kakarot Mode')),
      body: Column(
        children: [
          // --- Table Calendar Widget ---
          TableCalendar(
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay; 
              });
            },
            calendarFormat: CalendarFormat.week, // Use compact week format
            // Add event markers for days with workouts
            eventLoader: (day) {
              final key = _getDateKey(day);
              return _workouts.containsKey(key) ? [1] : [];
            },
            calendarStyle: const CalendarStyle(
              todayDecoration:
                  BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              selectedDecoration:
                  BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
              // Marker for days with events (workouts)
              markerDecoration:
                  BoxDecoration(color: Colors.red, shape: BoxShape.circle), 
              weekendTextStyle: TextStyle(color: Colors.deepOrange),
              outsideTextStyle: TextStyle(color: Colors.grey),
            ),
            headerStyle: const HeaderStyle(
                formatButtonVisible: false, 
                titleCentered: true,
                titleTextStyle: TextStyle(color: Colors.white, fontSize: 18)
            ),
          ),
          
          // --- Workout Summary Card ---
          if (dailyWorkout != null)
            Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Workout: ${dailyWorkout.workoutType}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (dailyWorkout.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Note: ${dailyWorkout.description}',
                          style:
                              const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          
          // --- Exercise List ---
          Expanded(
            child: dailyWorkout == null
                ? Center(
                    child: Text(
                      'No workout assigned for ${_getDateKey(_selectedDay)}. Tap 🟡 to begin!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ))
                : ListView(
                    children: [
                      ...dailyWorkout.exercises.map((ex) => Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              title: Text(ex.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              children: [
                                // List of Sets
                                Column(
                                  children: [
                                    ...ex.sets.asMap().entries.map((entry) {
                                      final idx = entry.key + 1;
                                      final s = entry.value;
                                      return ListTile(
                                          dense: true,
                                          title: Text(
                                              'Set $idx: ${s.reps} reps @ ${s.weight.toStringAsFixed(1)} kg'));
                                    }),
                                    
                                    // Action Buttons
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          ElevatedButton.icon(
                                              onPressed: () =>
                                                  _addSet(dateKey, ex),
                                              icon: const Icon(Icons.add),
                                              label: const Text('Add Set')),
                                          ElevatedButton.icon(
                                              onPressed: () {
                                                final history =
                                                    _getExerciseHistory(ex.name);
                                                showDialog(
                                                    context: context,
                                                    builder: (context) =>
                                                        AlertDialog(
                                                          title: Text(
                                                              'History for ${ex.name}'),
                                                          content: SizedBox(
                                                            width: double.maxFinite,
                                                            child: history.isEmpty 
                                                                ? const Text('No previous sets found.')
                                                                : ListView.builder(
                                                              shrinkWrap: true,
                                                              itemCount:
                                                                  history.length,
                                                              itemBuilder:
                                                                  (context, index) {
                                                                final h =
                                                                    history[index];
                                                                return ListTile(
                                                                    dense: true,
                                                                    title: Text(
                                                                        '${h.reps} reps @ ${h.weight.toStringAsFixed(1)} kg'));
                                                              },
                                                            ),
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context),
                                                                child: const Text(
                                                                    'Close'))
                                                          ],
                                                        ));
                                              },
                                              icon: const Icon(Icons.history),
                                              label: const Text('View History'))
                                        ],
                                      ),
                                    )
                                  ],
                                )
                              ],
                            ),
                          )),
                    ],
                  ),
          ),
        ],
      ),
      // --- Floating Action Button ---
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amberAccent,
        foregroundColor: Colors.black,
        // Logic: If workout exists, add an exercise; otherwise, assign a workout type
        onPressed: dailyWorkout != null ? _addExercise : _assignWorkoutType,
        child: dailyWorkout != null 
            ? const Icon(Icons.add) // Add Exercise
            : const Icon(Icons.assignment), // Assign Workout
      ),
    );
  }
}