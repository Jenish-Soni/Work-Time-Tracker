# ⏱️ Work Time Tracker

A beautiful Flutter application to track your daily work hours and ensure you meet your 8:30 hours goal. Features a modern dark theme UI with real-time tracking, calendar history, break time monitoring, and an Android home screen widget.

## ✨ Features

### 📊 Core Tracking
- **Punch In/Out System**: Simple one-tap punch in and punch out functionality
- **Live Timer**: Real-time duration tracking with second-by-second updates
- **Goal Visualization**: Circular progress indicator showing progress towards 8:30 hours goal
- **Expected Punch Out**: Automatically calculates when you can leave to meet your goal
- **Multiple Sessions**: Support for breaks - punch in/out multiple times per day

### 📅 History & Analytics
- **Calendar View**: Visual calendar showing your work history
  - 🟢 Green dates: Goal met (≥8:30 hours)
  - 🔴 Red dates: Goal missed (<8:30 hours)
- **Detailed Day View**: Tap any date to see:
  - Total work duration
  - Total break time
  - Individual session breakdown with punch in/out times
- **Recent History**: Quick view of recent work logs on the home screen

### ⏸️ Break Time Tracking
- **Automatic Calculation**: Tracks time between sessions on the same day
- **Visual Display**: Shows total break time on both home screen and history
- **Smart Detection**: Only counts breaks when both punch-out and next punch-in occur on the same day

### 📱 Android Widget
- **Home Screen Widget**: Quick status view without opening the app
- **Interactive Buttons**: Punch in/out directly from the widget
- **Auto-Updates**: Updates every minute while app is running
- **Status Display**: Shows "Working" or "Paused" with current duration

### 💾 Data Persistence
- **Local Database**: All sessions saved using SQLite
- **Offline First**: Works completely offline
- **No Data Loss**: Survives app restarts and device reboots

## 🎨 Design

- **Modern Dark Theme**: Easy on the eyes with vibrant accent colors
- **Color-Coded Status**: 
  - 🟢 Green: Goal achieved
  - 🔴 Red: Goal not met
  - 🔵 Blue: In progress
  - 🟠 Orange: Break time
- **Smooth Animations**: Polished UI with smooth transitions
- **Responsive Layout**: Works on all screen sizes

## 📸 Screenshots

*Add screenshots here*

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio / VS Code
- Android device or emulator (for widget testing)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Jenish-Soni/Work-Time-Tracker.git
   cd Work-Time-Tracker
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Adding the Widget (Android)

1. Long press on your home screen
2. Tap "Widgets"
3. Find "Time Tracker"
4. Drag it to your home screen
5. Tap the widget buttons to punch in/out!

## 📦 Dependencies

- `shared_preferences`: Local data persistence
- `sqflite`: SQLite database for work logs
- `intl`: Date and time formatting
- `table_calendar`: Calendar view implementation
- `home_widget`: Android home screen widget support
- `path`: File path utilities

## 🏗️ Architecture

```
lib/
├── main.dart              # App entry point
├── home_screen.dart       # Main tracking screen
├── history_screen.dart    # Calendar and history view
└── database_helper.dart   # SQLite database operations

android/
└── app/src/main/
    ├── kotlin/
    │   └── TimeTrackerWidget.kt    # Widget provider
    └── res/
        ├── layout/
        │   └── widget_layout.xml   # Widget UI
        └── xml/
            └── widget_info.xml     # Widget configuration
```

## 🎯 How It Works

### Daily Goal
- Target: **8 hours 30 minutes** per day
- Visual feedback when goal is reached
- Historical tracking of goal achievement

### Session Tracking
1. **Punch In**: Records start time, starts live timer
2. **Work**: Timer runs, showing real-time duration
3. **Punch Out**: Records end time, saves to database
4. **Repeat**: Support for multiple sessions (breaks)

### Break Calculation
- Automatically calculates gaps between sessions
- Only counts breaks on the same day
- Displays total break time separately from work time

### Widget Updates
- Updates every 1 minute while app is running
- Updates when app opens/closes
- Shows last known state when app is closed

## 🛠️ Configuration

### Changing Daily Goal
Edit the `_targetDuration` in `home_screen.dart`:
```dart
final Duration _targetDuration = const Duration(hours: 8, minutes: 30);
```

### Date Format
Current format: `dd-EEE-yyyy` (e.g., 26-Wed-2025)

To change, edit the `DateFormat` in `home_screen.dart` and `history_screen.dart`.

## 🐛 Known Limitations

- **Widget Real-Time Updates**: Android widgets cannot update every second (battery conservation). Updates occur every minute while app is running.
- **Background Updates**: When app is completely closed, widget shows last known state until app is reopened.
- **iOS Widget**: Currently only Android widget is implemented.

## 🔮 Future Enhancements

- [ ] iOS widget support
- [ ] Export data to CSV/PDF
- [ ] Weekly/Monthly statistics
- [ ] Customizable work goals
- [ ] Notifications for goal achievement
- [ ] Dark/Light theme toggle
- [ ] Multiple work profiles

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👨‍💻 Author

**Jenish Soni**
- GitHub: [@Jenish-Soni](https://github.com/Jenish-Soni)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Contributors to the open-source packages used in this project

---

Made with ❤️ using Flutter
