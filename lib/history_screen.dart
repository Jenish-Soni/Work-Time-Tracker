import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<DailyLog>> _logs = {};
  final Duration _targetDuration = const Duration(hours: 8, minutes: 30);

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logsList = await DatabaseHelper.instance.readAllLogs();
    final Map<DateTime, List<DailyLog>> logsMap = {};

    for (var log in logsList) {
      // Assuming date format is dd-EEE-yyyy from HomeScreen
      // We need to parse it carefully or rely on the timestamp if available?
      // Actually, the log.date string is just for display.
      // Better to rely on punchIn timestamp for accurate date grouping.
      final date = DateTime.fromMillisecondsSinceEpoch(log.punchIn);
      final normalizedDate = DateTime(date.year, date.month, date.day);

      if (logsMap[normalizedDate] == null) {
        logsMap[normalizedDate] = [];
      }
      logsMap[normalizedDate]!.add(log);
    }

    setState(() {
      _logs = logsMap;
    });
  }

  List<DailyLog> _getLogsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _logs[normalizedDay] ?? [];
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  String _formatTime(int millis) {
    return DateFormat(
      'hh:mm a',
    ).format(DateTime.fromMillisecondsSinceEpoch(millis));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: TextStyle(color: Colors.white),
              weekendTextStyle: TextStyle(color: Colors.white70),
              todayDecoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 18),
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                return _buildCalendarCell(day);
              },
              selectedBuilder: (context, day, focusedDay) {
                return _buildCalendarCell(day, isSelected: true);
              },
              todayBuilder: (context, day, focusedDay) {
                return _buildCalendarCell(day, isToday: true);
              },
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: _buildDetailsSection(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCell(
    DateTime day, {
    bool isSelected = false,
    bool isToday = false,
  }) {
    final logs = _getLogsForDay(day);
    Color? bgColor;
    Color textColor = Colors.white;

    if (logs.isNotEmpty) {
      final totalSeconds = logs.fold<int>(0, (sum, log) => sum + log.duration);
      final duration = Duration(seconds: totalSeconds);

      if (duration >= _targetDuration) {
        bgColor = Colors.greenAccent.withOpacity(0.8);
        textColor = Colors.black;
      } else {
        bgColor = Colors.redAccent.withOpacity(0.8);
        textColor = Colors.white;
      }
    } else if (isToday) {
      bgColor = Colors.blueAccent;
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDetailsSection() {
    if (_selectedDay == null) {
      return const Center(
        child: Text(
          'Select a date to view details',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final logs = _getLogsForDay(_selectedDay!);

    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('dd-EEE-yyyy').format(_selectedDay!),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Icon(Icons.event_busy, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No records found for this day',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final totalSeconds = logs.fold<int>(0, (sum, log) => sum + log.duration);
    final totalDuration = Duration(seconds: totalSeconds);
    final isGoalMet = totalDuration >= _targetDuration;

    // Calculate Break Time
    int totalBreakMillis = 0;
    // Ensure logs are sorted by punchIn time
    logs.sort((a, b) => a.punchIn.compareTo(b.punchIn));

    for (int i = 1; i < logs.length; i++) {
      final previousPunchOut = logs[i - 1].punchOut;
      final currentPunchIn = logs[i].punchIn;
      // Only count if on same day (already filtered by day, but good to be safe)
      // and currentPunchIn > previousPunchOut
      if (currentPunchIn > previousPunchOut) {
        totalBreakMillis += (currentPunchIn - previousPunchOut);
      }
    }
    final totalBreakDuration = Duration(milliseconds: totalBreakMillis);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text(
          DateFormat('dd-EEE-yyyy').format(_selectedDay!),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),

        // Total Duration Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isGoalMet
                ? Colors.greenAccent.withOpacity(0.1)
                : Colors.redAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isGoalMet
                  ? Colors.greenAccent.withOpacity(0.3)
                  : Colors.redAccent.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Duration',
                    style: TextStyle(
                      color: isGoalMet ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDuration(totalDuration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Icon(
                isGoalMet ? Icons.check_circle : Icons.warning_amber_rounded,
                color: isGoalMet ? Colors.greenAccent : Colors.redAccent,
                size: 40,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Break Time Card
        if (totalBreakDuration.inMinutes > 0) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Break Time',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDuration(totalBreakDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.coffee, color: Colors.orangeAccent, size: 28),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ] else
          const SizedBox(height: 24),

        const Text(
          'Sessions',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Sessions List
        ...logs.map((log) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.login, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(log.punchIn),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.logout, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(log.punchOut),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  _formatDuration(Duration(seconds: log.duration)),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
