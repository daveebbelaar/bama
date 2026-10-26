# Screenshots

Capture the full screen, an area, or one window with a shortcut, then copy, save, drag
out, or mark it up with arrows, boxes, text, and blur. Replaces: CleanShot X. Taken from Onyx.

## Brief

```markdown
# Shot

A menu bar screenshot tool for people who send a lot of marked-up screenshots.

## Replaces
CleanShot X, Command-Shift-4 plus Preview for markup

## Main jobs
1. Capture the screen, an area, or a window with a shortcut.
2. Copy, save, or drag the capture from a card in the corner.
3. Mark up a capture with arrows, boxes, text, and blur, then copy or save it.

## Data
- Capture: image (full Retina pixels), saved file URL (optional)
- Annotation: tool, start and end (image pixels), color, size, text, blur style and strength
- Settings: shortcuts, copy, save, card, sound, save folder

## Shape
Menu bar extra plus overlays (picker, corner card) and one editor window.
macOS 26 or later. Local data. Works offline. No accounts.

## System hooks
Global shortcuts, menu bar item, Screen Recording permission.

## Reference
CleanShot X

## Look
Native, system accent color. Liquid Glass corner card with dark, readable buttons.

## Not in version one
- Scrolling capture, timed capture, cloud upload
- OCR copy text, ellipse, step counter, highlighter, resize handles
```

## How it works

| Part | API | Permission |
| --- | --- | --- |
| Shortcuts | Carbon `RegisterEventHotKey` | None |
| Menu bar item, no Dock icon | `MenuBarExtra`, `LSUIElement = YES` | None |
| Capture a display | `SCShareableContent` + `SCScreenshotManager.captureImage` | Screen Recording |
| Capture a window | `SCContentFilter(desktopIndependentWindow:)` | Screen Recording |
| Window under the pointer | `CGWindowListCopyWindowInfo`, layer 0, on screen | None |
| Picker and corner card | Borderless `NSPanel`, `.nonactivatingPanel` | None |
| Blur and pixelate | Core Image `CIFilter.pixellate()`, `gaussianBlur()` | None |

Generic code for shortcuts, panels, and capture: [os-integrations recipes](../skills/code/os-integrations/recipes.md).

Types: `CaptureService`, `SelectionOverlay` (one panel per display), `CaptureThumbnail`,
`AnnotationDocument` (shapes, undo, render), `AnnotationRenderer` (one shape into a y-down
`CGContext`, for canvas and export), `AnnotationBlur` (cached filtered pixels), `AnnotationEditor`
(window, key monitor), `Permissions`, `HotkeyCenter`, `ShortcutField`, `SettingsView`.

Behavior that matters:

- Shortcuts: Command-Option-Shift-3 screen (the display under the pointer), -4 area, -5 window.
- Area and window open the picker on every display. Drag for an area, click for a window,
  Space switches mode, Escape or right-click cancels. A drag under 4 x 4 points is a click.
- The picker shows first, see-through, then freezes. All displays are captured at once and each
  picker shows its own picture when it lands. The size label shows pixels, not points.
- Retina: `config.width = display.width * screen.backingScaleFactor` (same for height),
  `captureResolution = .best`, `showsCursor = false`. Windows: `filter.pointPixelScale`,
  `ignoreShadowsSingleWindow = true`. Crop an area from the frozen picture in pixels:
  `scale = frozen.width / bounds.width`, and flip y with `bounds.height - rect.maxY`.
- After a capture: copy (on), save (off), card (on), sound (on). Folder: Desktop. File name:
  `Shot yyyy-MM-dd 'at' HH.mm.ss.png`.
- Card: 252 points wide, 16:9 picture, 6 point inset, 18 points from the bottom-left. Hides after
  8 s unless hovered. Hover: Copy, Save, Annotate, Close. Drag out the saved file or a temp PNG.
- Editor: fits the image in 85% of the screen, min 1000 x 320 points. Shapes use image pixels, top-left
  origin. Sizes in points times the capture scale: arrow 3, 5, 8; box 2, 3.5, 6; text 14, 20, 30.
- Palette: red `#FF3B30` (default), orange, yellow, green, blue, violet, white, black.
- Keys: `V` select, `A` arrow, `R` box, `T` text, `B` blur, `1` to `8` color, `[` `]` size,
  Command-Z, Shift-Command-Z, Command-C copy, Command-S save, Delete removes the selection.
- Blur: pixelate at 70% by default. Strongest block `max(longSide / 60, 24 * scale)` pixels,
  strongest radius `max(longSide / 50, 26 * scale)`. Undo keeps 200 steps of shape arrays.

## Stories

```markdown
# Stories

## M1 Core loop

### S-001 Grant Screen Recording
As the user, I press a capture shortcut for the first time and get asked for Screen Recording.
Screens: settings-permissions
Acceptance:
- [manual] `CGRequestScreenCaptureAccess()` runs; if it returns false, System Settings opens at `Privacy_ScreenCapture`.
- [snap] Settings shows Screen Recording Off with an Open System Settings button, and On once granted.
- [self] While missing, the app checks every 1.5 s; otherwise every 20 s with a 10% tolerance.
Status: todo

### S-002 Capture the full screen
As the user, I press Command-Option-Shift-3 and the screen under the pointer is copied.
Acceptance:
- [self] The image is the display's size in pixels, without the app's own panels or the open menu.
- [manual] The shutter sound plays and the PNG pastes into Mail.
Status: todo

### S-003 Capture an area
As the user, I press Command-Option-Shift-4 and drag a rectangle.
Screens: picker-area
Acceptance:
- [snap] The screen dims except the selection, which has a white border and a pixel size label.
- [manual] A drag released before the freeze still captures; Escape returns me to my app.
Status: todo

### S-004 Capture a window
As the user, I press Command-Option-Shift-5 and click a window.
Screens: picker-window
Acceptance:
- [snap] The window under the pointer gets an accent tint and border.
- [self] The image has no shadow and is the window's size times its display scale.
Status: todo

### S-005 Use the corner card
As the user, I copy, save, or drag out a capture from the card in the corner.
Screens: card, card-hover
Acceptance:
- [snap] Hover shows Copy and Save; white text stays readable over a white screenshot.
- [manual] Dragging into Finder drops a PNG; the card hides after 8 s unless hovered.
Status: todo

### S-006 Change shortcuts
As the user, I click a shortcut field in Settings and press a new combination.
Screens: settings-shortcuts
Acceptance:
- [manual] Escape cancels, Delete clears; all shortcuts pause while a field records.
- [snap] A combo another app owns shows "In use by another app" under the field.
Status: todo

### S-007 Choose what happens after a capture
As the user, I turn copy, save, card, and sound on or off and pick a save folder.
Screens: settings-capture
Acceptance:
- [unit] Defaults: copy on, save off, card on, sound on, folder Desktop.
- [self] With save on, the file is `Shot yyyy-MM-dd at HH.mm.ss.png` in the folder.
Status: todo

### S-008 Capture from the menu bar
As the user, I open the menu bar item and pick a capture, Settings, or Quit.
Screens: menu
Acceptance:
- [snap] The menu lists the three captures with their shortcuts, then Settings and Quit.
Status: todo

## M2 Mark up

### S-009 Open a capture in the editor
As the user, I click Annotate on the card and the editor opens with my capture.
Screens: editor-empty
Depends: S-005
Acceptance:
- [snap] Toolbar: Select, Arrow, Rectangle, Text, Blur, eight colors, three sizes, Undo, Redo, Copy, Save.
- [self] Command-S saves a PNG at the capture's pixel size with the annotations on it.
Status: todo

### S-010 Draw arrows and boxes
As the user, I drag with Arrow or Rectangle to draw in the current color and size.
Screens: editor-shapes
Acceptance:
- [snap] Arrows taper from tail to head; boxes have round corners and a soft shadow.
- [unit] The export matches the canvas; color and size per tool are remembered.
- [manual] Select drags a shape, Delete removes it, and Undo restores both (200 steps).
Status: todo

### S-011 Add text
As the user, I click with Text, type, and press Return or click away.
Acceptance:
- [manual] Letter keys go to the text box while typing, not to the tool shortcuts.
- [unit] An empty text box is removed; one edit is one undo step.
Status: todo

### S-012 Blur private parts
As the user, I drag with Blur over anything private and set its style and strength.
Screens: editor-blur
Acceptance:
- [snap] Pixelate at 70% by default; Pixelate or Blur and a 1 to 100% slider in the toolbar.
- [unit] A new box stays selected, and its edges never fade to transparent in the export.
Status: todo

## Dropped
- Ellipse, step counter, highlighter, resize handles (later)
- OCR copy text and word snapping (later, Vision `RecognizeTextRequest`)
- Usage stats, activity log, debug bridge capture commands
```

## Gotchas

- Show the picker first, capture after, or the shortcut feels slow. A mouse-up before the
  picture lands is kept and runs when `freeze` is called.
- Keep the picker out of its own screenshot: `sharingType = .none` until the freeze, and
  `SCContentFilter(display:excludingApplications: [ownApp], exceptingWindows: ownLayer0Windows)`.
- Activate the app only after every display is frozen. Activation pulled Settings or the editor
  to the front, into the screenshot. Call `makeKey()` on the picker again in `didBecomeActiveNotification`.
- On close, activate the previous app first, then `orderOut` the picker on
  `didActivateApplicationNotification` or after 0.25 s. Closing first flashed the app's windows.
- Draw the picker with `CALayer`s and no implicit actions. Redrawing a 5K picture per mouse move
  dropped frames. Set the image once; moves change only the dim path, border, and label.
- `CGWindowListCopyWindowInfo` bounds are global, top-left origin. Flip with
  `NSScreen.screens[0]` height, then subtract the overlay screen's origin, or a second display is off.
- Copying a 5K PNG blocks. Encode on a background queue; give TIFF lazily with `NSPasteboardItemDataProvider`.
- Play the shutter with `AudioServicesPlaySystemSound` and the system "Screen Capture.aif".
  `NSSound` blocked the main thread for minutes while CoreAudio was busy.
- The card is never key, so standard buttons draw dimmed. Use custom styles with a dark fill and
  white text; hover makes fills darker, never lighter, or they vanish over a bright picture.
- Blur: `clampedToExtent()` before the filter, flip the rect (Core Image is bottom-up), and draw
  pixelated regions with `interpolationQuality = .none`. Shadows ignore the CTM: scale them by hand.

Done when all three shortcuts capture at full Retina size on every display, the card copies,
saves, and drags out, and the editor saves a PNG with arrows, boxes, text, and blur.
