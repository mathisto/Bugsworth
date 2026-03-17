# Bugsworth

All-in-one Lua error handler for WoW 3.3.5a. Merges `!BugGrabber` and `BugSack` into a single addon with SavedVariables-backed log persistence, a two-panel error viewer, per-addon grouping, and export tools.

## What it does

- Hooks `seterrorhandler` to intercept all Lua errors
- Normalizes stack traces with addon names and version detection
- Deduplicates errors per session (strips volatile `Locals:` sections before comparing)
- Groups errors by source addon for quick identification
- Throttles capture at 20 errors/second to prevent runaway loops
- Persists everything to `BugsworthDB` in SavedVariables
- Optionally suppresses the default Blizzard error popup
- Exposes a `BugGrabber`-compatible callback API so other addons that listen for errors still work

## Usage

| Command | Description |
|---|---|
| `/bugs` | Open the error viewer |
| `/bugs count` | Print error summary to chat |
| `/bugs last [N]` | Print the last N errors to chat (default 1) |
| `/bugs clear` | Wipe all stored errors |
| `/bugs config` | Open the settings panel |
| `/bugs export` | Export all errors to `BugsworthExport` SavedVariable |
| `/bugs ignore [addon]` | Ignore errors from a specific addon |
| `/bugs unignore [addon]` | Stop ignoring an addon |
| `/bugs help` | Show all available commands |

## Minimap Button

- **Click** opens the viewer
- **Shift-click** reloads the UI
- **Alt-click** wipes all errors
- **Right-click** opens settings

The icon turns red when errors exist in the current session. A count badge shows the number of unique errors this session.

## Viewer

The viewer uses a two-panel layout:

### Left Panel — Navigation
- **Search bar** at the top filters errors by addon name or message content
- **Addon grouping** shows each addon that has reported errors, sorted by frequency, with total hit counts
- **Accordion** — click an addon name to expand/collapse its error list
- **Error selection** — click an individual error to view its full detail in the right panel
- **Ignore** — right-click an addon name to ignore all its errors (configurable in settings)

### Right Panel — Error Detail
- Full syntax-highlighted error display with color-coded file paths, line numbers, local variables, types, and values
- **Previous/Next** buttons to navigate between errors (Shift+click jumps to first/last)
- **Copy All** button that selects the entire error text and prompts you to press Ctrl+C
- The text area is an edit box, so you can also manually select and copy

### Tabs
- **This Session** (default) — errors from the current login/reload
- **All Bugs** — everything in the database across all sessions
- **Previous** — walk backwards through older sessions

## Settings

Available through `/bugs config` or right-clicking the minimap icon:

- Auto-open viewer on new error
- Chat frame notification on new error
- Mute error sound
- Filter addon action (taint) errors
- Throttle toggle
- Error database size limit (10-1000)
- Suppress default Blizzard error popup
- Ignored addons list with remove buttons

## Per-Addon Ignore List

You can ignore errors from specific addons in three ways:

1. **Right-click** an addon header in the viewer's left panel
2. Use `/bugs ignore AddonName` in chat
3. Manage the list in the settings panel

Ignored addons' errors are hidden from the viewer but not deleted from the database. Remove an ignored addon via the settings panel or `/bugs unignore AddonName`.

## Export

Use `/bugs export` to write all stored errors into the `BugsworthExport` SavedVariable. After exporting, `/reload` to flush the data to disk. The exported file will be at:

```
WTF/Account/<ACCOUNT>/SavedVariables/Bugsworth.lua
```

Look for the `BugsworthExport` variable — it contains a formatted, human-readable error report suitable for pasting into Discord, GitHub issues, etc.

## Log Persistence

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

## File Structure

```
Bugsworth/
  Bugsworth.toc         Table of contents
  core.lua              Error capture engine, dedup, throttle, callbacks, ignore list
  viewer.lua            Two-panel GUI with addon navigation and error detail
  config.lua            Interface Options panel with ignore list management
  minimap.lua           Draggable minimap button with count badge
  Libs/
    LibStub/            Library loader
    CallbackHandler-1.0/  Event callback system
  Media/
    error.wav           Notification sound
    icon.tga            Minimap icon (normal)
    icon_red.tga        Minimap icon (errors present)
```

## Backward Compatibility

The addon sets `_G.BugGrabber` to a shim table that forwards all standard API calls (`GetDB`, `GetSessionId`, `RegisterCallback`, etc.) to the Bugsworth internals. Addons that previously registered for `BugGrabber_BugGrabbed` callbacks will receive `Bugsworth_BugGrabbed` events transparently through the mapping layer.

## Origin

Merged from two community addons and extended with new features:

- **!BugGrabber** r154 (Rabbit) — error handler hook, stack normalization, throttle
- **BugSack** r225 (Rabbit) — GUI viewer, session navigation, syntax highlighting

On top of those foundations, Bugsworth adds:
- SavedVariables-backed log persistence
- Locals-stripping deduplication
- Two-panel viewer with per-addon grouping and accordion navigation
- Search/filter across all errors
- Copy-to-clipboard support
- Per-addon ignore list
- Error export to SavedVariable
- Minimap error count badge
- Auto-suppression of default error popup
- Extended slash commands (`/bugs last`, `/bugs export`, `/bugs ignore`, `/bugs help`)
