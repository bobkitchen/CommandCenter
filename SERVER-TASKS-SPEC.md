# Server-Side Tasks / Kanban API Spec

**For:** Denny
**Date:** 2026-03-20
**Auth:** All endpoints require the `cc_session` cookie (same as every other endpoint).

---

## Storage

Simple JSON file — no database needed.

**Path:** `data/tasks.json`

```json
{
  "tasks": [
    {
      "id": "task_abc123",
      "title": "Fix login timeout",
      "description": "Auth tokens expire too quickly",
      "status": "in_progress",
      "priority": "high",
      "tags": ["bug", "auth"],
      "createdAt": "2026-03-20T10:00:00Z",
      "updatedAt": "2026-03-20T14:30:00Z",
      "assignee": "denny"
    }
  ]
}
```

---

## Task Schema

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | auto | `task_` + nanoid/uuid fragment |
| `title` | string | yes | |
| `description` | string | no | |
| `status` | string | yes | `backlog`, `to_do`, `in_progress`, `review`, `done` |
| `priority` | string | no | `low`, `medium`, `high`, `critical` |
| `tags` | string[] | no | |
| `assignee` | string | no | |
| `createdAt` | ISO8601 string | auto | Set on creation |
| `updatedAt` | ISO8601 string | auto | Set on creation and every update |

---

## Endpoints

### `GET /api/tasks`

List all tasks. Optionally filter by status.

**Query params:**
- `status` (optional) — comma-separated list, e.g. `?status=todo,in_progress`

**Response `200`:**
```json
{
  "tasks": [
    {
      "id": "task_abc123",
      "title": "Fix login timeout",
      "description": "Auth tokens expire too quickly",
      "status": "in_progress",
      "priority": "high",
      "tags": ["bug", "auth"],
      "createdAt": "2026-03-20T10:00:00Z",
      "updatedAt": "2026-03-20T14:30:00Z",
      "assignee": "denny"
    }
  ]
}
```

---

### `POST /api/tasks`

Create a new task.

**Request body:**
```json
{
  "title": "Fix login timeout",
  "description": "Auth tokens expire too quickly",
  "status": "to_do",
  "priority": "high",
  "tags": ["bug", "auth"],
  "assignee": "denny"
}
```

- `title` and `status` are required; all others optional.
- Server sets `id`, `createdAt`, `updatedAt`.

**Response `201`:** The created task object (full schema above).

**Error `400`:** `{ "error": "title and status are required" }`

---

### `PUT /api/tasks/:id`

Update an existing task. Used for drag-and-drop status changes and field edits.

All fields are optional — only supply what changed.

**Request body (example — status change only):**
```json
{ "status": "done" }
```

**Request body (example — full edit):**
```json
{
  "title": "Fix login timeout (critical)",
  "description": "Updated description",
  "status": "in_progress",
  "priority": "critical",
  "tags": ["bug", "auth", "urgent"],
  "assignee": "bob"
}
```

Server updates `updatedAt` automatically.

**Response `200`:** The updated task object.

**Error `404`:** `{ "error": "Task not found" }`

---

### `DELETE /api/tasks/:id`

Delete a task by ID.

**Response `200`:** `{ "ok": true }`

**Error `404`:** `{ "error": "Task not found" }`

---

### `GET /api/tasks/columns`

Return the ordered column configuration. This lets the client know the canonical column names and order without hardcoding them.

**Response `200`:**
```json
{
  "columns": ["Backlog", "To Do", "In Progress", "Review", "Done"]
}
```

> **Note:** The display names map to status values by lowercasing and replacing spaces with underscores:
> `"To Do"` → `"to_do"`, `"In Progress"` → `"in_progress"`, etc.

---

## Implementation Notes

- Load `data/tasks.json` on startup; write it back after every mutation.
- Generate IDs with `task_` + a short random string (8 chars is fine).
- `GET /api/tasks/columns` can be a hardcoded response — no need to persist column config unless you want to make it editable later.
- Return `401` for any request missing a valid `cc_session` cookie (consistent with other endpoints).
- Keep reads/writes synchronous within a request to avoid race conditions on the JSON file, or use a simple mutex/queue.
