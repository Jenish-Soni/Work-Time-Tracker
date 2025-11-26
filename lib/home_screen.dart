import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'database_helper.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime? _punchInTime;
  DateTime? _punchOutTime;
  Duration _workedDuration = Duration.zero;
  final Duration _targetDuration = const Duration(hours: 8, minutes: 30);
  Timer? _timer;
  List<DailyLog> _historyLogs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _loadHistory();
    // Delay widget action check to ensure app is fully initialized
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkWidgetAction();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkWidgetAction();
      _updateWidget(); // Update widget when app resumes
    } else if (state == AppLifecycleState.paused) {
      _updateWidget(); // Update widget when app goes to background
    }
  }

  Future<void> _checkWidgetAction() async {
    final action = await HomeWidget.getWidgetData<String>('widget_action');
    if (action != null) {
      await HomeWidget.saveWidgetData<String>('widget_action', null);

      if (action == 'punch_in' &&
          (_punchInTime == null || _punchOutTime != null)) {
        await _punchIn();
      } else if (action == 'punch_out' &&
          _punchInTime != null &&
          _punchOutTime == null) {
        await _punchOut();
      }
    }
  }

  Future<void> _loadHistory() async {
    final logs = await DatabaseHelper.instance.readAllLogs();
    setState(() {
      _historyLogs = logs;
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final punchInMillis = prefs.getInt('punchInTime');
    final punchOutMillis = prefs.getInt('punchOutTime');

    setState(() {
      if (punchInMillis != null) {
        _punchInTime = DateTime.fromMillisecondsSinceEpoch(punchInMillis);
      }
      if (punchOutMillis != null) {
        _punchOutTime = DateTime.fromMillisecondsSinceEpoch(punchOutMillis);
      }
      _calculateDuration();
    });

    if (_punchInTime != null && _punchOutTime == null) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    int tickCount = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateDuration();
        });
        // Update widget every 60 seconds (1 minute) to save battery
        tickCount++;
        if (tickCount >= 60) {
          _updateWidget();
          tickCount = 0;
        }
      }
    });
  }

  Future<void> _punchIn() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('punchInTime', now.millisecondsSinceEpoch);
    await prefs.remove('punchOutTime');

    setState(() {
      _punchInTime = now;
      _punchOutTime = null;
      _workedDuration = Duration.zero;
    });
    _startTimer();
    _updateWidget();
  }

  Future<void> _punchOut() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('punchOutTime', now.millisecondsSinceEpoch);

    setState(() {
      _punchOutTime = now;
    });
    _timer?.cancel();
    _calculateDuration();

    // Save to DB
    if (_punchInTime != null) {
      final log = DailyLog(
        date: DateFormat('dd-EEE-yyyy').format(_punchInTime!),
        punchIn: _punchInTime!.millisecondsSinceEpoch,
        punchOut: now.millisecondsSinceEpoch,
        duration: _workedDuration.inSeconds,
      );
      await DatabaseHelper.instance.create(log);
      _loadHistory();
    }
    _updateWidget();
  }

  void _calculateDuration() {
    if (_punchInTime == null) {
      _workedDuration = Duration.zero;
      return;
    }

    final endTime = _punchOutTime ?? DateTime.now();
    _workedDuration = endTime.difference(_punchInTime!);
  }

  Future<void> _reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('punchInTime');
    await prefs.remove('punchOutTime');
    _timer?.cancel();

    setState(() {
      _punchInTime = null;
      _punchOutTime = null;
      _workedDuration = Duration.zero;
    });
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '--:--';
    return DateFormat('hh:mm a').format(time);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Future<void> _updateWidget() async {
    final status = _punchInTime != null && _punchOutTime == null
        ? 'Working'
        : 'Paused';
    final duration = _formatDuration(_workedDuration);

    await HomeWidget.saveWidgetData<String>('status', status);
    await HomeWidget.saveWidgetData<String>('duration', duration);
    await HomeWidget.updateWidget(androidName: 'TimeTrackerWidget');
  }

  @override
  Widget build(BuildContext context) {
    final isGoalReached = _workedDuration >= _targetDuration;
    final progress = _workedDuration.inMinutes / _targetDuration.inMinutes;

    DateTime? expectedPunchOut;
    if (_punchInTime != null) {
      expectedPunchOut = _punchInTime!.add(_targetDuration);
    }

    // Calculate Today's Break Time
    int totalBreakMillis = 0;
    final today = DateTime.now();
    final todayLogs = _historyLogs.where((log) {
      final logDate = DateTime.fromMillisecondsSinceEpoch(log.punchIn);
      return logDate.year == today.year &&
          logDate.month == today.month &&
          logDate.day == today.day;
    }).toList();

    // Sort logs by punchIn just in case
    todayLogs.sort((a, b) => a.punchIn.compareTo(b.punchIn));

    for (int i = 1; i < todayLogs.length; i++) {
      final previousPunchOut = todayLogs[i - 1].punchOut;
      final currentPunchIn = todayLogs[i].punchIn;
      if (currentPunchIn > previousPunchOut) {
        totalBreakMillis += (currentPunchIn - previousPunchOut);
      }
    }

    // If currently punched in, add break from last punch out
    if (_punchInTime != null && todayLogs.isNotEmpty) {
      final lastPunchOut = todayLogs.last.punchOut;
      final currentPunchIn = _punchInTime!.millisecondsSinceEpoch;
      if (currentPunchIn > lastPunchOut) {
        totalBreakMillis += (currentPunchIn - lastPunchOut);
      }
    }

    final totalBreakDuration = Duration(milliseconds: totalBreakMillis);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Work Timer'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
            tooltip: 'History',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: 'Reset Day',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Goal Indicator
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: CircularProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          strokeWidth: 12,
                          backgroundColor: Colors.grey[800],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isGoalReached
                                ? Colors.greenAccent
                                : Colors.blueAccent,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatDuration(_workedDuration),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Goal: 08:30:00',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Info Cards Row (Expected Punch Out & Break Time)
                  Row(
                    children: [
                      // Expected Punch Out
                      if (_punchInTime != null && _punchOutTime == null)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.blueAccent.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Expected Out',
                                  style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(expectedPunchOut),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (_punchInTime != null &&
                          _punchOutTime == null &&
                          totalBreakDuration.inMinutes > 0)
                        const SizedBox(width: 16),

                      // Break Time
                      if (totalBreakDuration.inMinutes > 0)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.orangeAccent.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Break Time',
                                  style: TextStyle(
                                    color: Colors.orangeAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDuration(totalBreakDuration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Times Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTimeCard(
                        'Punch In',
                        _formatTime(_punchInTime),
                        Icons.login,
                      ),
                      _buildTimeCard(
                        'Punch Out',
                        _formatTime(_punchOutTime),
                        Icons.logout,
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Action Buttons
                  if (_punchInTime == null || _punchOutTime != null)
                    _buildActionButton(
                      label: 'PUNCH IN',
                      color: Colors.greenAccent,
                      textColor: Colors.black,
                      icon: Icons.play_arrow,
                      onPressed: _punchIn,
                    )
                  else
                    _buildActionButton(
                      label: 'PUNCH OUT',
                      color: Colors.redAccent,
                      textColor: Colors.white,
                      icon: Icons.stop,
                      onPressed: _punchOut,
                    ),
                ],
              ),
            ),
          ),
          // History List
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Recent History',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: _historyLogs.isEmpty
                      ? Center(
                          child: Text(
                            'No records yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _historyLogs.length,
                          itemBuilder: (context, index) {
                            final log = _historyLogs[index];
                            final duration = Duration(seconds: log.duration);
                            final isGoalMet = duration >= _targetDuration;

                            return ListTile(
                              leading: Icon(
                                isGoalMet
                                    ? Icons.check_circle
                                    : Icons.warning_amber_rounded,
                                color: isGoalMet
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                              ),
                              title: Text(
                                log.date,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                '${_formatTime(DateTime.fromMillisecondsSinceEpoch(log.punchIn))} - ${_formatTime(DateTime.fromMillisecondsSinceEpoch(log.punchOut))}',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                              trailing: Text(
                                _formatDuration(duration),
                                style: TextStyle(
                                  color: isGoalMet
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard(String label, String time, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required Color textColor,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
