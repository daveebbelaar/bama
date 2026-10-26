# GPU and media recipes

For apps that capture, decode, process, or encode video, audio, or large
images. Each recipe: symptom, cause, fix. Numbers are from real
measurements on Apple silicon.

## Contents

- Rules
- Zero-copy GPU input
- Keep the GPU off the capture queue
- Back-pressure without drops
- Bounded caches and pools
- Threads, stacks, autorelease
- Playback
- Reading and encoding
- Overlays and filters
- SwiftUI next to a media engine
- AVFoundation lifetimes
- Measuring media work

## Rules

- One stage per queue: capture, decode, process, encode. Each hands off to
  the next and never waits on it.
- Pixels stay on the GPU. `CVPixelBuffer` and `IOSurface` pass between
  AVFoundation, VideoToolbox, Core Image, and Metal without a copy.
- Every new fast path gets an on-off switch (environment variable or
  default), so you can compare and fall back.
- Prove the output is the same: hashes, `ffmpeg -f framemd5`, or VMAF.

## Zero-copy GPU input

**Symptom:** 65 to 70 percent of a core while recording. `sample` shows
vImage conversion functions.
**Cause:** a pixel format with no hardware conversion path, converted on
the CPU every frame.
**Fix:** one Metal compute pass that reads the capture buffer in place.

```swift
let surface = CVPixelBufferGetIOSurface(pixelBuffer)!.takeUnretainedValue()
let desc = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .rgb10a2Uint, width: bytesPerRow / 4, height: height, mipmapped: false)
desc.usage = .shaderRead
desc.storageMode = .shared
let texture = device.makeTexture(descriptor: desc, iosurface: surface, plane: 0)
```

For formats Core Video knows, use `CVMetalTextureCacheCreateTextureFromImage`.

## Keep the GPU off the capture queue

**Symptom:** the camera drops frames when the GPU is busy.
**Cause:** `makeCommandBuffer` and `commit` blocked for up to 270 ms on the
capture callback queue.
**Fix:** a one-slot mailbox. The capture queue only hands off; a GPU queue
does the work and skips when busy.

```swift
lock.lock()
if busy { skipped += 1; lock.unlock(); return }
busy = true; lock.unlock()
gpuQueue.async { encode(pixelBuffer) }   // the completion handler clears busy
```

## Back-pressure without drops

**Symptom:** frames dropped when the writer is not ready.
**Fix:** a FIFO per track, drained on the writer queue, retried every 3 ms
while `isReadyForMoreMediaData` is false. Copy frames past the first two
into your own pool so capture gets its buffers back. Cap the queue (90
frames is about 3 seconds) and count when you hit the cap. When the queue
empties, call `CVPixelBufferPoolFlush(pool, .excessBuffers)` at most once
a second, or memory stays hundreds of MB higher after a stall.

Give the encoder buffers from its own adaptor pool
(`AVAssetWriterInputPixelBufferAdaptor.pixelBufferPool`).

## Bounded caches and pools

**Symptom:** memory grows from 0.7 GB to 20 GB in 14 minutes.
**Cause:** a texture cached per item with no limit.
**Fix:** evict textures unused for N frames, an LRU cap on images, and
`CVMetalTextureCacheFlush` every 120 frames. Check that rebuilt textures
are pixel-identical.

## Threads, stacks, autorelease

- Long-running media loops on a plain `Thread` need an autorelease pool per
  frame, or memory grows about 40 MB a minute:
  `while autoreleasepool(invoking: { step() }) {}`.
- GCD worker threads have 512 KB stacks. Deep recursion crashes with
  SIGBUS. Use a small pool of `Thread`s with `stackSize = 16 << 20`.

## Playback

**Symptom:** play starts 0.6 to 1.9 s late with `AVPlayer` and a custom
compositor, worse with more tracks.
**Fix:** your own player. The clock is host time
(`frame = anchor + (now - anchorHost) * fps * rate`). Audio
(`AVAudioEngine`) starts at the anchor's host time. Keep 3 frames in flight
on the GPU and 6 ready ahead. Present from a `CADisplayLink`.
**Result:** start went from 1,559 ms to 34 ms.

## Reading and encoding

- `AVAssetReader` on a network share is latency-bound (12 to 16 fps per
  stream). Read byte ranges from `AVSampleCursor` in batches with `pread`
  on two I/O threads, then decode from memory with
  `VTDecompressionSession`. Pool decode sessions (a new one costs 13 to
  17 ms). Result: 322 fps.
- No file system calls per frame. A "pure" planner that checked files on
  each call cost 12 ms per frame. Compute it once.
- `kVTCompressionPropertyKey_PrioritizeEncodingSpeedOverQuality`: HEVC
  went from 108 to 182 fps at the same quality score.
- Two parallel encode sessions gave 1.04x. Three gave 0.77x. Measure
  before you parallelize the encoder.
- Write to a network volume through a local file: write locally, copy to
  `.partial`, check the size, rename.

## Overlays and filters

- Prepare overlays for frame n+2 on worker threads while frame n renders.
- Blend only the rectangle that has content.
- A large Gaussian blur is expensive (3.1 ms a frame). A radial gradient
  fill gave the same look in 0.85 ms.
- Core Image runs blurs on its own serial queue. Parallel copies do not help.
- Exact colors in Core Image: `CIContext(options: [.workingColorSpace: NSNull(),
  .outputColorSpace: NSNull(), .cacheIntermediates: false,
  .workingFormat: CIFormat.RGBAf])`.

## SwiftUI next to a media engine

- A per-frame value on a model that 74 views observe cost 36 to 39 ms per
  frame. Move it to its own small object (see the `improve-architecture`
  skill, architecture.md).
- Scopes and meters: set `CALayer.contents` inside one `CATransaction`.
  Keep static parts as constant views. Refresh text at 2 Hz.
- Never build a publisher inside `body` and pass it to `.onReceive`. It
  resubscribes forever.

## AVFoundation lifetimes

- Keep every `AVURLAsset` that went into an `AVMutableComposition` alive,
  or you get errors -11800 and -12780.
- Image generators call back on the main queue. Never block the main queue
  with a semaphore while you wait for them.
- `CARenderer` needs `CATransaction.flush()` and draws y-up.

## Measuring media work

- A headless `--selftest N` that processes N frames and prints counters:
  drops, timestamp gaps, max queue depth, fallbacks, ms per stage.
- Read memory inside the process with
  `task_info(TASK_VM_INFO).phys_footprint`. `vmmap`, `sample`, and
  `footprint` pause the process.
- Release builds only. One analyzer took 190 ms per frame in debug and
  2.5 ms in release.
- One benchmark at a time, and write down the background load. Another
  process at 1,100 percent CPU caused drops that looked like an app bug.
