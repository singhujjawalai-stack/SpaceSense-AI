# SpaceSense Mobile App - Complete Setup Guide

## 📋 What You're Building

- **Android & iOS** mobile app for interior space optimization
- **AI-powered** room analysis from photos
- **Clean Architecture** with Riverpod for state management
- **Local storage** of analyses and photos
- **Multi-provider** AI support (OpenAI, Anthropic, Google)

## 🗂️ Project Structure

```
mobile/
├── lib/                    # Main application code
│   ├── core/               # Configuration, theme, utilities
│   ├── features/           # Feature modules
│   ├── shared/             # Common widgets and components
│   └── models/             # Data models
│
├── android/                # Android-specific configuration
├── ios/                    # iOS-specific configuration
├── assets/                 # Images, icons, fonts
└── test/                   # Test files
```

## 🚀 Quick Start (5-10 minutes)

### Install Flutter
1. Download Flutter from [flutter.dev](https://flutter.dev)
2. Extract and add to PATH
3. Start Flutter Doctor:
```bash
flutter doctor
```

### Clone Project
```bash
# Clone the starter project
git clone https://github.com/YOUR_USERNAME/spacesense-mobile.git

# Navigate to project
cd spacesense-mobile/mobile

# Get dependencies
flutter pub get
```

### Run First Time
1. **Android Emulator**: `flutter run`
2. **iOS Simulator**: `flutter run --flavor simulator`
3. **Physical Device**: Connect via USB, run `flutter run`

## 📖 Detailed Setup Instructions

### Step 1: Install Dependencies

```bash
# Install all Flutter and Dart dependencies
cd mobile
flutter pub get
```

### Step 2: Configure Environment

**Edit `lib/core/config/env.dart`:**
```dart
// Development environment
class DevelopmentConfig extends Env {
  static const String supabaseUrl = 'https://dev.supabase.co';
  static const String supabaseAnonKey = 'your-dev-key';
  static const String apiBaseUrl = 'http://localhost:8000';
  static const bool debugMode = true;
}

// Production environment
class ProductionConfig extends Env {
  static const String supabaseUrl = 'https://prod.supabase.co';
  static const String supabaseAnonKey = 'your-prod-key';
  static const String apiBaseUrl = 'https://api.spacesense.ai';
  static const bool debugMode = false;
}
```

### Step 3: Set Up Supabase Account

**Full guide:** See `../backend/docs/SUPABASE_SETUP.md`

**Quick steps:**
1. Go to [supabase.com](https://supabase.com) → Sign up
2. Create new project: `spacesense-mobile`
3. Get `Project URL` and `anon public key`
4. Edit `lib/core/config/env.dart` with your credentials

### Step 4: Configure Local Environment

Create `lib/core/config/env.local.dart` (add to .gitignore):

```dart
// lib/core/config/env.local.dart
// Edit this file and add your local Supabase credentials
class LocalEnv extends Env {
  static const String supabaseUrl = 'YOUR_LOCAL_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_LOCAL_SUPABASE_ANON_KEY';
}
```

Add to `.gitignore`:
```
lib/core/config/env.local.dart
.env
```

### Step 5: Connect to Backend

Edit `lib/core/config/env.dart` to change production config:

```dart
class ProductionConfig extends Env {
  static const String supabaseUrl = 'YOUR_PRODUCTION_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_PRODUCTION_SUPABASE_ANON_KEY';
  static const String apiBaseUrl = 'https://api.spacesense.ai';  // Your Render backend URL
  static const bool debugMode = false;
}
```

### Step 6: Run the App

**Android Emulator:**
```bash
cd mobile
flutter run
```

**iOS Simulator:**
```bash
cd mobile
flutter run --flavor simulator
```

**Physical Device:**
```bash
cd mobile
flutter run --device-id=YOUR_DEVICE_ID
```

## 📱 App Features

### ✅ MVP Features

- **Home Screen**: Room history with scores, FAB for new scans
- **Camera/Upload**: Take photo or pick from gallery
- **Processing**: AI analysis with real-time status updates
- **Results**: Score dashboard + recommendations
- **Settings**: API key management, app preferences
- **History**: Room details with all analyses

### 📊 UI/UX Design

**Color System:**
- Primary: Deep blue (#2E7D32) - trust and reliability
- Accent: Soft green (#81C784) - growth and improvement
- Background: Light gray (#F5F5F5) - clean and accessible
- Text: Dark gray (#212121) - readability

**Typography:**
- Headings: DM Sans (modern, readable)
- Body: Instrument Serif (elegant, accessible)

**Layout:**
- Material Design 3 components
- Responsive design for all screen sizes
- Accessibility features (contrast ratios, screen reader support)

---

## 🧪 Testing the App

### Run Unit Tests
```bash
flutter test
```

### Run Integration Tests
```bash
flutter test integration_test/
```

### Test on Real Device
```bash
# Install platform-specific tools
cd mobile
flutter doctor --android-licenses

# Start emulator or connect device
flutter emulator --avd test_avd &
flutter run --device-id emulator-5554
```

---

## 📊 Performance Optimization

### Android Specific Optimizations
```yaml
# android/app/src/main/res/values/styles.xml
<style name="AppTheme" parent="Theme.Material3.Light">
    <item name="android:windowSplashScreenAnimatedIcon">@drawable/splash_icon</item>
    <item name="android:windowSplashScreenDisplayedDurationMillis">2000</item>
</style>
```

### iOS Specific Optimizations
```objective-c
// ios/Runner/AppDelegate.m
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  // Initialize Firebase
  [FIRApp configure];
  
  // Set up local notifications
  [UNUserNotificationCenter currentNotificationCenter]
      requestAuthorizationWithOptions:(UNAuthorizationOptionAlert + UNAuthorizationOptionSound + UNAuthorizationOptionBadge)
      completionHandler:^(BOOL granted) {
    // Handle authorization
  }];
  
  [super application:application didFinishLaunchingWithOptions:launchOptions];
  return YES;
}
```

---

## 🔧 Advanced Configuration

### Build Flavors
```dart
// lib/core/config/flavor_config.dart
import 'package:flutter/foundation.dart';

enum Flavor { development, staging, production }

class FlavorConfig {
  static Flavor? flavor;
  
  static void init(Flavor flavor) {
    FlavorConfig.flavor = flavor;
  }
  
  static bool get isProduction => flavor == Flavor.production;
  static bool get isDevelopment => flavor == Flavor.development;
  static bool get isStaging => flavor == Flavor.staging;
}
```

### Environment Variables
```yaml
# android/app/src/main/res/values/strings.xml
<string name="supabase_url">YOUR_SUPABASE_URL</string>
<string name="supabase_anon_key">YOUR_SUPABASE_ANON_KEY</string>
<string name="api_base_url">YOUR_API_BASE_URL</string>
<string name="app_name">SpaceSense AI</string>
```

### Push Notifications
```dart
// lib/core/notifications/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  
  NotificationService(this.flutterLocalNotificationsPlugin);
  
  Future<void> showAnalysisCompleteNotification(String roomName) async {
    await flutterLocalNotificationsPlugin.show(
      0,
      'Analysis Complete',
      'Your $roomName analysis is ready!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'analysis_channel',
          'Analysis Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
```

---

## 📚 Resources

### Documentation
- [Flutter Documentation](https://docs.flutter.dev)
- [Riverpod Documentation](https://riverpod.dev/docs/overview/overview)
- [Material Design Guidelines](https://m3.material.io)

### Video Tutorials
- [Flutter Complete Guide](https://www.youtube.com/playlist?list=PLqoSnxQsHQIC6bWkjw9H2vEpSeQg4LQo-)
- [Riverpod Tutorial](https://www.youtube.com/playlist?list=PLbMVog9SWJTreaXvR5zAtdiMndI8KfB5n)

### Communities
- [Flutter Discord](https://discord.gg/flutter)
- [Riverpod Discord](https://discord.gg/9H9aUy8JhV)

---

## 🐛 Troubleshooting

### Common Issues

**1. "Connected to localhost:8000 failed"**
```
// Edit lib/core/config/env.dart
class DevelopmentConfig extends Env {
  static const String apiBaseUrl = 'http://127.0.0.1:8000';
}
```

**2. "Platform not supported"**
```bash
flutter doctor
// Install missing dependencies
c flutter clean
flutter pub get
flutter run
```

**3. "Camera permission denied"**
```dart
// lib/features/camera/permission_service.dart
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestCameraPermission() async {
    var status = await PermissionHandler.cameraPermission.request();
    return status.isGranted;
  }
}
```

**4. Slow app startup**
```yaml
# android/app/build.gradle
android {
    defaultConfig {
        // Minimize app size
        shrinkResources false
        useExopackage true
        
        // Set target SDK
        targetSdkVersion 33
        
        // Optimize for battery
        sourceSets {
            main {
                manifest.srcFile 'src/main/AndroidManifest.xml'
                java.srcDirs = ['src/main/java', 'src/main/kotlin']
                res.srcDirs = ['src/main/res', 'src/main/assets']
            }
        }
    }
}
```

---

## 🚀 Next Steps

### Phase 1: MVP Features
1. ✅ User authentication (email + Google)
2. ✅ Camera/gallery integration
3. ✅ AI analysis pipeline
4. ✅ Local storage of photos and analyses
5. ✅ Score display and recommendations

### Phase 2: Enhancements
1. Add image generation (from text descriptions)
2. Implement multiple redesign styles
3. Add social features (share, compare with others)
4. Create community of rooms and ideas

### Phase 3: Scale
1. Add admin dashboard
2. Implement analytics
3. Create premium tiers

---

## 📄 License

MIT License - Use this starter for your own projects!

---

**Need help?** Check the setup guides in the `docs/` folder or join the Flutter Discord community.

**Ready to build?** Start with Step 1 above! 🚀
