# Screenshots

Capture the full screen, an area, or one window with a shortcut, then copy, save, pin, drag
out, or mark it up with arrows, boxes, text, and blur. Replaces: CleanShot X. Taken from Onyx.

## Brief

```markdown
# Shot

A menu bar screenshot tool for people who send a lot of marked-up screenshots.

## Replaces
CleanShot X, Command-Shift-4 plus Preview for markup

## Main jobs
1. Capture the screen, an area, or a window with a shortcut.
2. Copy, save, pin, or drag the capture from a card in the corner, and swipe away the rest.
3. Mark up a capture with arrows, boxes, text, and blur, then copy or save it.

## Data
- Capture: image (full Retina pixels), saved file URL (optional)
- Annotation: tool, start and end (image pixels), color, size, text, blur style and strength
- Settings: shortcuts, copy, save, card, card close time, sound, save folder

## Shape
Menu bar extra plus overlays (picker, corner cards, pinned captures) and one editor window.
macOS 26 or later. Local data. Works offline. No accounts.

## System hooks
Global shortcuts, menu bar item, Screen Recording permission.

## Reference
CleanShot X

## Look
Native, system accent color. Corner cards like CleanShot X's Quick Access Overlay: the
picture edge to edge, and on hover a dark wash with light, readable buttons.

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
| Picker, corner cards, pins | Borderless `NSPanel`, `.nonactivatingPanel` | None |
| Swipe a card away | `NSPanel.sendEvent` override, `.scrollWheel` phases | None |
| Share a capture | SwiftUI `ShareLink` with the file URL | None |
| Blur and pixelate | Core Image `CIFilter.pixellate()`, `gaussianBlur()` | None |

Generic code for shortcuts, panels, and capture: [os-integrations recipes](../skills/code/os-integrations/recipes.md).

Types: `CaptureService`, `SelectionOverlay` (one panel per display), `CaptureThumbnail` (one
card's face and buttons), `CornerCards` (one panel with the column of cards), `CardSwipe` and
`CardSize` (pure swipe and size math, unit tested), `PinnedImage`, `AnnotationDocument` (shapes, undo, render), `AnnotationRenderer` (one shape into a y-down
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
- Card size: the picture's shape, so nothing is cropped. 220 points wide for a landscape picture,
  at most 200 tall, at least 132 x 104. The picture fills the card, 12 point corners.
- Column: one panel in the bottom-left, cards 18 points from the screen edges and 10 apart, 22
  points of margin for shadows. The newest card goes on top. With two or more, the newest has a
  2 point accent ring. When the column would pass the screen height, the oldest card goes.
- Hover: a 50% black wash, Copy and Save chips in the middle, and round buttons in the corners:
  close (top left), pin (top right), annotate (bottom left), share (bottom right). Copy, Save,
  Annotate, and Pin close the card. Drag out the saved file or a temp PNG.
- Right-click: Annotate, Pin to the Screen, Copy, Save, Show in Finder (when saved), Close, Close All.
- Close: after 10 s unless hovered. Settings offers 5 s, 10 s, 30 s, 1 min, and Never.
- Motion: a card slides in from the left edge (spring, response 0.42, damping 0.86). The column
  closes a gap with a spring of response 0.36, damping 0.9.
- Swipe: two fingers toward the edge move the card. It closes past 40% of its width, or on a
  flick of 500 points per second after at least 12 points. A shorter swipe springs back. Toward
  the middle it stretches at most 24 points, slower the farther it goes. Up or down does nothing.
- Pin: a floating panel with the capture at its point size, at most half the screen, centered.
  Drag it anywhere. Hover shows an Unpin button. Right-click: Copy, Annotate, Unpin.
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
As the user, I copy, save, share, or drag out a capture from the card in the corner.
Screens: card, card-hover
Acceptance:
- [snap] Hover shows Copy and Save in the middle and close, pin, annotate, share in the corners; the chips stay readable over a white screenshot.
- [unit] `CardSize.fitting` keeps the picture's shape, 132 to 220 points wide and 104 to 200 tall.
- [manual] Dragging into Finder drops a PNG; the card slides out after 10 s unless hovered.
Status: todo

### S-006 Change shortcuts
As the user, I click a shortcut field in Settings and press a new combination.
Screens: settings-shortcuts
Acceptance:
- [manual] Escape cancels, Delete clears; all shortcuts pause while a field records.
- [snap] A combo another app owns shows "In use by another app" under the field.
Status: todo

### S-007 Choose what happens after a capture
As the user, I turn copy, save, card, and sound on or off, pick when the card closes, and pick a save folder.
Screens: settings-capture
Acceptance:
- [unit] Defaults: copy on, save off, card on, card closes after 10 s, sound on, folder Desktop.
- [snap] The close picker offers 5 s, 10 s, 30 s, 1 min, and Never, and is off while the card is off.
- [self] With save on, the file is `Shot yyyy-MM-dd at HH.mm.ss.png` in the folder.
Status: todo

### S-008 Capture from the menu bar
As the user, I open the menu bar item and pick a capture, Settings, or Quit.
Screens: menu
Acceptance:
- [snap] The menu lists the three captures with their shortcuts, then Settings and Quit.
Status: todo

### S-009 Stack and swipe away cards
As the user, I take several captures in a row and flick the ones I do not need off the screen.
Screens: card-stack
Depends: S-005
Acceptance:
- [snap] The newest card is on top with an accent ring; the older cards stay where they were.
- [unit] `CardSwipe` closes past 40% of the width or on a 500 pt/s flick after 12 pt, springs back otherwise, and ignores an up or down swipe.
- [manual] A two-finger swipe toward the edge flicks the card away at the swipe's speed, and the cards above slide down. Right-click, Close All clears the column.
Status: todo

### S-010 Pin a capture to the screen
As the user, I click pin on a card and the capture floats above every window.
Depends: S-005
Acceptance:
- [manual] The pin shows at its real size (at most half the screen), drags anywhere, and stays when I switch apps.
- [manual] Hover shows Unpin; right-click offers Copy, Annotate, and Unpin.
Status: todo

## M2 Mark up

### S-011 Open a capture in the editor
As the user, I click Annotate on the card and the editor opens with my capture.
Screens: editor-empty
Depends: S-005
Acceptance:
- [snap] Toolbar: Select, Arrow, Rectangle, Text, Blur, eight colors, three sizes, Undo, Redo, Copy, Save.
- [self] Command-S saves a PNG at the capture's pixel size with the annotations on it.
Status: todo

### S-012 Draw arrows and boxes
As the user, I drag with Arrow or Rectangle to draw in the current color and size.
Screens: editor-shapes
Acceptance:
- [snap] Arrows taper from tail to head; boxes have round corners and a soft shadow.
- [unit] The export matches the canvas; color and size per tool are remembered.
- [manual] Select drags a shape, Delete removes it, and Undo restores both (200 steps).
Status: todo

### S-013 Add text
As the user, I click with Text, type, and press Return or click away.
Acceptance:
- [manual] Letter keys go to the text box while typing, not to the tool shortcuts.
- [unit] An empty text box is removed; one edit is one undo step.
Status: todo

### S-014 Blur private parts
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
- The card is never key, so standard buttons draw dimmed. Use custom chip styles with fixed
  colors: white at 84% with black ink at 82%, on a 50% black wash; full white on hover. They sit
  on a picture, so they look the same in light and dark mode.
- Put every card in one panel. A panel per card let the windows cover each other's buttons.
  Bottom-align the column, grow the panel before a new card goes in, and shrink it only after
  the restack animation ends, so the cards already there never move.
- Put the panel's left edge just past the screen edge (`edgeInset - margin`). A card that slides
  out is cut off there and never shows on the next display.
- Insert a new card at its hidden offset, then animate it to 0 one frame (16 ms) later. Otherwise
  its first layout animates from the wrong place.
- A non-key panel gives SwiftUI no clean swipe. Catch `.scrollWheel` in the panel's `sendEvent`
  first. Use only events with `hasPreciseScrollingDeltas` (a trackpad), skip the momentum phase,
  follow `isDirectionInvertedFromDevice`, and lock the axis on the first clear movement.
- Start the fling at the swipe's speed: `.interpolatingSpring(duration: 0.38, bounce: 0.12,
  initialVelocity: velocity / distance)`. Otherwise the card jumps when the fingers lift.
- Resample the picture once to the card's size in pixels, with high quality. It stays sharp on
  Retina and is cheap to draw.
- `ShareLink` needs a file. Write the temp PNG on the first hover of the share button, not for
  every card.
- Blur: `clampedToExtent()` before the filter, flip the rect (Core Image is bottom-up), and draw
  pixelated regions with `interpolationQuality = .none`. Shadows ignore the CTM: scale them by hand.

Done when all three shortcuts capture at full Retina size on every display, the card copies,
saves, pins, and drags out, cards stack and swipe away, and the editor saves a PNG with arrows,
boxes, text, and blur.
