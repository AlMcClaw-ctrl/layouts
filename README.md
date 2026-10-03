# Layouts

**Save your window arrangements as presets and restore them with one hotkey.**

A tiny native macOS menu bar app. Arrange your windows once (say Chrome on the left and Claude on the right, or two Claude windows side by side, or Hermes plus Claude), save the arrangement as a preset, and bring it back any time with a hotkey.

<!-- Screenshot: docs/editor.png -->

## Features

- **One-hotkey layouts:** ⌃⌥1 … ⌃⌥9 are assigned automatically, and every shortcut can be changed.
- **Snapshot the current setup:** "Save current layout…" captures your visible windows as a new preset.
- **Visual editor:** a to-scale preview of your display. Drag tiles freely, resize them from the corner, and edges snap magnetically to the screen and to other tiles (hold ⌥ for no snapping). An optional 1/24 grid is available.
- **Align to another window:** "Fill the space next to Chrome", "same size, side by side", "same row".
- **Clears the clutter:** windows that are not part of the preset get minimized (or their apps hidden, or left alone, chosen per preset).
- **Launches what is missing:** apps that aren't running get started. Missing windows are opened through the app's *New Window* menu item, a URL (Chromium browsers open a real new window) or a Terminal command, for example `cd ~/project && claude`.
- **Multiple instances:** apps running more than once with the same bundle ID are handled. For example, Claude running with a personal and a work account counts as two windows of one app.
- **Multi-monitor:** each window belongs to a specific display. Frames are stored relative to the display (0…1), so presets survive resolution changes.
- **Auto-apply on display change:** you can bind a preset to a display combination, for example "MacBook + external monitor". It is applied automatically when that combination is connected.
- **Shortcuts and Spotlight:** the actions "Apply Layout" and "Save Current Layout" are available as App Intents.
- **URL scheme** for Raycast, Alfred, Stream Deck and similar tools:
  - `layouts://apply?name=Coding`
  - `layouts://capture?name=New`
  - `layouts://settings`
- **Plain JSON storage** in `~/Library/Application Support/Layouts/presets.json`. You can edit it by hand or put it under version control.

## Requirements


- macOS 14 Sonoma or later
- **Accessibility** permission, which is required to move other apps' windows. That is also why the app is not sandboxed and not in the App Store.

## Download

1. Download **Layouts-x.y.z.zip** from the [latest release](https://github.com/AlMcClaw-ctrl/layouts/releases/latest), unzip it and move **Layouts.app** to `/Applications`.
2. The app is **not notarized** (no paid Apple Developer account), so macOS blocks it on first launch. Either:
   - open it once, then go to **System Settings → Privacy & Security** and click **Open Anyway**, or
   - remove the quarantine flag in Terminal:
     ```bash
     xattr -dr com.apple.quarantine /Applications/Layouts.app
     ```
3. Grant access in **System Settings → Privacy & Security → Accessibility → Layouts**.

Prefer to build it yourself? See below.

## Build from source

```bash
brew install xcodegen
git clone https://github.com/AlMcClaw-ctrl/layouts.git
cd layouts
xcodegen generate
xcodebuild -project Layouts.xcodeproj -scheme Layouts -configuration Release -derivedDataPath build build
cp -R build/Build/Products/Release/Layouts.app /Applications/
open /Applications/Layouts.app
```

Then grant access in **System Settings → Privacy & Security → Accessibility → Layouts**.

> **Signing tip:** by default the app is signed ad hoc, so anyone can build it without an Apple Developer account. With ad-hoc signing, macOS may ask for the Accessibility permission again after each rebuild. To keep the permission, create `Config/Local.xcconfig` (it is git-ignored) with your team:
> ```
> DEVELOPMENT_TEAM = ABCDE12345
> CODE_SIGN_STYLE = Automatic
> CODE_SIGN_IDENTITY = Apple Development
> ```

## Usage

1. Arrange your windows.
2. Menu bar icon → **Save current layout…**, give it a name, and untick windows you don't want in the preset.
3. Press **⌃⌥1** (or click the preset in the menu).
4. Fine-tune it under **Settings → Presets**: drag the tiles, set what happens with other windows, and set how missing windows are opened.

### presets.json example

```json
{
  "version": 1,
  "presets": [
    {
      "name": "Two Claudes",
      "others": "minimize",
      "slots": [
        { "bundleID": "com.anthropic.claudefordesktop", "match": { "index": 0 },
          "screen": "main", "frame": { "x": 0, "y": 0, "w": 0.5, "h": 1 } },
        { "bundleID": "com.apple.Terminal", "match": { "title": "CC:api" },
          "screen": "main", "frame": { "x": 0.5, "y": 0, "w": 0.5, "h": 1 },
          "launch": { "kind": "terminal", "cwd": "~/code/api", "command": "claude" } }
      ]
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `others` | `minimize` (default), `hide` or `keep`: what happens to windows that are not in the preset |
| `screen` | `main` for the primary display, otherwise a display UUID or display name |
| `frame` | position and size relative to the display's visible area (0…1, origin top left) |
| `match` | which window of the app: `index` (0 = first) and/or `title` (substring). If nothing matches, any free window of that app is used. |
| `launch` | how to open the window if it is missing: `newWindow` (default), `url` with `"url": …`, or `terminal` with `cwd` and `command` |
| `autoScreens` | apply automatically when exactly these displays are connected (set it in the editor) |

## How it works

- Windows are read and moved through the **Accessibility API** (`AXUIElement`).
- AppKit puts the coordinate origin at the bottom left, the Accessibility API at the top left. Layouts converts between them using the primary display.
- Size, position and then size again are set on each window. Otherwise macOS clamps a window that moves across a screen edge. After 300 ms the frame is set a second time, because Electron apps briefly report wrong sizes.
- Window matching runs in three passes: title matches first, then index or any free window, and new windows are opened only as a last resort.

## Limitations

- **Spaces:** there is no public API to move windows between Spaces, so Layouts works on the current Space.
- **Full screen:** windows in native full screen are skipped.
- **Minimum sizes:** some apps enforce a minimum window size and will ignore smaller frames.
- **New windows:** whether "open a new window" works depends on the app having a *New Window* menu item or handling ⌘N.

## Credits

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus, used for the global hotkeys and the shortcut recorder.
- Built in one early morning together with [Claude Code](https://claude.com/claude-code).

## License

[MIT](LICENSE)
