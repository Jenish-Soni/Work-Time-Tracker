import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Get current punch in time from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final punchInMillis = prefs.getInt('punchInTime');
      final punchOutMillis = prefs.getInt('punchOutTime');

      if (punchInMillis != null && punchOutMillis == null) {
        // User is currently punched in, calculate duration
        final punchInTime = DateTime.fromMillisecondsSinceEpoch(punchInMillis);
        final now = DateTime.now();
        final duration = now.difference(punchInTime);

        String formatDuration(Duration d) {
          String twoDigits(int n) => n.toString().padLeft(2, '0');
          final hours = twoDigits(d.inHours);
          final minutes = twoDigits(d.inMinutes.remainder(60));
          final seconds = twoDigits(d.inSeconds.remainder(60));
          return '$hours:$minutes:$seconds';
        }

        // Update widget data
        await HomeWidget.saveWidgetData<String>('status', 'Working');
        await HomeWidget.saveWidgetData<String>(
          'duration',
          formatDuration(duration),
        );
        await HomeWidget.updateWidget(androidName: 'TimeTrackerWidget');
      }
    } catch (e) {
      print('Error in background task: $e');
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize WorkManager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  // Register periodic task to update widget every 15 minutes
  await Workmanager().registerPeriodicTask(
    'widget_update_task',
    'widgetUpdate',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.notRequired),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Time Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}
