// Flutter: Happiness / State evaluation app
// File: flutter_happiness_tracker.dart
// pubspec dependencies (add to your pubspec.yaml):
//   flutter:
//     sdk: flutter
//   shared_preferences: ^2.0.15
//   fl_chart: ^0.55.1

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(HappinessTrackerApp());
}

class HappinessTrackerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Happiness Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(),
    );
  }
}

// Models
class ReferenceEvent {
  final String id;
  final String title;
  double rating; // user rating, signed
  ReferenceEvent({required this.id, required this.title, this.rating = 0});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'rating': rating};
  factory ReferenceEvent.fromJson(Map<String, dynamic> j) => ReferenceEvent(
      id: j['id'], title: j['title'], rating: (j['rating'] ?? 0).toDouble());
}

class DailyEvent {
  final String id;
  final DateTime date;
  final String title;
  final double rating;
  DailyEvent({required this.id, required this.date, required this.title, required this.rating});

  Map<String, dynamic> toJson() => {'id': id, 'date': date.toIso8601String(), 'title': title, 'rating': rating};
  factory DailyEvent.fromJson(Map<String, dynamic> j) => DailyEvent(
      id: j['id'], date: DateTime.parse(j['date']), title: j['title'], rating: (j['rating'] ?? 0).toDouble());
}

// Storage keys
const String kRefEventsKey = 'ref_events_v1';
const String kDailyEventsKey = 'daily_events_v1';

// Home
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<ReferenceEvent> _refs = [];
  List<DailyEvent> _daily = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final refsRaw = prefs.getString(kRefEventsKey);
    final dailyRaw = prefs.getString(kDailyEventsKey);
    if (refsRaw == null) {
      _refs = _defaultReferenceEvents();
      await prefs.setString(kRefEventsKey, jsonEncode(_refs.map((e) => e.toJson()).toList()));
    } else {
      final parsed = jsonDecode(refsRaw) as List;
      _refs = parsed.map((e) => ReferenceEvent.fromJson(e)).toList();
    }
    if (dailyRaw != null) {
      final parsed = jsonDecode(dailyRaw) as List;
      _daily = parsed.map((e) => DailyEvent.fromJson(e)).toList();
    }
    setState(() => _loaded = true);
  }

  List<ReferenceEvent> _defaultReferenceEvents() => [
        ReferenceEvent(id: 'r1', title: 'Умер близкий родственник'),
        ReferenceEvent(id: 'r2', title: 'Выиграл 100000'),
        ReferenceEvent(id: 'r3', title: 'Потерял работу'),
        ReferenceEvent(id: 'r4', title: 'Рождение ребёнка'),
        ReferenceEvent(id: 'r5', title: 'Серьёзная болезнь'),
      ];

  double computeX() {
    if (_refs.isEmpty) return 10.0;
    final absVals = _refs.map((r) => r.rating.abs()).toList();
    final maxAbs = absVals.isEmpty ? 10.0 : absVals.reduce((a, b) => a > b ? a : b);
    return maxAbs == 0 ? 10.0 : maxAbs; // fallback
  }

  Future<void> _openReferenceTest() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReferenceTestPage(refs: _refs)));
    await _loadData();
  }

  Future<void> _openAddEvent() async {
    final x = computeX();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddEventPage(maxScale: x)));
    await _loadData();
  }

  Future<void> _openStats() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => StatsPage()));
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text('Оценка состояний')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(onPressed: _openReferenceTest, child: Text('Пройти тест эталонов')),
            SizedBox(height: 12),
            ElevatedButton(onPressed: _openAddEvent, child: Text('Добавить событие дня')),
            SizedBox(height: 12),
            ElevatedButton(onPressed: _openStats, child: Text('Статистика')),
            SizedBox(height: 24),
            Text('Текущий масштаб x = ${computeX().toStringAsFixed(1)}', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('Эталонные события (и ваши оценки):', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: _refs.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(_refs[i].title),
                  trailing: Text(_refs[i].rating.toStringAsFixed(1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Reference test page
class ReferenceTestPage extends StatefulWidget {
  final List<ReferenceEvent> refs;
  ReferenceTestPage({required this.refs});
  @override
  _ReferenceTestPageState createState() => _ReferenceTestPageState();
}

class _ReferenceTestPageState extends State<ReferenceTestPage> {
  late List<double> _ratings;

  @override
  void initState() {
    super.initState();
    _ratings = widget.refs.map((r) => r.rating).toList();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < widget.refs.length; i++) widget.refs[i].rating = _ratings[i];
    await prefs.setString(kRefEventsKey, jsonEncode(widget.refs.map((e) => e.toJson()).toList()));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Тест эталонных событий')),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.refs.length,
              itemBuilder: (_, i) {
                final ref = widget.refs[i];
                final rating = _ratings[i];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(ref.title, style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('Оцените это событие по вашей шкале (от -100 до 100):'),
                      Slider(
                        min: -100,
                        max: 100,
                        divisions: 200,
                        value: rating.clamp(-100.0, 100.0),
                        label: rating.toStringAsFixed(0),
                        onChanged: (v) => setState(() => _ratings[i] = v),
                      ),
                      Align(alignment: Alignment.centerRight, child: Text(_ratings[i].toStringAsFixed(0))),
                    ]),
                  ),
                );
              },
            ),
          ),
          ElevatedButton(onPressed: _save, child: Text('Сохранить'))
        ]),
      ),
    );
  }
}

// Add event page
class AddEventPage extends StatefulWidget {
  final double maxScale;
  AddEventPage({required this.maxScale});
  @override
  _AddEventPageState createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final _titleController = TextEditingController();
  double _rating = 0;

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kDailyEventsKey);
    final list = raw == null ? <Map<String, dynamic>>[] : List<Map<String, dynamic>>.from(jsonDecode(raw));
    final newEvent = DailyEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        title: _titleController.text.isEmpty ? 'Событие' : _titleController.text,
        rating: _rating);
    list.add(newEvent.toJson());
    await prefs.setString(kDailyEventsKey, jsonEncode(list));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final x = widget.maxScale;
    return Scaffold(
      appBar: AppBar(title: Text('Добавить событие')),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _titleController, decoration: InputDecoration(labelText: 'Название события')),
          SizedBox(height: 12),
          Text('Оцените событие от ${-x.toStringAsFixed(1)} до ${x.toStringAsFixed(1)}'),
          Slider(
            min: -x,
            max: x,
            value: _rating.clamp(-x, x),
            divisions: (x * 2).round().clamp(10, 400),
            label: _rating.toStringAsFixed(1),
            onChanged: (v) => setState(() => _rating = v),
          ),
          Align(alignment: Alignment.centerRight, child: Text(_rating.toStringAsFixed(1))),
          SizedBox(height: 16),
          ElevatedButton(onPressed: _save, child: Text('Сохранить')),
        ]),
      ),
    );
  }
}

// Stats page
class StatsPage extends StatefulWidget {
  @override
  _StatsPageState createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  List<DailyEvent> _events = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kDailyEventsKey);
    if (raw != null) {
      final parsed = jsonDecode(raw) as List;
      _events = parsed.map((e) => DailyEvent.fromJson(e)).toList();
      _events.sort((a, b) => a.date.compareTo(b.date));
    }
    setState(() => _loaded = true);
  }

  // Build cumulative sum points grouped by date (day)
  List<FlSpot> _buildSpots() {
    if (_events.isEmpty) return [];
    final Map<String, double> dailySum = {};
    for (var e in _events) {
      final key = DateTime(e.date.year, e.date.month, e.date.day).toIso8601String();
      dailySum[key] = (dailySum[key] ?? 0) + e.rating;
    }
    final entries = dailySum.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    double cumulative = 0;
    List<FlSpot> spots = [];
    for (int i = 0; i < entries.length; i++) {
      cumulative += entries[i].value;
      spots.add(FlSpot(i.toDouble(), cumulative));
    }
    return spots;
  }

  double _computeAverage() {
    if (_events.isEmpty) return 0.0;
    // average happiness level: mean of cumulative sums divided by number of measurements
    final spots = _buildSpots();
    if (spots.isEmpty) return 0.0;
    final sum = spots.map((s) => s.y).reduce((a, b) => a + b);
    return sum / spots.length;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return Scaffold(body: Center(child: CircularProgressIndicator()));
    final spots = _buildSpots();
    final avg = _computeAverage();
    return Scaffold(
      appBar: AppBar(title: Text('Статистика')),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(children: [
          Text('F(t) = S — кумулятивная сумма оценок по дням', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Expanded(
            child: spots.isEmpty
                ? Center(child: Text('Нет данных'))
                : Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          bottomTitles: SideTitles(showTitles: true, reservedSize: 22),
                          leftTitles: SideTitles(showTitles: true, reservedSize: 40),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: false,
                            dotData: FlDotData(show: true),
                            barWidth: 2,
                          )
                        ],
                      ),
                    ),
                  ),
          ),
          SizedBox(height: 12),
          Text('Средний уровень (среднее из F(t)): ${avg.toStringAsFixed(2)}'),
          SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _events.length,
              itemBuilder: (_, i) {
                final e = _events[i];
                return ListTile(
                  title: Text(e.title),
                  subtitle: Text('${e.date.toLocal()}'),
                  trailing: Text(e.rating.toStringAsFixed(1)),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
