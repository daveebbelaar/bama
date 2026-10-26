# Screen recorder

Record the full screen, an area, or one window to MP4, with microphone, system audio, and a
webcam bubble. Replaces: CleanShot X (video), Loom. Taken from Onyx.

## Brief

```markdown
# Rec

A menu bar screen recorder for quick demos and bug reports, saved as MP4 on this Mac.

## Replaces
CleanShot X screen recording, Loom, QuickTime screen recording

## Main jobs
1. Record the screen, an area, or a window to MP4 with a shortcut.
2. Pause, resume, and stop from a small control at the top of the screen.
3. Add microphone, system audio, and a webcam bubble to a recording.

## Data
- Recording: file URL, duration, poster frame
- Settings: shortcuts, fps, codec, pointer, clicks, countdown, audio, mic, camera, bubble frame, folder

## Shape
Menu bar extra plus overlays (picker, countdown, control, corner card, camera bubble).
macOS 26 or later. Local data. Works offline. No accounts.

## System hooks
Global shortcuts, menu bar item, Screen Recording, Microphone, and Camera permissions.

## Reference
CleanShot X

## Look
Native, system accent color. Glass capsule control with a red record dot.

## Not in version one
- Trimming, uploads, and share links
- GIF export
```

## How it works

| Part | API | Permission |
| --- | --- | --- |
| Shortcuts | Carbon `RegisterEventHotKey` | None |
| Menu bar item, no Dock icon | `MenuBarExtra`, `LSUIElement = YES` | None |
| Video stream | `SCStream`, `SCContentFilter`, `SCStreamConfiguration` | Screen Recording |
| Write the MP4 | `SCRecordingOutput` added to the stream | Screen Recording |
| System audio, microphone | `config.capturesAudio`, `config.captureMicrophone` | Screen Recording, Microphone |
| Webcam bubble | `AVCaptureSession` + `AVCaptureVideoPreviewLayer` in an `NSPanel` | Camera |
| Join paused parts | `AVMutableComposition` + passthrough `AVAssetExportSession` | None |

Shortcut and panel code: [os-integrations recipes](../skills/code/os-integrations/recipes.md). The recorder must never stutter
or block the UI: follow the [performance skill](../skills/code/performance/SKILL.md) and [GPU and media recipes](../skills/code/performance/gpu-media.md).

Types: `ScreenRecorder` (`@MainActor @Observable`, phases `idle`, `selecting`, `countdown`,
`recording`, `paused`, `finishing`), `SelectionOverlay` (see-through, returns a rect or window ID),
`RecordingOptions`, `RecordingControl`, `RecordingCountdown`, `AreaOutline`, `CameraBubble`,
`RecordingFiles` (save, join, poster; off the main thread), `RecordingThumbnail`.

Behavior that matters:

- No default shortcuts. The user sets Record Screen, Area, Window, and Stop in Settings.
  A record shortcut pressed while recording stops it.
- Screen takes the display under the pointer. Area and Window open the picker on every display.
- Start order: ask for mic and camera if on, bubble, area outline, countdown, stream, control.
- Defaults: 30 fps, H.264, pointer on, clicks off, countdown on, system audio, mic, camera off.
- Config: `minimumFrameInterval = CMTime(value: 1, timescale: fps)`, `queueDepth = 6`,
  `showsCursor`, `showMouseClicks`, `excludesCurrentProcessAudio = true`.
- Output size: one scale factor so the long side fits 4096 (H.264) or 8192 (HEVC) and the area
  fits 4096 x 2304 or 8192 x 4320 pixels, never above 1, then each side rounded down to even.
- Retina: output is points times `backingScaleFactor`. Windows: `filter.pointPixelScale`,
  `ignoreShadowsSingleWindow = true`. Area: `config.sourceRect` in points, top-left origin,
  relative to the display: `x: rect.minX - screen.frame.minX, y: screen.frame.maxY - rect.maxY`.
- Segments go to the temp folder. On stop they become `Rec Recording yyyy-MM-dd 'at' HH.mm.ss.mp4`
  in the save folder (default Desktop), with ` 2`, ` 3` added if the name exists.
- Control: top center, level `.statusBar`, time every 0.5 s as `00:12` or `1:02:03`, dragged by its time.
- Bubble: Small 140, Medium 200 (default), Large 300, range 96 to 480 points, mirrored. Starts 32 points
  in from the bottom-left, at most 40% of the short side; reuses its last frame. None for windows.
- Card: poster frame at `min(0.5 s, duration / 2)`, max 640 pixels. Copy puts the file URL on the
  pasteboard, Show in Finder selects it, drag the movie out. Hides after 8 s unless hovered.

## Stories

```markdown
# Stories

## M1 Core loop

### S-001 Grant Screen Recording
As the user, I start my first recording and get asked for Screen Recording.
Screens: settings-permissions
Acceptance:
- [manual] `CGRequestScreenCaptureAccess()` runs; if false, System Settings opens at `Privacy_ScreenCapture`.
- [snap] Settings shows Screen Recording, Microphone, and Camera as On or Off, each with an open button.
- [self] While a grant is missing the app checks every 1.5 s; otherwise every 20 s, 10% tolerance.
Status: todo

### S-002 Record the full screen
As the user, I press Record Screen, see 3, 2, 1, and recording starts.
Screens: countdown
Acceptance:
- [self] The MP4 has the display's pixel size, even, scaled down only past the codec limit.
- [manual] Escape cancels the countdown, and the recorded app never gets the Escape.
Status: todo

### S-003 Stop and save
As the user, I click Stop on the capsule or press the shortcut again, and the movie is saved.
Screens: control
Depends: S-002
Acceptance:
- [snap] The capsule shows a pulsing red dot, the time, Pause, and a red Stop button.
- [self] The file plays in QuickTime and has no capsule, countdown, or menu in it.
- [unit] A second file with the same name gets ` 2` added.
Status: todo

### S-004 Record an area
As the user, I press Record Area and drag a rectangle.
Screens: picker-area, area-outline
Acceptance:
- [unit] The source rect for an area on a second display is relative to that display, top-left origin.
- [snap] A dashed white line sits just outside the area while recording.
Status: todo

### S-005 Record a window
As the user, I press Record Window and click a window.
Screens: picker-window
Acceptance:
- [self] The video is the window's size times its display scale, with no shadow.
Status: todo

### S-006 Use the corner card
As the user, I copy the file, show it in Finder, or drag it out from the card.
Screens: card
Acceptance:
- [snap] The card shows the poster frame and the duration.
- [manual] Copy, then Paste in Finder, gives the MP4; dragging into Mail attaches it.
Status: todo

### S-007 Set record shortcuts
As the user, I set shortcuts for Record Screen, Area, Window, and Stop in Settings.
Screens: settings-shortcuts
Acceptance:
- [manual] Escape cancels, Delete clears; all shortcuts pause while a field records.
- [snap] A combo another app owns shows "In use by another app" under the field.
Status: todo

### S-008 Record from the menu bar
As the user, I start a recording from the menu bar item and stop it there.
Screens: menu, menu-recording
Acceptance:
- [snap] Idle: Record Screen, Record Area, Record Window, Settings, Quit.
- [snap] Recording: a red "Recording 00:12" row with Stop at the top.
Status: todo

## M2 Audio, camera, pause

### S-009 Pause and resume
As the user, I click Pause, then Resume, and get one movie without the paused part.
Acceptance:
- [self] Three segments join into one MP4 as long as the three together.
- [manual] The time stops and the dot turns grey while paused.
Status: todo

### S-010 Record audio
As the user, I turn on the mic (and pick a device) or system audio, and the sound is in the video.
Screens: settings-audio
Acceptance:
- [manual] The first recording with the mic on asks for access; when denied it records without and says so.
- [manual] Music from another app is audible with system audio on; the app's own sounds are not.
Status: todo

### S-011 Show the webcam bubble
As the user, I turn on the camera and a round, mirrored bubble shows in my recording.
Screens: bubble
Acceptance:
- [manual] Drag moves it; the rim, pinch, or scroll resizes it; right-click offers Small, Medium, Large, Hide Camera.
- [self] The bubble is in screen and area videos; denied access records without it and says so.
Status: todo

### S-012 Choose video settings
As the user, I pick frame rate, format, pointer, clicks, and countdown in Settings.
Screens: settings-video
Acceptance:
- [unit] Defaults: 30 fps, H.264, pointer on, clicks off, countdown on.
- [self] HEVC is used only if `availableVideoCodecTypes` has it; otherwise H.264.
Status: todo

## Dropped
- GIF export from the card: 10 fps, 640 pixels, first 30 seconds (later)
- Recording Mode, keystroke overlay, cursor highlight, chapter markers
- Usage stats, activity log, debug bridge record commands
```

## Gotchas

- Let `SCRecordingOutput` write the file. The stream still needs an `SCStreamOutput` per type (`.screen`,
  `.audio`, `.microphone`) that drops every sample, or ScreenCaptureKit complains nobody takes frames.
- H.264 tops out near 4096 x 2304, so a 5K display at full Retina size fails. HEVC keeps 5K and 6K.
- Hide the app's panels with `SCContentFilter(display:excludingApplications: [ownApp], exceptingWindows: keep)`,
  `keep` being layer 0 windows plus the bubble. Show the bubble before the stream starts.
- Bump a `session` counter on every start and stop; late callbacks from an older recording check
  it and do nothing. Stop during startup stops that stream and deletes its file.
- Wait for `recordingOutputDidFinishRecording` before moving a segment, or the MP4 is cut short.
  Give up after 5 seconds so stop never hangs.
- Pause removes the recording output; resume adds a new one. Join tracks by media type and index
  (video, system audio, mic) and export with `AVAssetExportPresetPassthrough`. No re-encode.
- During the countdown, register Escape as a temporary Carbon hotkey, so the recorded app never sees it.
- `NSMicrophoneUsageDescription` and `NSCameraUsageDescription` must be in Info.plist before the first
  request, or the app crashes. Ask only when the toggle is on. `AVCaptureSession.startRunning()`
  blocks: call it on a private serial queue.
- Play the done sound with `AudioServicesPlaySystemSound`. `NSSound` froze the main thread for minutes
  right after a recording, while CoreAudio was busy.
- Delegate methods are `nonisolated`: pass only an `ObjectIdentifier` into `Task { @MainActor in ... }`.
  Save and join run in `Task.detached`. Panels are never key, so buttons need custom styles.

Done when screen, area, and window recordings each save as a playable MP4 at full Retina size, with
mic, system audio, and bubble when turned on, and none of the app's own panels in the video.
