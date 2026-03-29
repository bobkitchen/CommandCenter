# Server-Side WebSocket Spec for Command Center iOS App

## Overview

The Command Center iOS app needs a WebSocket endpoint for real-time chat. The iOS client is **already built and deployed** — it attempts to connect to `ws://<server>/api/chat/ws` on launch. If the endpoint doesn't exist, it falls back to polling. Once this endpoint is live, the app will automatically switch to real-time mode with zero client-side changes.

## Endpoint

```
GET /api/chat/ws  →  WebSocket Upgrade
```

- **Protocol**: `ws://` (not `wss://` — running over Tailscale private network)
- **Authentication**: The iOS client sends the `cc_session` cookie with the upgrade request. Validate it the same way you validate REST API requests. Reject with 401 if invalid.
- **No new dependencies required if using Node.js**: The `ws` package is the standard choice. If already using Express, add `express-ws` or handle the upgrade manually.

## Authentication Flow

```
1. iOS client connects: GET /api/chat/ws
   Headers:
     Connection: Upgrade
     Upgrade: websocket
     Cookie: cc_session=<auth_token>

2. Server validates cc_session cookie
   - Valid → complete WebSocket upgrade (101 Switching Protocols)
   - Invalid → respond with 401 and close
```

## Server → Client Messages

The server should send JSON messages to the client. The iOS app handles **three message formats** — implement whichever is easiest for your architecture:

### Option A: New Message Push (recommended)

Send each new message individually as it arrives. This is the most efficient approach.

```json
{
  "type": "message",
  "message": {
    "id": "msg_abc123",
    "role": "assistant",
    "content": "Here's the weather forecast...",
    "timestamp": "2026-03-20T14:30:00Z",
    "channel": "web"
  }
}
```

**When to send**: Every time a new message is added to the chat (both user messages from other clients and assistant responses).

### Option B: Typing Indicator

```json
{
  "type": "typing",
  "typing": true
}
```

**When to send**:
- `typing: true` → when Denny starts generating a response
- `typing: false` → when Denny finishes responding (or send a `type: "message"` which implicitly clears typing)

### Option C: Full History Sync (alternative to Option A)

If easier, you can push the full message list. The client will diff and merge.

```json
{
  "messages": [
    {"id": "msg_1", "role": "user", "content": "hello", "timestamp": "...", "channel": "web"},
    {"id": "msg_2", "role": "assistant", "content": "Hi Bob!", "timestamp": "...", "channel": "web"}
  ],
  "typing": false
}
```

**When to send**: After any new message is added. This is simpler to implement but sends more data per update.

## Client → Server Messages

The iOS app sends messages in this format:

```json
{
  "type": "message",
  "content": "What's the weather like?"
}
```

**Server should**:
1. Receive this JSON
2. Process it identically to `POST /api/chat/send` with body `{"content": "..."}`
3. Broadcast the resulting assistant response back via WebSocket (using Option A or C above)

## Message Schema Reference

Each message object must match the existing REST API schema:

```typescript
interface Message {
  id: string;          // Unique message ID (e.g., "msg_abc123" or UUID)
  role: string;        // "user" | "assistant" | "system"
  content: string;     // Message text (markdown supported)
  timestamp: string;   // ISO 8601 format (e.g., "2026-03-20T14:30:00Z")
  channel?: string;    // "web" | "ios" | "irc" | "telegram" | etc. (optional)
}
```

## Connection Lifecycle

```
iOS App                          Server
  |                                |
  |--- GET /api/chat/ws --------->|  (with cc_session cookie)
  |<-- 101 Switching Protocols ---|  (if auth valid)
  |                                |
  |<-- {"type":"typing","typing":true} --|  (Denny is thinking)
  |<-- {"type":"message","message":{...}}|  (Denny responds)
  |                                |
  |--- {"type":"message","content":"hi"} -->|  (Bob sends)
  |<-- {"type":"typing","typing":true} --|  (Denny is thinking)
  |<-- {"type":"message","message":{...}}|  (Denny responds)
  |                                |
  |--- ping ---------------------->|  (iOS sends keepalive every ~30s)
  |<-- pong -----------------------|
  |                                |
  |--- close (1000, going away) -->|  (app backgrounded or tab switched)
```

## Keepalive / Ping-Pong

- The iOS client sends WebSocket pings automatically (handled by `URLSessionWebSocketTask`)
- The server **must respond to pings with pongs** (this is default behavior for the `ws` npm package — no code needed)
- If the server doesn't receive a ping for 60 seconds, it can close the connection
- The iOS client will detect the disconnect and attempt reconnection with exponential backoff (1s, 2s, 4s), then fall back to polling after 3 failed attempts

## Multi-Client Broadcasting

If Bob has multiple clients connected (iOS app, web dashboard, IRC, Telegram):
- When a message arrives from **any** client or channel, broadcast it to **all** connected WebSocket clients
- This ensures the iOS app sees messages Bob sent from Telegram, the web dashboard, IRC, and vice versa
- The `channel` field identifies the source: `"ios"`, `"web"`, `"irc"`, `"telegram"`

## Cross-Channel Message Sync (CRITICAL)

**All channels must share the same message history.** The iOS Command Center app and Telegram must show identical conversations. This requires three things:

### 1. History endpoint must return ALL channels

`GET /api/chat/history` must return messages from every channel — web, ios, irc, telegram. Do NOT filter by channel. The query should be:

```sql
-- CORRECT: return all messages regardless of channel
SELECT * FROM messages ORDER BY timestamp DESC LIMIT 200

-- WRONG: filtering by channel breaks cross-platform sync
SELECT * FROM messages WHERE channel IN ('web', 'ios') ORDER BY timestamp DESC LIMIT 200
```

### 2. Telegram messages must broadcast to WebSocket clients

When a message arrives from Telegram, the server must:

1. Store it in the database with `channel: "telegram"` and `role: "user"`
2. **Broadcast it to all connected WebSocket clients** using the standard envelope:

```json
{
  "type": "message",
  "message": {
    "id": "msg_tg_12345",
    "role": "user",
    "content": "Message sent from Telegram",
    "timestamp": "2026-03-21T10:30:00Z",
    "channel": "telegram"
  }
}
```

3. When Denny replies to a Telegram message, that reply must also broadcast to all WebSocket clients:

```json
{
  "type": "message",
  "message": {
    "id": "msg_reply_456",
    "role": "assistant",
    "content": "Denny's response...",
    "timestamp": "2026-03-21T10:30:05Z",
    "channel": "telegram"
  }
}
```

### 3. iOS/web messages must forward to Telegram

When a message arrives from the iOS app or web dashboard:

1. Store it and broadcast to WebSocket clients (existing behavior)
2. **Also send it to the Telegram chat** so the Telegram side sees messages sent from Command Center

This creates a true bidirectional bridge:
```
Telegram → Server → WebSocket broadcast → iOS app, web dashboard
iOS app  → Server → WebSocket broadcast → web dashboard + Telegram forward
Web      → Server → WebSocket broadcast → iOS app + Telegram forward
```

### 4. Message roles must be consistent

Regardless of which channel a message arrives from:
- Human messages: `role: "user"` (whether from Telegram, iOS, web, or IRC)
- Denny's responses: `role: "assistant"`
- System messages: `role: "system"` (these are hidden in the iOS app)

Do **NOT** use channel-specific roles like `role: "telegram"` — the iOS app will not display them correctly.

## Error Handling

| Scenario | Server Action |
|----------|--------------|
| Invalid/expired cookie | Reject upgrade with 401 |
| Malformed JSON from client | Ignore the message, log a warning |
| Client disconnects abruptly | Clean up the connection, no action needed |
| Server restart | Clients will reconnect automatically |

## Minimal Implementation Example (Node.js + ws)

```javascript
const WebSocket = require('ws');

// Attach to your existing HTTP server
const wss = new WebSocket.Server({ noServer: true });

// Handle upgrade requests on /api/chat/ws
server.on('upgrade', (request, socket, head) => {
  if (request.url !== '/api/chat/ws') {
    socket.destroy();
    return;
  }

  // Validate cc_session cookie
  const cookies = parseCookies(request.headers.cookie);
  if (!isValidSession(cookies.cc_session)) {
    socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
    socket.destroy();
    return;
  }

  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit('connection', ws, request);
  });
});

// Handle connections
wss.on('connection', (ws) => {
  console.log('[WS] Client connected');

  // Send recent history on connect (optional but nice)
  const history = getChatHistory(50);
  ws.send(JSON.stringify({ messages: history, typing: false }));

  // Handle incoming messages from this client
  ws.on('message', async (data) => {
    try {
      const parsed = JSON.parse(data);
      if (parsed.type === 'message' && parsed.content) {
        // Process like POST /api/chat/send
        const response = await processMessage(parsed.content);

        // Broadcast typing indicator to ALL clients
        broadcast({ type: 'typing', typing: true });

        // ... wait for Denny to respond ...

        // Broadcast the user's message to ALL clients (so other clients see it)
        broadcast({
          type: 'message',
          message: {
            id: userMsg.id,
            role: 'user',
            content: parsed.content,
            timestamp: new Date().toISOString(),
            channel: 'ios'  // or 'web' depending on source
          }
        });

        // Forward to Telegram so Telegram users see it too
        await sendToTelegram(parsed.content);

        // ... wait for Denny to respond ...

        // Broadcast the response to ALL clients
        broadcast({
          type: 'message',
          message: {
            id: response.id,
            role: 'assistant',
            content: response.content,
            timestamp: new Date().toISOString(),
            channel: 'web'
          }
        });

        // Forward Denny's reply to Telegram too
        await sendToTelegram(response.content);
      }
    } catch (e) {
      console.warn('[WS] Bad message:', e.message);
    }
  });

  ws.on('close', () => console.log('[WS] Client disconnected'));
});

function broadcast(data) {
  const json = JSON.stringify(data);
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(json);
    }
  });
}
```

## Telegram Integration Example

When a Telegram message arrives, the handler must broadcast to WebSocket clients:

```javascript
// In your Telegram bot handler (e.g., node-telegram-bot-api)
bot.on('message', async (msg) => {
  const userMessage = {
    id: `tg_${msg.message_id}`,
    role: 'user',
    content: msg.text,
    timestamp: new Date().toISOString(),
    channel: 'telegram'
  };

  // 1. Store in database
  await db.insertMessage(userMessage);

  // 2. Broadcast to ALL WebSocket clients (iOS app, web dashboard, etc.)
  broadcast({ type: 'message', message: userMessage });

  // 3. Send typing indicator
  broadcast({ type: 'typing', typing: true });

  // 4. Get Denny's response
  const response = await getDennyResponse(msg.text);

  // 5. Store Denny's reply
  const assistantMessage = {
    id: `tg_reply_${Date.now()}`,
    role: 'assistant',
    content: response,
    timestamp: new Date().toISOString(),
    channel: 'telegram'
  };
  await db.insertMessage(assistantMessage);

  // 6. Broadcast Denny's reply to WebSocket clients
  broadcast({ type: 'message', message: assistantMessage });

  // 7. Send reply back to Telegram
  bot.sendMessage(msg.chat.id, response);
});
```

## Testing

Once implemented, verify with:

```bash
# Quick test with websocat (install: brew install websocat)
websocat -H "Cookie: cc_session=YOUR_TOKEN" ws://100.74.188.28:8765/api/chat/ws

# Or with curl (just tests the upgrade handshake)
curl -i -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  -H "Cookie: cc_session=YOUR_TOKEN" \
  http://100.74.188.28:8765/api/chat/ws
# Should return: HTTP/1.1 101 Switching Protocols
```

The iOS app will detect the WebSocket automatically on next launch — the toolbar subtitle will change from "Polling" (yellow dot) to "WebSocket" (green dot).

## Summary of What's Needed

1. **Install `ws` package** (if not already): `npm install ws`
2. **Add upgrade handler** on your HTTP server for `/api/chat/ws`
3. **Validate `cc_session` cookie** on upgrade
4. **Handle incoming `{"type":"message","content":"..."}` from clients**
5. **Broadcast `{"type":"message","message":{...}}` and `{"type":"typing","typing":bool}` to all connected clients**
6. **Return ALL channels from `/api/chat/history`** — do not filter by channel
7. **Broadcast Telegram messages to WebSocket clients** — when Telegram delivers a message, call `broadcast()` so iOS and web see it in real-time
8. **Forward iOS/web messages to Telegram** — when a message arrives from Command Center, send it to the Telegram chat too
9. **Use consistent roles** — `role: "user"` for all human messages regardless of channel, `role: "assistant"` for all Denny responses
10. **That's it** — the iOS client accepts messages from all channels with zero filtering

---

## Binary File Downloads (NEW)

The iOS app needs to download binary files (MP3, PDF, etc.) that can't be returned as JSON text/base64. The `/api/media/[...path]` endpoint already serves raw files perfectly — we just need the `/api/files/` response to include the download path so the iOS app knows where to fetch from.

### Required: Add `downloadUrl` and `path` fields to `/api/files/{path}?content=true` response

When the file type is binary (not text or image), include the download info in the JSON response:

```json
{
  "type": "binary",
  "content": null,
  "filename": "Fred again.. & Thomas Bangalter (USB002, Original Mix).mp3",
  "size": 8432156,
  "mimeType": "audio/mpeg",
  "downloadUrl": "/api/media/home/bob/.openclaw/workspace/music/Fred again.. & Thomas Bangalter (USB002, Original Mix).mp3",
  "path": "/home/bob/.openclaw/workspace/music/Fred again.. & Thomas Bangalter (USB002, Original Mix).mp3"
}
```

**Implementation** — in the `/api/files/[[...path]]` route handler, when the file isn't text or image:

```javascript
// After resolving the full filesystem path:
const fullPath = resolveFilePath(pathSegments, workspace);
const ext = path.extname(fullPath).toLowerCase();
const binaryTypes = ['.mp3', '.mp4', '.pdf', '.zip', '.gpx', '.wav', '.flac', '.m4a'];

if (binaryTypes.includes(ext)) {
    return Response.json({
        type: 'binary',
        content: null,
        filename: path.basename(fullPath),
        size: fs.statSync(fullPath).size,
        mimeType: getMimeType(ext),
        downloadUrl: `/api/media/${fullPath}`,
        path: fullPath
    });
}
```

**The iOS app then:**
1. Sees `downloadUrl` in the response
2. Fetches `GET /api/media/{path}` (which is already public and returns raw bytes)
3. Saves the raw data directly to the device's Files app

**No new endpoints needed** — just two extra fields in the existing `/api/files/` JSON response.
