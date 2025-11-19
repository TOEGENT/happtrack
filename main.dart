// Flutter: Happiness Tracker (улучшенная версия 2025)

// pubspec.yaml зависимости:

// dependencies:

//   flutter:

//     sdk: flutter

//   shared_preferences: ^2.3.0

//   fl_chart: ^0.68.0

//   uuid: ^4.4.0

//   intl: ^0.19.0

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:fl_chart/fl_chart.dart';

import 'package:uuid/uuid.dart';

import 'package:intl/intl.dart';

void main() {

  runApp(const HappinessTrackerApp());

}

class HappinessTrackerApp extends StatelessWidget {

  const HappinessTrackerApp({super.key});

  @override

  Widget build(BuildContext context) {

    return MaterialApp(

      title: 'Трекер счастья',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),

        useMaterial3: true,

        appBarTheme: const AppBarTheme(centerTitle: true),

      ),

      home: const HomePage(),

    );

  }

}

// ========================

// Модели

// ========================

class ReferenceEvent {

  final String id;

  final String title;

  double rating;

  ReferenceEvent({

    required this.id,

    required this.title,

    this.rating = 0.0,

  });

  factory ReferenceEvent copyWith({double? rating}) {

    return ReferenceEvent(id: id, title: title, rating: rating ?? this.rating);

  }

  Map<String, dynamic> toJson() => {

        'id': id,

        'title': title,

        'rating': rating,

      };

  factory ReferenceEvent.fromJson(Map<String, dynamic> json) => ReferenceEvent(

        id: json['id'] as String,

        title: json['title'] as String,

        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,

      );

}

class DailyEvent {

  final String id;

  final DateTime date;

  final String title;

  final double rating;

  DailyEvent({

    required this.id,

    required this.date,

    required this.title,

    required this.rating,

  });

  DailyEvent copyWith({

    String? id,

    DateTime? date,

    String? title,

    double? rating,

  }) {

    return DailyEvent(

      id: id ?? this.id,

      date: date ?? this.date,

      title: title ?? this.title,

      rating: rating ?? this.rating,

    );

  }

  Map<String, dynamic> toJson() => {

        'id': id,

        'date': date.toIso8601String(),

        'title': title,

        'rating': rating,

      };

  factory DailyEvent.fromJson(Map<String, dynamic> json) => DailyEvent(

        id: json['id'] as String,

        date: DateTime.parse(json['date'] as String),

        title: json['title'] as String,

        rating: (json['rating'] as num).toDouble(),

      );

}

// ========================

// Репозиторий (единая точка работы с данными)

// ========================

class HappinessRepository {

  static const String _refKey = 'ref_events_v2';

  static const String _dailyKey = 'daily_events_v2';

  late SharedPreferences _prefs;

  static final HappinessRepository _instance = HappinessRepository._();

  factory HappinessRepository() => _instance;

  HappinessRepository._();

  Future<void> init() async {

    _prefs = await SharedPreferences.getInstance();

  }

  // Эталонные события

  Future<List<ReferenceEvent>> getReferenceEvents() async {

    final jsonString = _prefs.getString(_refKey);

    if (jsonString == null) {

      final defaults = _defaultReferences();

      await saveReferenceEvents(defaults);

      return defaults;

    }

    final List jsonList = jsonDecode(jsonString);

    return jsonList.map((e) => ReferenceEvent.fromJson(e)).toList();

  }

  Future<void> saveReferenceEvents(List<ReferenceEvent> events) async {

    final jsonString = jsonEncode(events.map((e) => e.toJson()).toList());

    await _prefs.setString(_refKey, jsonString);

  }

  // Дневные события

  Future<List<DailyEvent>> getDailyEvents() async {

    final jsonString = _prefs.getString(_dailyKey);

    if (jsonString == null) return [];

    final List jsonList = jsonDecode(jsonString);

    final events = jsonList.map((e) => DailyEvent.fromJson(e)).toList();

    events.sort((a, b) => a.date.compareTo(b.date));

    return events;

  }

  Future<void> addDailyEvent(DailyEvent event) async {

    final events = await getDailyEvents();

    events.add(event);

    final jsonString = jsonEncode(events.map((e) => e.toJson()).toList());

    await _prefs.setString(_dailyKey, jsonString);

  }

  List<ReferenceEvent> _defaultReferences() => [

        ReferenceEvent(id: const Uuid().v4(), title: 'Умер близкий родственник'),

        ReferenceEvent(id: const Uuid().v4(), title: 'Выиграл миллион'),

        ReferenceEvent(id: const Uuid().v4(), title: 'Потерял работу'),

        ReferenceEvent(id: const Uuid().v4(), title: 'Рождение ребёнка'),

        ReferenceEvent(id: const Uuid().v4(), title: 'Серьёзная болезнь'),

        ReferenceEvent(id: const Uuid().v4(), title: 'Влюбился'),

        ReferenceEvent(id: const Uuid().v4(), title: 'Развод'),

      ];

}

// ========================

// Главная страница

// ========================

class HomePage extends StatefulWidget {

  const HomePage({super.key});

  @override

  State<HomePage> createState() => _HomePageState();

}

class _HomePageState extends State<HomePage> {

  late Future<void> _initFuture;

  @override

  void initState() {

    super.initState();

    _initFuture = HappinessRepository().init();

  }

  double _computeScale(List<ReferenceEvent> refs) {

    if (refs.isEmpty) return 100.0;

    final maxAbs = refs.map((e) => e.rating.abs()).reduce((a, b) => a > b ? a : b);

    return maxAbs == 0 ? 100.0 : maxAbs;

  }

  @override

  Widget build(BuildContext context) {

    return FutureBuilder<void>(

      future: _initFuture,

      builder: (context, snapshot) {

        if (snapshot.connectionState != ConnectionState.done) {

          return const Scaffold(body: Center(child: CircularProgressIndicator()));

        }

        return const _HomeContent();

      },

    );

  }

}

class _HomeContent extends StatefulWidget {

  const _HomeContent();

  @override

  State<_HomeContent> createState() => _HomeContentState();

}

class _HomeContentState extends State<_HomeContent> {

  late ValueNotifier<List<ReferenceEvent>> _refNotifier;

  @override

  void initState() {

    super.initState();

    _refNotifier = ValueNotifier([]);

    _loadReferences();

  }

  Future<void> _loadReferences() async {

    final refs = await HappinessRepository().getReferenceEvents();

    _refNotifier.value = refs;

  }

  @override

  void dispose() {

    _refNotifier.dispose();

    super.dispose();

  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text('Трекер счастья')),

      body: ValueListenableBuilder<List<ReferenceEvent>>(

        valueListenable: _refNotifier,

        builder: (context, refs, _) {

          final scale = refs.isEmpty

              ? 100.0

              : refs.map((e) => e.rating.abs()).reduce((a, b) => a > b ? a : b);

          return Padding(

            padding: const EdgeInsets.all(16),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [

                Card(

                  child: Padding(

                    padding: const EdgeInsets.all(16),

                    child: Column(

                      children: [

                        Text('Текущая шкала: ±${scale.toStringAsFixed(1)}',

                            style: Theme.of(context).textTheme.titleLarge),

                        const SizedBox(height: 8),

                        Text('На основе ваших оценок эталонных событий',

                            style: Theme.of(context).textTheme.bodyMedium),

                      ],

                    ),

                  ),

                ),

                const SizedBox(height: 20),

                ElevatedButton.icon(

                  onPressed: () async {

                    await Navigator.push(

                      context,

                      MaterialPageRoute(

                        builder: (_) => ReferenceTestPage(

                          onSave: () => _loadReferences(),

                        ),

                      ),

                    );

                  },

                  icon: const Icon(Icons.balance),

                  label: const Text('Калибровка эталонов'),

                ),

                const SizedBox(height: 12),

                ElevatedButton.icon(

                  onPressed: () async {

                    await Navigator.push(

                      context,

                      MaterialPageRoute(

                        builder: (_) => AddEventPage(scale: scale == 0 ? 100 : scale),

                      ),

                    );

                    setState(() {}); // чтобы обновить статистику

                  },

                  icon: const Icon(Icons.add_circle_outline),

                  label: const Text('Добавить событие дня'),

                ),

                const SizedBox(height: 12),

                ElevatedButton.icon(

                  onPressed: () => Navigator.push(context,

                      MaterialPageRoute(builder: (_) => const StatsPage())),

                  icon: const Icon(Icons.bar_chart),

                  label: const Text('Статистика и график'),

                ),

                const SizedBox(height: 24),

                Text('Эталонные события:',

                    style: Theme.of(context).textTheme.titleMedium),

                const SizedBox(height: 8),

                Expanded(

                  child: ListView.builder(

                    itemCount: refs.length,

                    itemBuilder: (context, i) {

                      final r = refs[i];

                      return ListTile(

                        leading: CircleAvatar(

                          child: Text(r.rating.abs().toStringAsFixed(0)),

                        ),

                        title: Text(r.title),

                        trailing: Text(

                          r.rating >= 0 ? '+${r.rating.toStringAsFixed(1)}' : r.rating.toStringAsFixed(1),

                          style: TextStyle(

                            color: r.rating >= 0 ? Colors.green[700] : Colors.red[700],

                            fontWeight: FontWeight.bold,

                          ),

                        ),

                      );

                    },

                  ),

                ),

              ],

            ),

          );

        },

      ),

    );

  }

}

// ========================

// Страница калибровки эталонов

// ========================

class ReferenceTestPage extends StatefulWidget {

  final VoidCallback onSave;

  const ReferenceTestPage({super.key, required this.onSave});

  @override

  State<ReferenceTestPage> createState() => _ReferenceTestPageState();

}

class _ReferenceTestPageState extends State<ReferenceTestPage> {

  late List<ReferenceEvent> _events;

  bool _loading = true;

  @override

  void initState() {

    super.initState();

    _load();

  }

  Future<void> _load() async {

    _events = await HappinessRepository().getReferenceEvents();

    setState(() => _loading = false);

  }

  Future<void> _save() async {

    await HappinessRepository().saveReferenceEvents(_events);

    widget.onSave();

    if (mounted) Navigator.of(context).pop();

  }

  @override

  Widget build(BuildContext context) {

    if (_loading) {

      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    }

    return Scaffold(

      appBar: AppBar(title: const Text('Калибровка эталонов')),

      body: Column(

        children: [

          const Padding(

            padding: EdgeInsets.all(16),

            child: Text(

              'Оцените, насколько сильно каждое событие влияет на ваше счастье.\n'

              'Это нужно для правильной шкалы в будущем.',

              textAlign: TextAlign.center,

            ),

          ),

          Expanded(

            child: ListView.separated(

              padding: const EdgeInsets.symmetric(horizontal: 16),

              itemCount: _events.length,

              separatorBuilder: (_, __) => const SizedBox(height: 12),

              itemBuilder: (context, i) {

                final event = _events[i];

                return Card(

                  child: Padding(

                    padding: const EdgeInsets.all(16),

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        Text(event.title, style: Theme.of(context).textTheme.titleMedium),

                        const SizedBox(height: 12),

                        Row(

                          children: [

                            const Icon(Icons.sentiment_very_dissatisfied, color: Colors.red),

                            Expanded(

                              child: Slider(

                                min: -100,

                                max: 100,

                                divisions: 200,

                                value: event.rating.clamp(-100, 100),

                                label: event.rating.round().toString(),

                                onChanged: (v) {

                                  setState(() {

                                    _events[i] = event.copyWith(rating: v);

                                  });

                                },

                              ),

                            ),

                            const Icon(Icons.sentiment_very_satisfied, color: Colors.green),

                          ],

                        ),

                        Center(

                          child: Text(

                            event.rating >= 0

                                ? '+${event.rating.toStringAsFixed(1)}'

                                : event.rating.toStringAsFixed(1),

                            style: Theme.of(context).textTheme.titleLarge!.copyWith(

                                  color: event.rating >= 0 ? Colors.green[700] : Colors.red[700],

                                ),

                          ),

                        ),

                      ],

                    ),

                  ),

                );

              },

            ),

          ),

          Padding(

            padding: const EdgeInsets.all(16),

            child: ElevatedButton(

              onPressed: _save,

              child: const Text('Сохранить калибровку'),

            ),

          ),

        ],

      ),

    );

  }

}

// ========================

// Добавление события

// ========================

class AddEventPage extends StatefulWidget {

  final double scale;

  const AddEventPage({super.key, required this.scale});

  @override

  State<AddEventPage> createState() => _AddEventPageState();

}

class _AddEventPageState extends State<AddEventPage> {

  final _titleController = TextEditingController();

  double _rating = 0;

  Future<void> _save() async {

    if (_titleController.text.trim().isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Введите название события')),

      );

      return;

    }

    final event = DailyEvent(

      id: const Uuid().v4(),

      date: DateTime.now(),

      title: _titleController.text.trim(),

      rating: _rating,

    );

    await HappinessRepository().addDailyEvent(event);

    if (mounted) {

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Событие сохранено')),

      );

    }

  }

  @override

  Widget build(BuildContext context) {

    final scale = widget.scale;

    return Scaffold(

      appBar: AppBar(title: const Text('Новое событие')),

      body: Padding(

        padding: const EdgeInsets.all(16),

        child: Column(

          children: [

            TextField(

              'Оцените событие по вашей текущей шкале',

              style: Theme.of(context).textTheme.titleMedium,

            ),

            const SizedBox(height: 8),

            Text('Диапазон: ±${scale.toStringAsFixed(1)}'),

            const SizedBox(height: 20),

            TextField(

              controller: _titleController,

              decoration: const InputDecoration(

                labelText: 'Что произошло?',

                border: OutlineInputBorder(),

              ),

              maxLines: 2,

            ),

            const SizedBox(height: 30),

            Text(

              _rating >= 0 ? '+${_rating.toStringAsFixed(1)}' : _rating.toStringAsFixed(1),

              style: Theme.of(context).textTheme.headlineMedium!.copyWith(

                    color: _rating >= 0 ? Colors.green[700] : Colors.red[700],

                  ),

            ),

            Slider(

              min: -scale,

              max: scale,

              divisions: (scale * 2).round().clamp(20, 400),

              value: _rating,

              onChanged: (v) => setState(() => _rating = v),

            ),

            const Spacer(),

            SizedBox(

              width: double.infinity,

              child: ElevatedButton(

                onPressed: _save,

                child: const Padding(

                  padding: EdgeInsets.symmetric(vertical: 16),

                  child: Text('Сохранить событие'),

                ),

              ),

            ),

          ],

        ),

      ),

    );

  }

}

// ========================

// Статистика с красивым графиком

// ========================

class StatsPage extends StatefulWidget {

  const StatsPage({super.key});

  @override

  State<StatsPage> createState() => _StatsPageState();

}

class _StatsPageState extends State<StatsPage> {

  List<DailyEvent> _events = [];

  @override

  void initState() {

    super.initState();

    _loadEvents();

  }

  Future<void> _loadEvents() async {

    final events = await HappinessRepository().getDailyEvents();

    setState(() => _events = events);

  }

  List<FlSpot> _buildCumulativeSpots() {

    if (_events.isEmpty) return [];

    final Map<String, double> dailySums = {};

    for (final e in _events) {

      final dayKey =

          DateFormat('yyyy-MM-dd').format(DateTime(e.date.year, e.date.month, e.date.day));

      dailySums[dayKey] = (dailySums[dayKey] ?? 0) + e.rating;

    }

    final sortedDays = dailySums.keys.toList()..sort();

    double cumulative = 0;

    return sortedDays.asMap().entries.map((entry) {

      cumulative += dailySums[entry.value]!;

      return FlSpot(entry.key.toDouble(), cumulative);

    }).toList();

  }

  double _calculateAverageHappiness() {

    final spots = _buildCumulativeSpots();

    if (spots.isEmpty) return 0;

    return spots.map((s) => s.y).reduce((a, b) => a + b) / spots.length;

  }

  @override

  Widget build(BuildContext context) {

    final spots = _buildCumulativeSpots();

    final avg = _calculateAverageHappiness();

    final dateFormat = DateFormat('dd.MM');

    return Scaffold(

      appBar: AppBar(title: const Text('Статистика')),

      body: _events.isEmpty

          ? const Center(child: Text('Пока нет событий'))

          : ListView(

              padding: const EdgeInsets.all(16),

              children: [

                Card(

                  child: Padding(

                    padding: const EdgeInsets.all(16),

                    child: Column(

                      children: [

                        Text('Кумулятивное счастье',

                            style: Theme.of(context).textTheme.titleLarge),

                        const SizedBox(height: 20),

                        SizedBox(

                          height: 300,

                          child: LineChart(

                            LineChartData(

                              gridData: const FlGridData(show: true),

                              titlesData: FlTitlesData(

                                bottomTitles: AxisTitles(

                                  sideTitles: SideTitles(

                                    showTitles: true,

                                    reservedSize: 30,

                                    interval: (spots.length / 6).ceilToDouble(),

                                    getTitlesWidget: (value, meta) {

                                      final index = value.toInt();

                                      if (index < 0 || index >= spots.length) return const Text('');

                                      final date = DateTime.now().subtract(

                                          Duration(days: spots.length - 1 - index));

                                      return SideTitleWidget(

                                        axisSide: meta.axisSide,

                                        child: Text(dateFormat.format(date)),

                                      );

                                    },

                                  ),

                                ),

                                leftTitles: const AxisTitles(

                                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),

                                ),

                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),

                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),

                              ),

                              borderData: FlBorderData(show: true),

                              lineBarsData: [

                                LineChartBarData(

                                  spots: spots,

                                  isCurved: true,

                                  color: Colors.indigo,

                                  barWidth: 3,

                                  dotData: const FlDotData(show: true),

                                  belowBarData: BarAreaData(

                                    show: true,

                                    color: Colors.indigo.withOpacity(0.1),

                                  ),

                                ),

                              ],

                              lineTouchData: LineTouchData(

                                touchTooltipData: LineTouchTooltipData(

                                  getTooltipItems: (touchedSpots) {

                                    return touchedSpots.map((spot) {

                                      final date = DateTime.now().subtract(

                                          Duration(days: spots.length - 1 - spot.x.toInt()));

                                      return LineTooltipItem(

                                        '${dateFormat.format(date)}\n${spot.y.toStringAsFixed(1)}',

                                        const TextStyle(color: Colors.white),

                                      );

                                    }).toList();

                                  },

                                ),

                              ),

                            ),

                          ),

                        ),

                      ],

                    ),

                  ),

                ),

                const SizedBox(height: 16),

                Card(

                  child: Padding(

                    padding: const EdgeInsets.all(16),

                    child: Row(

                      mainAxisAlignment: MainAxisAlignment.spaceAround,

                      children: [

                        Column(

                          children: [

                            Text('Средний уровень',

                                style: Theme.of(context).textTheme.titleMedium),

                            Text(avg.toStringAsFixed(2),

                                style: TextStyle(

                                    fontSize: 32,

                                    fontWeight: FontWeight.bold,

                                    color: avg >= 0 ? Colors.green[700] : Colors.red[700])),

                          ],

                        ),

                        Column(

                          children: [

                            const Text('Всего событий'),

                            Text('${_events.length}',

                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),

                          ],

                        ),

                      ],

                    ),

                  ),

                ),

                const SizedBox(height: 16),

                Text('История событий',

                    style: Theme.of(context).textTheme.titleMedium),

                const SizedBox(height: 8),

                ..._events.reversed.map((e) => Card(

                      child: ListTile(

                        leading: Icon(

                          e.rating >= 0 ? Icons.sentiment_satisfied : Icons.sentiment_dissatisfied,

                          color: e.rating >= 0 ? Colors.green : Colors.red,

                        ),

                        title: Text(e.title),

                        subtitle: Text(DateFormat('dd MMMM yyyy, HH:mm').format(e.date)),

                        trailing: Text(

                          e.rating >= 0 ? '+${e.rating.toStringAsFixed(1)}' : e.rating.toStringAsFixed(1),

                          style: TextStyle(

                            fontWeight: FontWeight.bold,

                            color: e.rating >= 0 ? Colors.green[700] : Colors.red[700],

                          ),

                        ),

                      ),

                    )),

              ],

            ),

    );

  }

}
