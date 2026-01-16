# RunAm

A Flutter-based errand delivery platform that connects people who need errands done with students who want to earn extra income.  RunAm uses verification, escrow payments, and a trust-score system to ensure safe, reliable, and community-driven errand services.

## Features

- **User Authentication**: Google Sign-In integration for secure authentication
- **Real-time Location**:  Mapbox integration for location tracking and mapping
- **Errand Management**: Post, track, and manage errands with ease
- **Modern UI**: Built with Material 3 design principles and custom theming using Google Fonts
- **State Management**: GetX for efficient state management
- **Routing**: Go Router for declarative navigation

## Tech Stack

- **Framework**: Flutter 3.7.2+
- **State Management**: GetX
- **Authentication**: Google Sign-In
- **Maps & Location**: Mapbox Maps, Geolocator
- **Routing**: Go Router
- **HTTP Client**: http package
- **Icons**: Iconsax Plus
- **Fonts**: Google Fonts (Shantell Sans)
- **Environment Config**: flutter_dotenv

## Project Structure

```
lib/
├── app/
│   ├── app.dart           # Main app widget
│   ├── router.dart        # App routing configuration
│   └── theme.dart         # App theme and colors
├── components/
│   ├── errand_card.dart   # Errand display component
│   ├── onboarding_content.dart
│   └── switch_list_tile.dart
├── controllers/
│   └── auth_controller.dart  # Authentication state management
├── screens/
│   ├── home/
│   ├── onboarding/
│   ├── profile/
│   └── splash/
├── services/
│   └── auth_service.dart  # Authentication API service
└── main.dart              # App entry point
```

## Getting Started

### Prerequisites

- Flutter SDK (^3.7.2)
- Dart SDK
- Android Studio / Xcode for mobile development
- Mapbox account and API token

### Installation

1. Clone the repository: 
```bash
git clone https://github.com/Egbemichel/runam.git
cd runam/src/frontend
```

2. Install dependencies:
```bash
flutter pub get
```

3. Create a `.env` file in the `src/frontend` directory with your Mapbox token:
```
MAPBOX_PUBLIC_TOKEN=your_mapbox_token_here
```

4. Run the app:
```bash
flutter run
```

### Configuration

- **Mapbox Setup**: Add your Mapbox public token to the `.env` file
- **Google Sign-In**: Configure OAuth credentials for your platform (Android/iOS)
- **Backend API**: Update the base URL in `lib/services/auth_service.dart` if needed

## Development

### Running Tests

```bash
flutter test
```

### Building for Production

**Android:**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```

## Key Dependencies

| Package | Purpose |
|---------|---------|
| mapbox_maps_flutter | Interactive maps and location services |
| geolocator | Device location tracking |
| get | State management and dependency injection |
| go_router | Declarative routing |
| google_sign_in | Google authentication |
| http | API communication |
| google_fonts | Custom typography |
| iconsax_plus | Modern icon set |

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Mapbox Flutter SDK](https://docs.mapbox.com/flutter/maps/overview/)
- [GetX Documentation](https://pub.dev/packages/get)
- [Go Router Documentation](https://pub.dev/packages/go_router)

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.