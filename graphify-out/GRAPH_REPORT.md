# Graph Report - .  (2026-04-24)

## Corpus Check
- Corpus is ~39,860 words - fits in a single context window. You may not need a graph.

## Summary
- 698 nodes · 985 edges · 31 communities detected
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.84)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Admin Screen Management|Admin Screen Management]]
- [[_COMMUNITY_UI Design System|UI Design System]]
- [[_COMMUNITY_Auth & Registration|Auth & Registration]]
- [[_COMMUNITY_Workout Tracking|Workout Tracking]]
- [[_COMMUNITY_Meal Logging|Meal Logging]]
- [[_COMMUNITY_Data Models|Data Models]]
- [[_COMMUNITY_Trainer Dashboard|Trainer Dashboard]]
- [[_COMMUNITY_Windows Native Layer|Windows Native Layer]]
- [[_COMMUNITY_Member Home Screen|Member Home Screen]]
- [[_COMMUNITY_Member Profile|Member Profile]]
- [[_COMMUNITY_Linux Native Layer|Linux Native Layer]]
- [[_COMMUNITY_Linux Build Config|Linux Build Config]]
- [[_COMMUNITY_App Theme & Onboarding|App Theme & Onboarding]]
- [[_COMMUNITY_Admin Member Detail|Admin Member Detail]]
- [[_COMMUNITY_Firebase Initialization|Firebase Initialization]]
- [[_COMMUNITY_Windows Build Config|Windows Build Config]]
- [[_COMMUNITY_Admin Member List|Admin Member List]]
- [[_COMMUNITY_Web & iOS Icons|Web & iOS Icons]]
- [[_COMMUNITY_Android App Icons|Android App Icons]]
- [[_COMMUNITY_iOSmacOS App Delegate|iOS/macOS App Delegate]]
- [[_COMMUNITY_macOS Window Setup|macOS Window Setup]]
- [[_COMMUNITY_Test Suite|Test Suite]]
- [[_COMMUNITY_Plugin Registration|Plugin Registration]]
- [[_COMMUNITY_iOS LLDB Debug Helper|iOS LLDB Debug Helper]]
- [[_COMMUNITY_Widget Test|Widget Test]]
- [[_COMMUNITY_Spacing & Radius|Spacing & Radius]]
- [[_COMMUNITY_App Constants & Routes|App Constants & Routes]]
- [[_COMMUNITY_Auth Service|Auth Service]]
- [[_COMMUNITY_macOS App Icon Design|macOS App Icon Design]]
- [[_COMMUNITY_Android Main Activity|Android Main Activity]]
- [[_COMMUNITY_Input Validators|Input Validators]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 34 edges
2. `../core/app_colors.dart` - 30 edges
3. `../core/app_text_styles.dart` - 28 edges
4. `package:gap/gap.dart` - 22 edges
5. `package:provider/provider.dart` - 21 edges
6. `../../services/user_provider.dart` - 21 edges
7. `../services/firestore_service.dart` - 18 edges
8. `package:cloud_firestore/cloud_firestore.dart` - 17 edges
9. `../models/user.dart` - 17 edges
10. `../core/constants.dart` - 14 edges

## Surprising Connections (you probably didn't know these)
- `iOS Launch Screen Assets` --conceptually_related_to--> `burnfit`  [INFERRED]
  ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md → README.md
- `burnfit Web App` --conceptually_related_to--> `burnfit`  [INFERRED]
  web/index.html → README.md
- `burnfit` --conceptually_related_to--> `burnfit Linux Binary`  [INFERRED]
  README.md → linux/CMakeLists.txt
- `burnfit` --conceptually_related_to--> `burnfit Windows Binary`  [INFERRED]
  README.md → windows/CMakeLists.txt
- `burnfit Linux Binary` --conceptually_related_to--> `burnfit Windows Binary`  [INFERRED]
  linux/CMakeLists.txt → windows/CMakeLists.txt

## Hyperedges (group relationships)
- **burnfit Flutter Multi-Platform Build** — readme_burnfit, linux_cmakelists_burnfit_binary, windows_cmakelists_burnfit_binary, web_index_burnfit_web_app, ios_launch_image_readme [INFERRED 0.85]
- **Linux Flutter Build Chain** — linux_cmakelists_burnfit_binary, linux_runner_cmakelists_runner_target, linux_flutter_cmakelists_flutter_lib, linux_flutter_cmakelists_flutter_assemble_target [EXTRACTED 1.00]
- **Windows Flutter Build Chain** — windows_cmakelists_burnfit_binary, windows_runner_cmakelists_runner_target, windows_flutter_cmakelists_flutter_lib, windows_flutter_cmakelists_flutter_assemble_target, windows_flutter_cmakelists_flutter_wrapper_plugin, windows_runner_cmakelists_flutter_wrapper_app [EXTRACTED 1.00]

## Communities

### Community 0 - "Admin Screen Management"
Cohesion: 0.03
Nodes (66): admin_member_list_screen.dart, admin_requests_screen.dart, admin_trainer_list_screen.dart, package:provider/provider.dart, package:table_calendar/table_calendar.dart, ../../services/user_provider.dart, AdminHomeScreen, _AdminHomeScreenState (+58 more)

### Community 1 - "UI Design System"
Cohesion: 0.04
Nodes (62): ../core/app_colors.dart, ../core/app_spacing.dart, ../core/app_text_styles.dart, dart:ui, package:flutter/material.dart, package:gap/gap.dart, trainer_member_detail_screen.dart, trainer_schedule_screen.dart (+54 more)

### Community 2 - "Auth & Registration"
Cohesion: 0.04
Nodes (58): admin/admin_register_screen.dart, ../../core/validators.dart, member/member_register_screen.dart, ../models/center.dart, ../models/feedback.dart, ../models/inbody.dart, ../models/join_request.dart, ../models/pt_info.dart (+50 more)

### Community 3 - "Workout Tracking"
Cohesion: 0.05
Nodes (42): ../../core/exercise_data.dart, ../../services/exercise_service.dart, _addExercise, _addSet, AppButton, AppCard, AppTextField, BorderSide (+34 more)

### Community 4 - "Meal Logging"
Cohesion: 0.05
Nodes (40): ../core/constants.dart, dart:io, ../models/meal.dart, package:firebase_storage/firebase_storage.dart, package:flutter_image_compress/flutter_image_compress.dart, package:image_picker/image_picker.dart, AlertDialog, AppBottomSheetHeader (+32 more)

### Community 5 - "Data Models"
Cohesion: 0.05
Nodes (26): ../models/cardio.dart, ../models/custom_exercise.dart, ../models/workout.dart, package:cloud_firestore/cloud_firestore.dart, package:uuid/uuid.dart, ExerciseData, Cardio, Center (+18 more)

### Community 6 - "Trainer Dashboard"
Cohesion: 0.06
Nodes (36): app_button.dart, app_text_field.dart, ../services/cardio_service.dart, ../services/meal_service.dart, ../services/workout_service.dart, AppCard, build, _CardiosTab (+28 more)

### Community 7 - "Windows Native Layer"
Cohesion: 0.09
Nodes (25): FlutterWindow(), OnCreate(), RegisterPlugins(), wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16(), Create() (+17 more)

### Community 8 - "Member Home Screen"
Cohesion: 0.06
Nodes (33): member_meal_log_screen.dart, member_profile_screen.dart, member_pt_schedule_screen.dart, member_workout_screen.dart, build, Column, Container, _DashboardFilter (+25 more)

### Community 9 - "Member Profile"
Cohesion: 0.06
Nodes (32): _ActionPanel, AppBottomSheetHeader, _BodyCompositionPanel, _BodyMetricTile, build, Column, Container, dispose (+24 more)

### Community 10 - "Linux Native Layer"
Cohesion: 0.08
Nodes (16): fl_register_plugins(), main(), my_application_activate(), my_application_dispose(), my_application_new(), package:intl/intl.dart, AppDateStrip, _AppDateStripState (+8 more)

### Community 11 - "Linux Build Config"
Cohesion: 0.1
Nodes (24): iOS Launch Screen Assets, burnfit Linux Binary, flutter_assemble (Linux), Linux Flutter Managed Dir, generated_plugins.cmake (Linux), GTK+ 3.0 (Linux), flutter_assemble custom target (Linux), flutter Interface Library (Linux) (+16 more)

### Community 12 - "App Theme & Onboarding"
Cohesion: 0.09
Nodes (19): app_colors.dart, package:flutter/services.dart, AppTextStyles, _base, TextStyle, AppTheme, ThemeData, build (+11 more)

### Community 13 - "Admin Member Detail"
Cohesion: 0.09
Nodes (21): AdminMemberDetailScreen, _AdminMemberDetailScreenState, AlertDialog, build, _DateRow, dispose, Divider, Function (+13 more)

### Community 14 - "Firebase Initialization"
Cohesion: 0.1
Nodes (19): core/app_theme.dart, firebase_options.dart, package:firebase_core/firebase_core.dart, package:flutter/foundation.dart, package:intl/date_symbol_data_local.dart, screens/admin/admin_home_screen.dart, screens/login_screen.dart, screens/member/member_home_screen.dart (+11 more)

### Community 15 - "Windows Build Config"
Cohesion: 0.17
Nodes (15): core_implementations.cc + standard_codec.cc, flutter_assemble custom target (Windows), flutter Interface Library (Windows), flutter_windows.dll, flutter_wrapper_plugin, generated_config.cmake (Windows), dwmapi.lib, flutter_assemble (Windows) (+7 more)

### Community 16 - "Admin Member List"
Cohesion: 0.15
Nodes (12): admin_member_detail_screen.dart, AdminMemberListScreen, _AdminMemberListScreenState, AppCard, BorderSide, build, dispose, _filter (+4 more)

### Community 17 - "Web & iOS Icons"
Cohesion: 0.29
Nodes (12): BurnFit App, Web Favicon (Flutter logo, small), Flutter Logo / Branding (light blue + dark blue angular chevron mark), PWA Standard Icon 192x192 (Flutter logo, light/dark blue on white), PWA Standard Icon 512x512 (Flutter logo, light/dark blue, white background), PWA Maskable Icon 192x192 (Flutter logo, light/dark blue, safe-zone centered), PWA Maskable Icon 512x512 (Flutter logo, light/dark blue, white background, safe-zone centered), iOS Launch Image Set (1x, 2x, 3x blank white splash) (+4 more)

### Community 18 - "Android App Icons"
Cohesion: 0.27
Nodes (11): BurnFit App Branding — no custom icon; uses unmodified Flutter default icon across iOS and Android, Flutter Default App Icon Design — sky-blue (#42A5F5) diagonal chevrons forming stylized F/arrow, dark navy (#1A237E) accent, white background; no custom branding applied, Android Launcher Icon mipmap-hdpi — Flutter default logo (sky-blue chevrons, navy accent, white bg), Android Launcher Icon mipmap-mdpi — Flutter default logo (sky-blue chevrons, navy accent, white bg), Android Launcher Icon mipmap-xhdpi — Flutter default logo (sky-blue chevrons, navy accent, white bg), Android Launcher Icon mipmap-xxhdpi — Flutter default logo (sky-blue chevrons, navy accent, white bg), Android Launcher Icon mipmap-xxxhdpi — Flutter default logo (sky-blue chevrons, navy accent, white bg), iOS App Icon 1024x1024@1x — Flutter default logo (sky-blue chevrons, navy accent, white bg) (+3 more)

### Community 19 - "iOS/macOS App Delegate"
Cohesion: 0.29
Nodes (2): AppDelegate, FlutterAppDelegate

### Community 20 - "macOS Window Setup"
Cohesion: 0.33
Nodes (3): RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 21 - "Test Suite"
Cohesion: 0.4
Nodes (2): RunnerTests, XCTestCase

### Community 22 - "Plugin Registration"
Cohesion: 0.4
Nodes (2): GeneratedPluginRegistrant, -registerWithRegistry

### Community 23 - "iOS LLDB Debug Helper"
Cohesion: 0.5
Nodes (2): handle_new_rx_page(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

### Community 24 - "Widget Test"
Cohesion: 0.67
Nodes (2): package:flutter_test/flutter_test.dart, main

### Community 25 - "Spacing & Radius"
Cohesion: 0.67
Nodes (2): AppRadius, AppSpacing

### Community 26 - "App Constants & Routes"
Cohesion: 0.67
Nodes (2): AppConstants, AppRoutes

### Community 27 - "Auth Service"
Cohesion: 0.67
Nodes (2): package:firebase_auth/firebase_auth.dart, AuthService

### Community 28 - "macOS App Icon Design"
Cohesion: 1.0
Nodes (3): BurnFit macOS App Icon (Flutter Default), macOS App Icon Size Variants (16, 32, 64, 128, 256, 512, 1024 px), Flutter Framework Logo Mark

### Community 29 - "Android Main Activity"
Cohesion: 1.0
Nodes (1): MainActivity

### Community 30 - "Input Validators"
Cohesion: 1.0
Nodes (1): Validators

## Knowledge Gaps
- **481 isolated node(s):** `main`, `package:flutter_test/flutter_test.dart`, `-registerWithRegistry`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `MainActivity` (+476 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `iOS/macOS App Delegate`** (7 nodes): `AppDelegate`, `.application()`, `.applicationShouldTerminateAfterLastWindowClosed()`, `.applicationSupportsSecureRestorableState()`, `FlutterAppDelegate`, `AppDelegate.swift`, `AppDelegate.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Test Suite`** (5 nodes): `RunnerTests.swift`, `RunnerTests.swift`, `RunnerTests`, `.testExample()`, `XCTestCase`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Plugin Registration`** (5 nodes): `GeneratedPluginRegistrant.java`, `GeneratedPluginRegistrant`, `.registerWith()`, `-registerWithRegistry`, `GeneratedPluginRegistrant.m`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `iOS LLDB Debug Helper`** (4 nodes): `handle_new_rx_page()`, `__lldb_init_module()`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `flutter_lldb_helper.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Widget Test`** (3 nodes): `package:flutter_test/flutter_test.dart`, `widget_test.dart`, `main`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Spacing & Radius`** (3 nodes): `app_spacing.dart`, `AppRadius`, `AppSpacing`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `App Constants & Routes`** (3 nodes): `constants.dart`, `AppConstants`, `AppRoutes`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Auth Service`** (3 nodes): `auth_service.dart`, `package:firebase_auth/firebase_auth.dart`, `AuthService`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Android Main Activity`** (2 nodes): `MainActivity.kt`, `MainActivity`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Input Validators`** (2 nodes): `validators.dart`, `Validators`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `UI Design System` to `Admin Screen Management`, `Auth & Registration`, `Workout Tracking`, `Meal Logging`, `Trainer Dashboard`, `Member Home Screen`, `Member Profile`, `Linux Native Layer`, `App Theme & Onboarding`, `Admin Member Detail`, `Firebase Initialization`, `Admin Member List`?**
  _High betweenness centrality (0.130) - this node is a cross-community bridge._
- **Why does `../core/app_colors.dart` connect `UI Design System` to `Admin Screen Management`, `Auth & Registration`, `Workout Tracking`, `Meal Logging`, `Trainer Dashboard`, `Member Home Screen`, `Member Profile`, `Linux Native Layer`, `App Theme & Onboarding`, `Admin Member Detail`, `Admin Member List`?**
  _High betweenness centrality (0.077) - this node is a cross-community bridge._
- **Why does `../core/app_text_styles.dart` connect `UI Design System` to `Admin Screen Management`, `Auth & Registration`, `Workout Tracking`, `Meal Logging`, `Trainer Dashboard`, `Member Home Screen`, `Member Profile`, `Linux Native Layer`, `App Theme & Onboarding`, `Admin Member Detail`, `Admin Member List`?**
  _High betweenness centrality (0.069) - this node is a cross-community bridge._
- **What connects `main`, `package:flutter_test/flutter_test.dart`, `-registerWithRegistry` to the rest of the system?**
  _481 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Admin Screen Management` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._
- **Should `UI Design System` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._
- **Should `Auth & Registration` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._