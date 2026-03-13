import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vibration/vibration.dart';

void main() {
  runApp(const VnsApp());
}

class VnsApp extends StatelessWidget {
  const VnsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VNS Vibration Controller',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D4FF),
          secondary: Color(0xFF7C3AED),
          surface: Color(0xFF111827),
          error: Color(0xFFEF4444),
        ),
      ),
      home: const VnsHomePage(),
    );
  }
}

class PatternDefinition {
  const PatternDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.hz,
    required this.onMs,
    required this.offMs,
    this.badge,
    this.pulsed = false,
    this.modHz,
  });

  final String id;
  final String name;
  final String description;
  final int hz;
  final int onMs;
  final int offMs;
  final String? badge;
  final bool pulsed;
  final int? modHz;
}

class LogEntry {
  const LogEntry({required this.timestamp, required this.message, required this.type});

  final DateTime timestamp;
  final String message;
  final String type;
}

class VnsHomePage extends StatefulWidget {
  const VnsHomePage({super.key});

  @override
  State<VnsHomePage> createState() => _VnsHomePageState();
}

class _VnsHomePageState extends State<VnsHomePage> {
  static const _androidChannel = MethodChannel('flutter_vns_app/downloads');

  static const List<PatternDefinition> _patterns = [
    PatternDefinition(
      id: 'control',
      name: 'Control',
      description: 'No vibration · Baseline reference',
      hz: 0,
      onMs: 0,
      offMs: 0,
      badge: 'SHAM',
    ),
    PatternDefinition(
      id: 'low',
      name: 'Low Frequency',
      description: '50 Hz · 2s ON / 3s OFF',
      hz: 50,
      onMs: 2000,
      offMs: 3000,
    ),
    PatternDefinition(
      id: 'medium',
      name: 'Medium Frequency',
      description: '100 Hz · 2s ON / 3s OFF',
      hz: 100,
      onMs: 2000,
      offMs: 3000,
    ),
    PatternDefinition(
      id: 'high',
      name: 'High Frequency',
      description: '150 Hz · 2s ON / 3s OFF',
      hz: 150,
      onMs: 2000,
      offMs: 3000,
    ),
    PatternDefinition(
      id: 'pulsed',
      name: 'Pulsed Pattern',
      description: '100 Hz @ 20 Hz modulation · taVNS-like',
      hz: 100,
      onMs: 2000,
      offMs: 3000,
      badge: 'taVNS',
      pulsed: true,
      modHz: 20,
    ),
  ];

  String? _selectedPatternId;
  int _selectedDurationMins = 20;
  bool _sessionActive = false;
  bool _isVibrating = false;
  bool _deviceSupportsVibration = false;
  int _cycleCount = 0;
  int _elapsedSeconds = 0;
  int _totalSeconds = 0;
  DateTime? _sessionStart;
  Timer? _sessionTimer;
  Timer? _phaseTimer;
  final List<LogEntry> _logEntries = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final support = await Vibration.hasVibrator() ?? false;
    setState(() {
      _deviceSupportsVibration = support;
    });
    _addLog('System ready. Select a pattern to begin.', 'info');
    if (!support) {
      _addLog('Warning: vibration hardware not detected on this device.', 'warn');
    }
  }

  PatternDefinition? get _selectedPattern {
    for (final pattern in _patterns) {
      if (pattern.id == _selectedPatternId) return pattern;
    }
    return null;
  }

  void _addLog(String message, String type) {
    setState(() {
      _logEntries.add(LogEntry(timestamp: DateTime.now(), message: message, type: type));
    });
  }

  Future<void> _startSession() async {
    if (_selectedPattern == null) {
      _showSnack('Please select a stimulation pattern.');
      return;
    }

    setState(() {
      _sessionActive = true;
      _sessionStart = DateTime.now();
      _elapsedSeconds = 0;
      _totalSeconds = _selectedDurationMins * 60;
      _cycleCount = 0;
    });

    _addLog(
      'Session started · ${_selectedPattern!.name} · $_selectedDurationMins min',
      'info',
    );

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds += 1;
      });
      if (_elapsedSeconds >= _totalSeconds) {
        _completeSession();
      }
    });

    _runCycle();
  }

  Future<void> _runCycle() async {
    if (!_sessionActive || _selectedPattern == null) return;
    final pattern = _selectedPattern!;

    if (pattern.hz == 0) {
      setState(() {
        _isVibrating = false;
      });
      return;
    }

    setState(() {
      _isVibrating = true;
      _cycleCount += 1;
    });
    _addLog('Cycle $_cycleCount: ON (${pattern.name})', 'info');
    await _startVibration(pattern);

    _phaseTimer = Timer(Duration(milliseconds: pattern.onMs), () async {
      await _stopVibration();
      if (!mounted) return;
      setState(() {
        _isVibrating = false;
      });
      _addLog('Cycle $_cycleCount: OFF', 'default');

      _phaseTimer = Timer(Duration(milliseconds: pattern.offMs), () {
        if (_sessionActive) {
          _runCycle();
        }
      });
    });
  }

  Future<void> _startVibration(PatternDefinition pattern) async {
    if (!_deviceSupportsVibration || pattern.hz == 0) return;

    if (pattern.pulsed && pattern.modHz != null) {
      final burstHalf = (1000 / pattern.modHz! / 2).round().clamp(5, 1000);
      final sequence = <int>[];
      var elapsed = 0;
      while (elapsed < pattern.onMs) {
        sequence.addAll([0, burstHalf, burstHalf]);
        elapsed += burstHalf * 2;
      }
      await Vibration.vibrate(pattern: sequence, repeat: -1);
      return;
    }

    final halfPeriod = (1000 / pattern.hz / 2).round().clamp(5, 1000);
    final sequence = <int>[];
    var elapsed = 0;
    while (elapsed < pattern.onMs) {
      sequence.addAll([0, halfPeriod, halfPeriod]);
      elapsed += halfPeriod * 2;
    }
    await Vibration.vibrate(pattern: sequence, repeat: -1);
  }

  Future<void> _stopVibration() async {
    await Vibration.cancel();
  }

  Future<void> _stopSession({bool completed = false}) async {
    _sessionTimer?.cancel();
    _phaseTimer?.cancel();
    await _stopVibration();

    if (!mounted) return;
    setState(() {
      _sessionActive = false;
      _isVibrating = false;
    });

    _addLog(
      completed ? 'Session complete ✓' : 'Session ended · $_cycleCount cycles completed',
      completed ? 'info' : 'stop',
    );
  }

  Future<void> _completeSession() async {
    await _stopSession(completed: true);
  }

  String _fmt(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _buildCsv() {
    final pattern = _selectedPattern;
    final buffer = StringBuffer();
    buffer.writeln('timestamp,type,message,pattern,duration_minutes,cycle_count');
    for (final entry in _logEntries) {
      final ts = DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.timestamp);
      final safeMessage = entry.message.replaceAll(',', ';');
      buffer.writeln(
        '$ts,${entry.type},$safeMessage,${pattern?.name ?? ''},$_selectedDurationMins,$_cycleCount',
      );
    }
    return buffer.toString();
  }

  Future<void> _exportLogsToDownloads() async {
    try {
      final fileName =
          'vns_session_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final result = await _androidChannel.invokeMethod<String>('saveCsvToDownloads', {
        'fileName': fileName,
        'mimeType': 'text/csv',
        'content': _buildCsv(),
      });
      _showSnack(result ?? 'Saved to Downloads');
      _addLog('Exported log to Downloads', 'info');
    } on PlatformException catch (e) {
      _showSnack('Export failed: ${e.message}');
      _addLog('Export failed: ${e.message}', 'warn');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _phaseTimer?.cancel();
    Vibration.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedPattern = _selectedPattern;
    final remaining = (_totalSeconds - _elapsedSeconds).clamp(0, _totalSeconds);
    final progress = _totalSeconds == 0 ? 0.0 : _elapsedSeconds / _totalSeconds;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VNS Vibration Controller'),
            Text(
              'CS-8803 · Health Sensing & Interventions',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _noticeCard(),
              const SizedBox(height: 20),
              _sectionLabel('Stimulation Pattern'),
              ..._patterns.map((pattern) => _patternCard(pattern)).toList(),
              const SizedBox(height: 24),
              _sectionLabel('Session Duration'),
              Row(
                children: [5, 20, 30]
                    .map(
                      (mins) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _durationButton(mins),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _sessionActive ? const Color(0xFFEF4444) : const Color(0xFF00D4FF),
                    foregroundColor: _sessionActive ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _sessionActive ? () => _stopSession() : _startSession,
                  child: Text(_sessionActive ? '■ STOP' : '▶ START SESSION'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logEntries.isEmpty ? null : _exportLogsToDownloads,
                  icon: const Icon(Icons.download),
                  label: const Text('Export Session Log to Downloads'),
                ),
              ),
              const SizedBox(height: 20),
              if (_sessionActive || _elapsedSeconds > 0) _statusPanel(remaining, progress),
              const SizedBox(height: 20),
              _sectionLabel('Session Log'),
              _logBox(),
              const SizedBox(height: 16),
              Text(
                _deviceSupportsVibration
                    ? '✓ Vibration hardware detected on this device.'
                    : '⚠ Vibration hardware not detected on this device.',
                style: TextStyle(
                  fontSize: 12,
                  color: _deviceSupportsVibration ? const Color(0xFF64748B) : const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                selectedPattern == null
                    ? 'Select a pattern to begin.'
                    : 'Selected: ${selectedPattern.name}. Note: phone motors do not produce true calibrated 50/100/150 Hz output; this app emulates burst patterns like the original HTML.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noticeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(245, 158, 11, 0.10),
        border: Border.all(color: const Color.fromRGBO(245, 158, 11, 0.30)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '⚠ Research Use Only. Place phone on left anterior neck or upper sternum. Ensure participant meets inclusion criteria before proceeding.',
        style: TextStyle(fontSize: 13, color: Color(0xFFF59E0B), height: 1.5),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.8,
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _patternCard(PatternDefinition pattern) {
    final selected = _selectedPatternId == pattern.id;
    return GestureDetector(
      onTap: _sessionActive
          ? null
          : () {
              setState(() => _selectedPatternId = pattern.id);
              _addLog('Pattern selected: ${pattern.name}', 'default');
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? const Color.fromRGBO(0, 212, 255, 0.07)
              : const Color(0xFF111827),
          border: Border.all(
            color: selected ? const Color(0xFF00D4FF) : const Color(0xFF1E2D45),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xFF00D4FF) : Colors.transparent,
                border: Border.all(
                  color: selected ? const Color(0xFF00D4FF) : const Color(0xFF64748B),
                  width: 2,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pattern.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    pattern.description,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            if (pattern.badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(124, 58, 237, 0.2),
                  border: Border.all(color: const Color.fromRGBO(124, 58, 237, 0.3)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pattern.badge!,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFA78BFA)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _durationButton(int mins) {
    final selected = _selectedDurationMins == mins;
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        backgroundColor: selected
            ? const Color.fromRGBO(124, 58, 237, 0.15)
            : const Color(0xFF111827),
        foregroundColor: selected ? const Color(0xFFA78BFA) : Colors.white,
        side: BorderSide(
          color: selected ? const Color(0xFF7C3AED) : const Color(0xFF1E2D45),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: _sessionActive ? null : () => setState(() => _selectedDurationMins = mins),
      child: Text('$mins min'),
    );
  }

  Widget _statusPanel(int remaining, double progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border.all(color: const Color(0xFF1E2D45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _statusRow('Elapsed', _fmt(_elapsedSeconds)),
          _statusRow('Remaining', _fmt(remaining)),
          _statusRow('State', _isVibrating ? 'ON' : (_sessionActive ? 'OFF' : 'STOPPED')),
          _statusRow('Cycle', '$_cycleCount'),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: progress),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF00D4FF))),
        ],
      ),
    );
  }

  Widget _logBox() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border.all(color: const Color(0xFF1E2D45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _logEntries.isEmpty
            ? const [Text('No log entries yet.', style: TextStyle(color: Color(0xFF64748B)))]
            : _logEntries.reversed
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '[${DateFormat('HH:mm:ss').format(entry.timestamp)}] ${entry.message}',
                      style: TextStyle(
                        fontSize: 12,
                        color: switch (entry.type) {
                          'info' => const Color(0xFF00D4FF),
                          'warn' => const Color(0xFFF59E0B),
                          'stop' => const Color(0xFFEF4444),
                          _ => Colors.white,
                        },
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}

