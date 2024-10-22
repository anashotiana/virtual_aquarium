import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p; // Alias for the path package to avoid conflicts
import 'dart:math';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Aquarium',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: VirtualAquariumScreen(),
    );
  }
}

class VirtualAquariumScreen extends StatefulWidget {
  @override
  _VirtualAquariumScreenState createState() => _VirtualAquariumScreenState();
}

class _VirtualAquariumScreenState extends State<VirtualAquariumScreen> {
  List<Fish> fishList = [];
  Color selectedColor = Colors.blue;
  double selectedSpeed = 2.0;

  @override
  void initState() {
    super.initState();
    _loadFish();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Virtual Aquarium')),
      body: Column(
        children: [
          // Aquarium container
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blueAccent),
            ),
            child: Stack(
              children: fishList
                  .map((fish) => AnimatedFishWidget(fish: fish))
                  .toList(),
            ),
          ),
          // Speed slider
          Slider(
            value: selectedSpeed,
            min: 0.1,
            max: 5.0,
            onChanged: (value) {
              setState(() {
                selectedSpeed = value;
              });
            },
          ),
          // Color picker dropdown
          DropdownButton<Color>(
            value: selectedColor,
            items: [Colors.red, Colors.blue, Colors.green].map((color) {
              return DropdownMenuItem(
                value: color,
                child: Container(
                  width: 24,
                  height: 24,
                  color: color,
                ),
              );
            }).toList(),
            onChanged: (color) {
              setState(() {
                selectedColor = color!;
              });
            },
          ),
          // Add Fish button
          ElevatedButton(
            onPressed: _addFish,
            child: Text('Add Fish'),
          ),
          // Save Settings button
          ElevatedButton(
            onPressed: _saveSettings,
            child: Text('Save Settings'),
          ),
        ],
      ),
    );
  }

  // Add fish method
  void _addFish() async {
    if (fishList.length < 10) {
      Fish newFish = Fish(color: selectedColor, speed: selectedSpeed);

      // Save fish to the database
      await DatabaseHelper().saveFish({
        'color': newFish.color.value,  // Save color as an integer
        'speed': newFish.speed,
      });

      setState(() {
        fishList.add(newFish);
      });
    }
  }

  // Load fish from database on app startup
  void _loadFish() async {
    List<Map<String, dynamic>> savedFish = await DatabaseHelper().getFish();

    setState(() {
      fishList = savedFish.map((fishData) {
        return Fish(
          color: Color(fishData['color']),
          speed: fishData['speed'],
        );
      }).toList();
    });
  }

  // Save current fish settings
  void _saveSettings() async {
    // Clear all existing fish data from the database
    await DatabaseHelper().deleteAllFish();

    // Save each fish's data to the database
    for (Fish fish in fishList) {
      await DatabaseHelper().saveFish({
        'color': fish.color.value,
        'speed': fish.speed,
      });
    }

    // Display a success message using BuildContext
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Aquarium settings saved!')),
    );
  }
}

// Fish model class
class Fish {
  final Color color;
  final double speed;

  Fish({required this.color, required this.speed});
}

// Animated Fish Widget with movement
class AnimatedFishWidget extends StatefulWidget {
  final Fish fish;
  AnimatedFishWidget({required this.fish});

  @override
  _AnimatedFishWidgetState createState() => _AnimatedFishWidgetState();
}

class _AnimatedFishWidgetState extends State<AnimatedFishWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;
  final Random random = Random();

  @override
  void initState() {
    super.initState();

    // Random initial positions and directions
    double startX = random.nextDouble();
    double startY = random.nextDouble();
    double endX = random.nextDouble();
    double endY = random.nextDouble();

    _controller = AnimationController(
      duration: Duration(seconds: widget.fish.speed.toInt() + 1), // Speed control
      vsync: this,
    )..repeat(reverse: true);

    _positionAnimation = Tween<Offset>(
      begin: Offset(startX, startY),
      end: Offset(endX, endY),
    ).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _positionAnimation,
      builder: (context, child) {
        return Positioned(
          left: _positionAnimation.value.dx * 300, // Adjust based on container size
          top: _positionAnimation.value.dy * 300,
          child: CircleAvatar(
            backgroundColor: widget.fish.color,
            radius: 15,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// Database helper for SQLite
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = p.join(await getDatabasesPath(), 'aquarium.db'); // Use alias for path package
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE fish(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        color INTEGER,
        speed REAL
      )
    ''');
  }

  Future<int> saveFish(Map<String, dynamic> fish) async {
    Database db = await database;
    return await db.insert('fish', fish);
  }

  Future<List<Map<String, dynamic>>> getFish() async {
    Database db = await database;
    return await db.query('fish');
  }

  Future<void> deleteAllFish() async {
    Database db = await database;
    await db.delete('fish');
  }
}
