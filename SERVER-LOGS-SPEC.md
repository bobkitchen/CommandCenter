# Server-Side Logs API Spec

**For:** Denny
**Date:** 2026-03-20
**Auth:** All endpoints require the `cc_session` cookie (same as every other endpoint). The WebSocket uses the same cookie-based auth as the chat WebSocket.

---

## Sources

| Source key | Description |
|---|---|
| `gateway` | Nginx / gateway process logs |
| `server` | Main Node/Express server logs |
| `all` | Combined stream from all sources |

---

## Endpoints

### `GET /api/logs`

Fetch recent log lines as JSON.

**Query params:**
- `lines` (optional, default `100`) — number of recent lines to return
- `source` (optional, default `all`) — `gateway`, `server`, or `all`

**Request example:**
```
GET /api/logs?lines=200&source=gateway
```

**Response `200`:**
```json
{
  "lines": [
    {
      "timestamp": "2026-03-20T14:30:00Z",
      "level": "info",
      "source": "gateway",
      "message": "Request received: GET /api/tasks"
    },
    {
      "timestamp": "2026-03-20T14:30:01Z",
      "level": "error",
      "source": "gateway",
      "message": "Upstream connection refused"
    }
  ]
}
```

**Log line fields:**

| Field | Type | Notes |
|---|---|---|
| `timestamp` | ISO8601 string | Parsed from log line; use current time if unparseable |
| `level` | string | `debug`, `info`, `warn`, `error` — infer from log line content |
| `source` | string | Which source this line came from |
| `message` | string | The raw log line content |

---

### `WS /api/logs/ws`

WebSocket endpoint for live log tailing.

**Query params:**
- `source` (optional, default `all`) — `gateway`, `server`, or `all`

**Connection example:**
```
ws://server/api/logs/ws?source=all
```

**Auth:** Server should validate the `cc_session` cookie on the upgrade request before accepting the WebSocket connection. Reject with `401` if missing or invalid (same behaviour as the chat WebSocket).

#### Messages: Server → Client

**Log line event:**
```json
{
  "type": "log",
  "line": "[2026-03-20 14:30:00] INFO Request received: GET /api/tasks",
  "source": "gateway",
  "level": "info",
  "timestamp": "2026-03-20T14:30:00Z"
}
```

**Keepalive ping (optional, every 30s):**
```json
{ "type": "ping" }
```

#### Messages: Client → Server

The client does not send any messages. The connection is receive-only. The server should handle unexpected client messages gracefully (ignore or log).

---

## Implementation Notes

### Reading PM2 logs

Two approaches — use whichever is simpler:

**Option A — Read log files directly (recommended):**

PM2 log files are typically at:
- `~/.pm2/logs/<app-name>-out.log` (stdout)
- `~/.pm2/logs/<app-name>-error.log` (stderr)

For `GET /api/logs`: read the last `N` lines with `tail -n <lines> <logfile>`.

For `WS /api/logs/ws`: use `tail -f <logfile>` as a child process and stream each new line to the WebSocket client. Clean up the child process when the client disconnects.

**Option B — Use `pm2 logs --json`:**

```bash
pm2 logs --json --lines 100
```

Output is newline-delimited JSON. Parse and re-emit in the standard response format.

### Level inference

If the log line does not have an explicit level, infer it from content:
- Contains `ERROR` or `error` → `error`
- Contains `WARN` or `warn` → `warn`
- Contains `DEBUG` or `debug` → `debug`
- Otherwise → `info`

### Timestamp parsing

Try to parse a timestamp from the log line. Common formats:
- `[2026-03-20 14:30:00]`
- `2026-03-20T14:30:00.000Z`
- PM2 JSON field `at`

If parsing fails, use the current server time.

### `source=all`

For the REST endpoint, read from all log files, merge, sort by timestamp descending, and return the most recent `N` lines across all sources.

For the WebSocket, start a `tail -f` on each log file and multiplex lines to the single client connection.

### Error responses

- `401` — missing or invalid session cookie
- `400` — invalid `source` value
- `500` — unable to read log files (include `"error"` field in response body)
