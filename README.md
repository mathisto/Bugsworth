# Bugsworth

All-in-one Lua error handler for WoW 3.3.5a. Merges `!BugGrabber` and `BugSack` into a single addon and extends them with SavedVariables-backed log persistence.

## What it does

- Hooks `seterrorhandler` to intercept all Lua errors
- Normalizes stack traces with addon names and version detection
- Deduplicates errors per session (strips volatile `Locals:` sections before comparing)
- Throttles capture at 20 errors/second to prevent runaway loops
- Persists everything to `BugsworthDB` in SavedVariables
- Exposes a `BugGrabber`-compatible callback API so other addons that listen for errors still work

## Usage

| Command | Description |
|---|---|
| `/bugs` | Open the error viewer |
| `/bugs count` | Print error summary to chat |
| `/bugs clear` | Wipe all stored errors |
| `/bugs config` | Open the settings panel |

The minimap button does the same things: left-click opens the viewer, right-click opens settings, shift-click reloads the UI, alt-click wipes errors. The icon turns red when errors exist in the current session.

## Viewer

The viewer window has three tabs:

- **This Session** (default) — errors from the current login/reload
- **All Bugs** — everything in the database across all sessions
- **Previous** — walk backwards through older sessions

Errors are syntax-highlighted: file paths, line numbers, local variable names, types, and values are color-coded for readability. The text area is an edit box, so you can select and copy error text.

## Settings

Available through `/bugs config` or right-clicking the minimap icon:

- Auto-open viewer on new error
- Chat frame notification on new error
- Mute error sound
- Filter addon action (taint) errors
- Throttle toggle
- Error database size limit (10-1000)

## Log persistence

Errors are stored in WoW's SavedVariables system:

```
WTF/Account/<ACCOUNT>/SavedVariables/Bugsworth.lua
```

This file is written to disk when you **log out**, **exit the game**, or **`/reload`**. If WoW crashes, any errors captured since the last save point will be lost. To force a save at any time, use `/reload`.

The saved file is plain Lua and can be opened in any text editor. The `BugsworthDB.errors` table contains all stored errors with their messages, stack traces, session IDs, timestamps, and hit counts.

### Development note — the double-reload workflow

Because SavedVariables are only flushed on logout or `/reload`, persisting newly triggered errors during development requires **two reloads**:

1. **First `/reload`** — loads your code changes and triggers any new errors.
2. **Second `/reload`** — flushes those captured errors to `BugsworthDB` in SavedVariables so they appear in your logs on the next session.

This is a limitation of the WoW SavedVariables system, not of Bugsworth itself.

## File structure

```
Bugsworth/
  Bugsworth.toc         Table of contents
  core.lua              Error capture engine, dedup, throttle, callbacks
  viewer.lua            Scrollable GUI with session tabs and syntax highlighting
  config.lua            Interface Options panel
  minimap.lua           Draggable minimap button
  Libs/
    LibStub/            Library loader
    CallbackHandler-1.0/  Event callback system
  Media/
    error.wav           Notification sound
    icon.tga            Minimap icon (normal)
    icon_red.tga        Minimap icon (errors present)
```

## Backward compatibility

The addon sets `_G.BugGrabber` to a shim table that forwards all standard API calls (`GetDB`, `GetSessionId`, `RegisterCallback`, etc.) to the Bugsworth internals. Addons that previously registered for `BugGrabber_BugGrabbed` callbacks will receive `Bugsworth_BugGrabbed` events transparently through the mapping layer.

## Origin

Merged from two community addons and extended with new features:

- **!BugGrabber** r154 (Rabbit) — error handler hook, stack normalization, throttle
- **BugSack** r225 (Rabbit) — GUI viewer, session navigation, syntax highlighting

On top of those foundations, Bugsworth adds SavedVariables-backed log persistence, Locals-stripping deduplication, and a streamlined single-addon package.
