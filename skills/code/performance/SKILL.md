---
name: performance
description: Make a macOS app fast by measuring hangs, stutter, CPU, memory, and energy, then moving work off the main thread and onto the GPU. Use when the app freezes, a shortcut feels slow, dragging stutters, the fan spins, memory grows, or the user asks to optimize or profile.
---

# Performance

Fast means two numbers: the first frame after a key press shows in under
100 ms, and nothing on the main thread blocks for more than 50 ms. Every
change in this skill starts and ends with a **measurement**, so you know it
helped. Symptom-by-symptom fixes are in [recipes.md](recipes.md). For
video, audio, camera, Metal, or large image pipelines, also read
[gpu-media.md](gpu-media.md).

## The loop

```text
reproduce -> measure (release build) -> find the line -> fix -> measure again -> commit with the numbers
```

1. **Reproduce.** Write the exact steps, or add a probe command to the
   debug bridge (`test-mac-app` skill) that runs the slow action and logs
   the time of each step.
2. **Measure the release build.** Debug Swift is 3 to 10 times slower and
   points at the wrong code.
3. **Find the line.** Pick the tool for the symptom:

   | Symptom | Tool |
   | --- | --- |
   | App freezes, spinning pointer | `sample <App> 5`, then read the main thread stack |
   | Slow action | Time Profiler: `xcrun xctrace record --template 'Time Profiler' --attach <App> --time-limit 10s` |
   | Short freezes while typing or dragging | `--template 'Hangs'` |
   | Stutter while moving or animating | `--template 'Animation Hitches'` |
   | Memory grows | `footprint <App>`, `leaks <App>`, `--template 'Allocations'` |
   | Fan, battery | `--template 'Energy Log'`, look for timers and polling |

   Read traces as text, not in the Instruments GUI: see "Measuring" in
   [recipes.md](recipes.md). Delete every `.trace` after reading. A trace
   stores the app's full environment, and an app opened from an agent's
   shell inherits that shell's tokens. Never commit or share one.

4. **Fix** with the matching recipe.
5. **Measure again** with the same steps. Put before and after in the
   commit message: "Picker opens in 40 ms, was 600 ms".

## The rules that fix most problems

- **Main thread does UI only.** File, network, database, image decoding,
  Accessibility calls, and audio go elsewhere. A main-thread call that waits
  on another process (CoreAudio, AX) can freeze the app for minutes.
- **Show first, work after.** Put the window or panel on screen in the same
  frame as the key press, then load. Never make the UI wait for the work.
- **Let the GPU composite.** Large images go in a `CALayer` once. Pointer
  movement changes only small layers. Never redraw a full-screen picture per
  mouse event.
- **Decode at display size.** ImageIO thumbnails, cached in `NSCache`.
- **Do not animate what must be fast.** Search results and switchers
  update in place.
- **No polling without a reason.** Timers get a tolerance and stop when
  nothing on screen needs them.

## Apple silicon notes

- Core Animation, Core Image (one shared `CIContext`), Vision, and
  AVFoundation already run on the GPU or the Neural Engine. Hand them the
  work instead of looping over pixels in Swift.
- Write Metal (`MTKView`, compute shaders) only when a measurement shows
  Core Animation or Core Image is too slow. Most apps never need it.
- Unified memory means a `CGImage` from ScreenCaptureKit passes to a layer
  without a copy. Keep it as a `CGImage` or `IOSurface`. Converting to
  `NSImage` and back costs copies.

Done when the slow action has a measured before and after, the after meets
the two numbers at the top, and the commit message names both.
