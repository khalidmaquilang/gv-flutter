# TikTok Clone (Flutter)

## Project Overview
This project is a mobile application built with **Flutter**, emulating the core functionality of TikTok. It features a video feed, social interactions (likes, comments, follows), live streaming, wallet integration, and chat.

The project is designed with a **Feature-First Modular Architecture** and uses **Riverpod** for state management.

---

## Tech Stack

### Core
*   **Framework**: Flutter (Dart)
*   **State Management**: `flutter_riverpod`, `riverpod_annotation`
*   **Networking**: `dio` (REST API)
*   **Storage**: `flutter_secure_storage` (Tokens)
*   **Navigation**: Navigator 2.0 (Material `Navigator`)

### Features
*   **Video**: `video_player`, `chewie`, `camera`
*   **Live Streaming**: `agora_rtc_engine`
*   **UI/UX**: `font_awesome_flutter`

### Backend (Assumed/External)
*   **API Base URL**: Configured in `lib/core/constants/api_constants.dart`
*   **Endpoints**: User Authentication (Laravel), Content Delivery, Agora Token Generation.

---

## Architecture

The project follows a modular structure where each feature is encapsulated with its own data and presentation layers.

```
lib/
├── core/                   # Global shared resources
│   ├── constants/          # API endpoints, keys
│   └── theme/              # AppTheme, colors
│
├── features/               # Feature modules
│   ├── auth/               # Login, Register, Auth tokens
│   │   ├── data/           # Services (AuthService), Models (User)
│   │   └── presentation/   # Providers, Screens (Login, Register), Widgets
│   │
│   ├── feed/               # Main FYP, Following, Comments, Likes
│   │   ├── data/           # VideoService, Comment Model
│   │   └── presentation/   # FeedScreen, VideoFeedList, VideoPlayerItem
│   │
│   ├── camera/             # Recording functionality
│   ├── live/               # Live Streaming logic (Agora)
│   ├── profile/            # User profile, Edit, Settings
│   └── wallet/             # Coin purchase, withdrawal mockup
│
└── main.dart               # Entry point, ProviderScope, App Theme
```

---

## Key Features & Specifications

### 1. Authentication
*   **System**: Email/Password.
*   **Flow**: 
    1.  User enters credentials.
    2.  `AuthService` sends POST to `/login`.
    3.  Token is stored via `flutter_secure_storage`.
    4.  User profile is fetched from `/user`.
*   **Files**: `auth_service.dart`, `login_screen.dart`, `register_screen.dart`.

### 2. Home Feed (FYP)
*   **Navigation**: Swipeable tabs: **Live**, **Following**, **For You**.
*   **Layout**: `Stack` with `TabBarView`.
*   **Video List**: `VideoFeedList` widget reusing `PageView.builder` for vertical scrolling.
*   **Interaction**:
    *   **Like**: Toggles local state immediately (Optimistic UI) -> Syncs via `VideoService.likeVideo`.
    *   **Comments**: Opens `CommentBottomSheet` -> Fetches/Posts via `VideoService`.

### 3. Live Streaming
*   **Engine**: Agora RTC.
*   **Roles**: Broadcaster (Host) vs Audience (Viewer).
*   **Status**: Basic channel joining implemented.
*   **Files**: `live_service.dart`, `live_stream_screen.dart`.

### 4. Wallet
*   **Currency**: Mock tokens/coins.
*   **Actions**: Buy, Withdraw (UI only).
*   **Files**: `wallet_screen.dart`.

---

## API Contract (Mock/Expected)

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| **POST** | `/login` | Returns `{ token: "..." }` (Plain string or JSON) |
| **GET** | `/user` | Returns User object |
| **GET** | `/videos` | Returns List of Videos |
| **POST** | `/videos/{id}/like` | Toggle Like |
| **GET** | `/videos/{id}/comments` | Get comments list |
| **POST** | `/videos/{id}/comments` | Post a comment |

---

## Development Notes for AI
*   **Context**: When modifying this codebase, always check `task.md` for current progress.
*   **Pattern**: Use `ConsumerWidget` or `ConsumerStatefulWidget` (Riverpod) for all state-dependent UI.
*   **Style**: Adhere to the Dark Theme (TikTok style). Primary color: `#FE2C55`.
*   **Images**: Use `generate_image` tool if creating new assets is required, otherwise mock with network placeholders.

---
**Last Updated**: 2025-12-13
