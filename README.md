# Command Center — iOS App

Native SwiftUI iOS app for the Command Center dashboard. Built for **iOS 26+** with Apple's **Liquid Glass** design language.

## Features

- **Dashboard** — Widget grid: Weather, Calendar, Crises, Strava, Agents, OpenClaw Status
- **Chat** — Full messaging UI with Denny 🦩 (3-second polling, Markdown rendering)
- **Files** — File browser with workspace picker, breadcrumbs, text/image preview

## Design

- Dark theme with Liquid Glass throughout (iOS 26+)
- `#available` fallbacks to `.ultraThinMaterial` for older iOS
- Dashboard cards use `GlassEffectContainer` + `.glassEffect()`
- Chat assistant bubbles: frosted glass. User bubbles: solid accent blue.
- Subtle gradient background gives glass surfaces depth and refraction

## Setup on Mac

### Option 1: XcodeGen (recommended)

```bash
# Install XcodeGen if you don't have it
brew install xcodegen

# Generate the Xcode project
cd CommandCenter
xcodegen generate

# Open in Xcode
open CommandCenter.xcodeproj
```

### Option 2: Manual Xcode project

1. Open Xcode → File → New → Project → iOS → App
2. Product Name: `CommandCenter`, Interface: SwiftUI, Language: Swift
3. Set deployment target to iOS 26.0
4. Delete the auto-generated ContentView.swift and CommandCenterApp.swift
5. Drag the entire `CommandCenter/` folder into the project navigator
6. In target Build Settings:
   - Set `INFOPLIST_FILE` to `CommandCenter/Info.plist`
   - Bundle ID: `com.bobkitchen.commandcenter`
7. Build and run

## Configuration

On first launch, enter:
- **Server URL**: `http://100.74.188.28:8765` (your Tailscale IP)
- **Password**: The dashboard token

Credentials are stored in Keychain and auto-login on subsequent launches.

## Architecture

- **Pure SwiftUI** — no third-party dependencies
- **@Observable** for state management (iOS 17+)
- **async/await** for all networking
- **URLSession** with cookie-based auth
- `NSAllowsArbitraryLoads` enabled for HTTP Tailscale server

## File Structure

```
CommandCenter/
├── CommandCenterApp.swift       # App entry point
├── ContentView.swift            # Tab container
├── Info.plist                   # ATS config
├── Assets.xcassets/
├── Models/
│   ├── Message.swift
│   ├── FileEntry.swift
│   ├── Crisis.swift
│   ├── WeatherData.swift
│   └── CalendarEvent.swift
├── Services/
│   ├── APIClient.swift          # HTTP + auth cookies
│   ├── AuthService.swift        # Login + Keychain
│   └── ChatService.swift        # Chat polling
├── Views/
│   ├── Dashboard/               # 6 widget cards
│   ├── Chat/                    # Messages, input, Markdown
│   ├── Files/                   # Browser, rows, preview
│   └── Settings/                # Login screen
└── Utilities/
    ├── Colors.swift             # Theme colors
    ├── KeychainHelper.swift
    └── GlassModifiers.swift     # Liquid Glass helpers
```
