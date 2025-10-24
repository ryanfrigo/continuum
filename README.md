# Continuum

A beautiful, minimalist iOS habit tracking app built with SwiftUI and SwiftData. Track your daily habits with visual progress indicators and streak counters.

## Features

### 🎯 **Habit Tracking**
- Create and manage multiple habits
- Visual 66-day progress grid (6 rows × 11 columns)
- Daily completion tracking with tap-to-toggle
- Streak counting with intelligent display logic

### 🎨 **Beautiful Design**
- Dark theme with orange accent colors
- Gradient color progression based on streak length:
  - **Orange** (0-66 days): Building the habit
  - **Green** (66+ days): Habit formation complete
  - **Blue** (100+ days): Mastery level
- Monospaced typography for clean, technical aesthetic
- Smooth animations and haptic feedback

### 📊 **Progress Visualization**
- 66-day completion grid showing recent history
- Real-time streak counter
- Color-coded progress indicators
- "Start today" prompt for new habits

### ⚙️ **Habit Management**
- Rename habits with long-press context menu
- Adjust streak counts manually
- Reset progress when needed
- Delete habits with confirmation

### 🔄 **Smart Updates**
- Automatic refresh when app becomes active
- Real-time streak calculations
- Persistent data storage with SwiftData

## Screenshots

The app features a clean, dark interface with:
- Welcome screen for first-time users
- Grid layout for multiple habits
- Individual habit cards with progress visualization
- Context menus for habit management

## Technical Details

### Architecture
- **SwiftUI** for declarative UI
- **SwiftData** for data persistence
- **MVVM** pattern with `@Observable` models
- **Swift Package Manager** for dependencies

### Key Components
- `Habit` model with streak calculation logic
- `HabitCardView` for individual habit display
- `AddHabitSheet` for habit creation
- `ContentView` as the main interface

### Data Model
```swift
@Model
final class Habit {
    var id: UUID
    var name: String
    var createdAt: Date
    var completedDates: [Date]
}
```

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/continuum.git
```

2. Open `continuum.xcodeproj` in Xcode

3. Build and run on your device or simulator

## Usage

### Creating a Habit
1. Tap the "+" button in the top-right corner
2. Enter a habit name
3. Tap "Save"

### Tracking Progress
1. Tap any habit card to mark it complete for today
2. Tap again to unmark if needed
3. View your streak count and progress grid

### Managing Habits
- **Long-press** any habit card to access options:
  - Change name
  - Adjust streak count
  - Reset progress
  - Delete habit

## Development

### Project Structure
```
continuum/
├── Models/
│   └── Habit.swift          # Data model
├── Views/
│   ├── ContentView.swift    # Main interface
│   ├── HabitCardView.swift  # Individual habit display
│   └── AddHabitSheet.swift  # Habit creation
├── Assets.xcassets/         # App icons and assets
└── continuumApp.swift       # App entry point
```

### Key Features Implementation

#### Streak Calculation
The app uses a sophisticated streak calculation that:
- Counts consecutive completed days
- Handles timezone changes correctly
- Shows appropriate streak text based on completion status

#### Visual Design
- Color progression based on habit formation science (66 days)
- Responsive grid layout for progress visualization
- Smooth animations and haptic feedback

#### Data Persistence
- SwiftData for automatic Core Data integration
- Unique habit IDs to prevent duplicates
- Efficient date storage and retrieval

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by habit formation research and the 66-day rule
- Built with modern SwiftUI and SwiftData technologies
- Designed for simplicity and effectiveness

---

**Continuum** - Build better habits, one day at a time.
