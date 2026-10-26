---
name: app-icon
description: Liquid Glass macOS app icon made as an Icon Composer file (Icon/AppIcon.icon, JSON plus SVG layers), compiled with actool, and reviewed in every look with ictool. Use when the user wants an app icon, a better icon, or a Dock icon.
allowed-tools: Bash(tools/make_icon.sh) Bash(tools/icon_review.sh) Bash(./build.sh *) Read Edit Write
---

# App icon

The icon is an Icon Composer file in git: `Icon/AppIcon.icon`, a folder
with `icon.json` and SVG layers in `Assets/`. You write both by hand.
macOS adds the glass, the highlights, the shadow, the mask, and the dark,
tinted, and clear looks. You never draw those yourself.

- `tools/make_icon.sh` compiles it with `actool` into `Resources/Assets.car`
  and `Resources/AppIcon.icns`. `build.sh` runs it when the icon changed.
- `tools/icon_review.sh` renders it with `ictool` (Icon Composer's command
  line tool, inside Xcode) into one contact sheet you read.

Older app without these files: copy `Icon/`, `tools/make_icon.sh`,
`tools/icon_review.sh`, and `tools/icon_sheet.swift` from the
`new-mac-app` template, the icon block of its `build.sh`, and
`CFBundleIconName` = `AppIcon` from its `Info.plist.in`.

Other cases: [more-cases.md](more-cases.md).
- An Xcode or XcodeGen project (Xcode compiles the `.icon` itself).
- Converting an existing flat icon into layers.
- A Dock icon that changes with a theme or style. `NSApp.applicationIconImage`
  shows a flat picture, so render glass versions ahead of time.

## The file

```text
Icon/AppIcon.icon/
  icon.json
  Assets/front.svg     1024 x 1024 canvas, same as the icon
  Assets/back.svg
```

```json
{
  "fill" : { "automatic-gradient" : "srgb:0.20000,0.42000,0.96000,1.00000" },
  "groups" : [
    {
      "layers" : [
        { "glass" : true, "image-name" : "front.svg", "name" : "front" },
        { "glass" : true, "image-name" : "back.svg", "name" : "back", "opacity" : 0.6 }
      ],
      "shadow" : { "kind" : "neutral", "opacity" : 0.5 },
      "translucency" : { "enabled" : true, "value" : 0.5 }
    }
  ],
  "supported-platforms" : { "squares" : [ "macOS" ] }
}
```

- `fill` is the background: `solid`, `automatic-gradient` (one color, the
  system adds a soft gradient), or `linear-gradient` with two colors.
  Colors are `srgb:r,g,b,a` or `display-p3:r,g,b,a`.
- The first layer in the list sits on top.
- Shadow `kind`: `neutral`, `layer-color`, or `none`.
- A different look per appearance goes in `<key>-specializations`, for
  example `fill-specializations` with an entry for `dark`.
- The art fills the whole square. Never draw the rounded square, a margin,
  a shadow, or a sheen: the system adds them.

## What makes it look like Apple made it

1. One idea. One object that says what the app does: a check for tasks, a
   stack of cards for a reader, a waveform for audio.
2. No text, no letters, no screenshots of the UI.
3. The glyph is your own drawing. Never use an SF Symbol, or a shape that
   looks like one: the SF Symbols license forbids symbols in app icons.
4. Two or three layers, each one flat shape in white or one tint. Glass
   gives the depth. Put the main shape on top, a softer one behind it.
5. The glyph is large: about 45 to 55 percent of the canvas width. Thin
   parts vanish at 16 px.
6. Filled shapes only. A stroke on an open path leaves a faint glass line.
7. One background hue. `automatic-gradient` looks right almost every time.
8. Distinct from the apps next to it in the Dock. List Dock apps without a
   screenshot: `defaults read com.apple.dock persistent-apps | grep file-label`.

## Steps

1. Read `docs/BRIEF.md`. Write three icon concepts in one line each: the
   object, the background color, the layers. Pick one with the user, or
   pick the one that is easiest to recognize at 16 px.

   Check: one concept is chosen and it uses no SF Symbol.

2. Write the layers as SVG files in `Icon/AppIcon.icon/Assets/`, on a
   1024 x 1024 canvas, white filled shapes (`rect` with `rx`, `circle`,
   `path`). Write `icon.json` to list them. Delete layer files you no
   longer use.

   Check: every `image-name` in `icon.json` has a file in `Assets/`.

3. Compile:

   ```bash
   tools/make_icon.sh
   # wrote Resources/Assets.car and Resources/AppIcon.icns
   ```

   Check: the line above prints. On an error, fix the file it names.

4. Review every look:

   ```bash
   tools/icon_review.sh
   # wrote /tmp/<AppName>-icon.png
   ```

   Read the PNG. It shows Default, Dark, Tinted, and Clear at 256 pt, then
   Default at 32 and 16 pt. The glyph reads in every look and is still
   recognizable at 16 pt. If not, make it bigger, bolder, or simpler.

5. Iterate two or three times. Change one thing per round: glyph size,
   layer opacity, background color.

6. Install and look at the Dock:

   ```bash
   ./build.sh --open
   ```

   If the Dock still shows the old icon, macOS cached it. Run
   `touch ~/Applications/<AppName>.app` and restart the app. As a last
   resort, `killall Dock`.

The user can fine-tune the file by hand in Icon Composer:
`open -a "Icon Composer" Icon/AppIcon.icon`. Run `tools/make_icon.sh`
after they save.

## Gotchas

- The folder must be named `AppIcon.icon`. With another name, `actool`
  writes nothing and still exits 0. `make_icon.sh` checks for that.
- A missing layer file: `actool` fails with the name, but `ictool` exits 0
  and renders an empty background. Compile before you review.
- PDF layers do not render. Use SVG or PNG.
- `xcrun ictool` is a different tool. Icon Composer's `ictool` lives at
  `$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool`.
- The icon needs `CFBundleIconName` = `AppIcon` in `Info.plist` and
  `Assets.car` in `Contents/Resources`. `AppIcon.icns` covers older Finder
  views and macOS 15.

Done when `tools/make_icon.sh` succeeds, the contact sheet shows a clear
glyph in all four looks and at 16 pt, the icon uses no SF Symbol, and the
Dock shows the new icon.
