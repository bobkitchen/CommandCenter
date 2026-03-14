# Command Center iOS App — Specification

## Overview
Native SwiftUI iOS app for the Command Center dashboard. Connects to an existing Next.js API backend running at a configurable URL (default: `http://100.74.188.28:8765` via Tailscale).

## Architecture
- **SwiftUI** (iOS 17+)
- **URLSession** for REST API calls
- **No third-party dependencies** — pure Apple frameworks
- Target: iPhone (iPad layout can come later)

## Authentication
The API uses a simple token-based auth:
1. POST to `/api/auth/login` with body `{"token": "<password>"}`
2. Response sets a cookie `cc_session` with the auth token
3. All subsequent requests must include this cookie
4. The auth token/password is: `a6f02a18250e3080e26e747b7b64e874` (hardcoded default, can be overridden)

On first launch, show a settings/login screen where user enters:
- **Server URL** (e.g., `http://100.74.188.28:8765`)
- **Password** (the dashboard token)

Store both in Keychain. Auto-login on subsequent launches.

## App Structure — 3 Tabs

### Tab 1: Dashboard
A scrollable grid of widget cards. Each widget fetches its own data.

**Widgets to implement:**

1. **Weather** — `GET /api/weather` → returns `{ current: { temp, condition, humidity, wind, icon }, forecast: [...] }`
2. **Calendar** — `GET /api/calendar` → returns `{ events: [{ title, start, end, location, calendar }] }`
3. **Strava** — `GET /api/strava` → returns `{ stats: { recent_ride_totals, ytd_ride_totals, ... }, activities: [...] }`
4. **Crises** — `GET /api/crises` → returns `{ crises: [{ name, status, level, updated, summary }] }` — show as colored status cards (critical=red, serious=orange, stable=green)
5. **Agents** — `GET /api/sessions?limit=10` → returns agent session status cards
6. **OpenClaw Status** — `GET /api/openclaw-status` → returns `{ version, uptime, model, sessions }`

Design: Cards with rounded corners, dark theme matching the web app's color scheme:
- Background: #0d1117
- Cards: #161b22
- Border: #30363d
- Accent: #58a6ff
- Text: #e6edf3
- Muted: #8b949e
- Success: #3fb950
- Warning: #d29922
- Danger: #f85149

### Tab 2: Chat
Full chat interface with Denny (the AI assistant).

**API Endpoints:**
- `GET /api/chat/history?limit=200` → returns `{ messages: [{ id, role, content, timestamp, channel }] }`
- `POST /api/chat/send` with body `{"content": "message text"}` → sends message, returns `{ ok: true }`
- `GET /api/chat/status` → returns typing/agent status

**Chat UI Requirements:**
- Messages display as bubbles: user (accent blue, right-aligned) and assistant (dark card, left-aligned)
- Assistant messages render basic Markdown (bold, code, lists, headers, links)
- Auto-scroll to bottom on new messages
- Pull-to-refresh for history
- Text input at bottom with send button
- Native iOS keyboard handling (input moves up with keyboard)
- Poll for new messages every 3 seconds while on chat tab (simple polling, not WebSocket)
- Show a flamingo emoji 🦩 as assistant avatar
- Timestamp below each message (e.g., "10:42 PM")
- Support for image display in messages (URLs and local paths via `/api/media?path=...`)

**Message content cleaning (do this client-side):**
- Strip `[[reply_to_current]]` and similar reply tags from assistant messages
- Messages with role "system" should be hidden
- Messages matching "HEARTBEAT_OK" or "NO_REPLY" should be hidden

### Tab 3: Files
File browser for the workspace and agent workspaces.

**API Endpoints:**
- `GET /api/files` → directory listing of workspace root: `{ path, workspace, entries: [{ name, type, size, modified, extension }] }`
- `GET /api/files/memory` → directory listing of memory folder
- `GET /api/files/SOUL.md?content=true` → file content: `{ type: "text", content: "...", filename, size }`
- `GET /api/files/path/to/image.png?content=true` → image: `{ type: "image", content: "data:image/png;base64,..." }`
- Query param `?workspace=workspace-sentinel` to browse other agent workspaces

**File Browser UI:**
- List view with file/folder icons
- Tap folder → navigate into it
- Tap file → preview (text files render as markdown, images display inline)
- Breadcrumb navigation at top
- Workspace picker (dropdown: main, sentinel, mirror, scout, etc.)
- Show file size and modification date in muted text

## Design Language
- **Dark mode only** (matches the web dashboard)
- **SF Symbols** for icons throughout
- **SF Pro** font (system default)
- Clean, minimal, information-dense
- Tab bar at bottom with: Dashboard (square.grid.2x2), Chat (bubble.left.and.bubble.right), Files (folder)
- Navigation bar with "Command Center" title, flamingo accent color

## Project Structure
```
CommandCenter/
├── CommandCenter.xcodeproj/
├── CommandCenter/
│   ├── CommandCenterApp.swift          # App entry point
│   ├── ContentView.swift               # Tab bar container
│   ├── Models/
│   │   ├── Message.swift               # Chat message model
│   │   ├── FileEntry.swift             # File browser model
│   │   ├── Crisis.swift                # Crisis card model
│   │   ├── WeatherData.swift           # Weather model
│   │   └── CalendarEvent.swift         # Calendar event model
│   ├── Services/
│   │   ├── APIClient.swift             # HTTP client with auth cookie handling
│   │   ├── AuthService.swift           # Login, keychain storage
│   │   └── ChatService.swift           # Chat-specific API + polling
│   ├── Views/
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift     # Main dashboard grid
│   │   │   ├── WeatherCard.swift
│   │   │   ├── CalendarCard.swift
│   │   │   ├── StravaCard.swift
│   │   │   ├── CrisisCard.swift
│   │   │   ├── AgentCard.swift
│   │   │   └── StatusCard.swift
│   │   ├── Chat/
│   │   │   ├── ChatView.swift          # Main chat view
│   │   │   ├── MessageBubble.swift     # Individual message bubble
│   │   │   ├── ChatInputBar.swift      # Text input + send button
│   │   │   └── MarkdownText.swift      # Basic markdown renderer
│   │   ├── Files/
│   │   │   ├── FileBrowserView.swift   # File list view
│   │   │   ├── FileRow.swift           # Individual file row
│   │   │   └── FilePreviewView.swift   # File content preview
│   │   └── Settings/
│   │       └── LoginView.swift         # Server URL + password entry
│   ├── Utilities/
│   │   ├── KeychainHelper.swift        # Keychain read/write
│   │   └── Colors.swift                # App color constants
│   ├── Assets.xcassets/
│   └── Info.plist
└── README.md
```

## Important Notes
- The server runs on a private Tailscale network (HTTP, not HTTPS). The app needs to allow arbitrary loads in Info.plist (`NSAppTransportSecurity` → `NSAllowsArbitraryLoads`).
- Keep it simple. No CoreData, no SwiftData, no Combine unless genuinely needed. Use async/await and @Observable.
- Target iOS 17+ so we can use the latest SwiftUI features (@Observable, etc.)
- This is a personal app, not App Store. Don't worry about localization or accessibility perfection.
- The color scheme MUST match the web app (dark theme colors listed above).
