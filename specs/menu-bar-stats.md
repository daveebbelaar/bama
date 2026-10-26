# Menu bar stats

A menu bar item that shows CPU, memory, and network speed as live numbers, with a popover for graphs, disk, battery, and the batteries of Bluetooth devices. Replaces: Stats, iStat Menus. Taken from Onyx.

## Brief

```markdown
# Stats

A menu bar item for Mac users who want CPU, memory, network, disk, and battery at a glance.

## Replaces
Stats, iStat Menus, opening Activity Monitor to check one number

## Main jobs
1. Glance at CPU, memory, and network speed in the menu bar.
2. Click the item for graphs, per-core load, memory pressure, disk space, and battery details.
3. See the battery level of a Magic Keyboard, Mouse, or Trackpad.

## Data
- Sample: date, cpu, cpuUser, cpuSystem, cores, memoryApp, memoryWired, memoryCompressed, memoryTotal, pressure, swapUsed, downRate, upRate, diskFree, diskTotal, battery, bluetooth. In memory only, the last 60.
- BatteryInfo: percent, isCharging, onPower, isCharged, minutesToEmpty, minutesToFull, cycleCount, health, temperature, watts, adapterWatts.
- BluetoothBattery: id (device address), name, percent.
- Settings in UserDefaults: interval, which metrics show in the menu bar, CPU graph.

## Shape
Menu bar extra (NSStatusItem with a popover) plus a Settings window, macOS 26 or later.
LSUIElement, no Dock icon. Local data. Works offline. No accounts.

## System hooks
Menu bar item, launch at login.

## Reference
none

## Look
Native with the system accent. The menu bar text is one template image, so it tints with the menu bar. The popover shows soft cards with small graphs.

## Not in version one
- Storage scanner and cleanup
- Temperature sensors and fan speeds
- Per-app CPU and memory list
```

## How it works

| Part | API | Permission |
| --- | --- | --- |
| CPU, total and per core | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)`, tick deltas | None |
| Memory | `host_statistics64(HOST_VM_INFO64)`, `sysctlbyname("vm.swapusage")`, `kern.memorystatus_vm_pressure_level` | None |
| Network | `getifaddrs`, `if_data.ifi_ibytes` and `ifi_obytes` on `en*` | None |
| Disk | `URL(fileURLWithPath: "/").resourceValues` with `.volumeAvailableCapacityForImportantUsageKey`, `.volumeTotalCapacityKey` | None |
| Battery | `IOPSCopyPowerSourcesInfo`, then the `AppleSmartBattery` registry entry | None |
| Bluetooth batteries | IOKit `BatteryPercent` on HID and Bluetooth services | None |
| Menu bar item | `NSStatusItem` + `NSPopover` (`.transient`) | None |
| Timer | `DispatchSourceTimer` on a `.utility` queue | None |
| Launch at login | `SMAppService.mainApp` ([recipe](../skills/code/os-integrations/recipes.md#launch-at-login)) | User approves once |

Stats needs no system permission. A stats app must sample cheaply: read [performance](../skills/code/performance/SKILL.md), "Timers, polling, and energy".

Types to create:
- `StatsSample`: one reading as a plain struct, plus `memoryUsed` and `memoryFraction`.
- `StatsReader`: reads the counters and keeps the last ticks and byte counts. Touched only on the sampler queue.
- `StatsSampler`: `@MainActor @Observable`. Owns the timer, `latest`, `history` (60), and a set of demand keys.
- `StatsFormat`: every number-to-text rule in one place.
- `StatusItemController` and `MenuBarImage`: the `NSStatusItem`, the popover, and one template `NSImage` per sample.
- `StatsPopoverView` with `CPUCard`, `MemoryCard`, `DiskCard`, `NetworkCard`, `BatteryCard`, `BluetoothCard`.
- `SettingsView`: metric toggles with a live preview, interval, battery details, launch at login.

Behaviors that matter:
- **Interval** 1, 2, or 5 seconds, default 2. One timer reads everything. Leeway is 10% of the interval so macOS can group wake-ups.
- **Baseline.** CPU and network need two readings. The first read only stores counters and is never published. The timer's first fire is 0.5 s after start, not a full interval.
- **Slow values.** Battery and Bluetooth every 10 s, disk every 60 s. Carry the last value into the samples in between.
- **Demand.** The sampler runs while something shows numbers: the menu bar item, the popover, the Settings page. Each adds a key while visible and removes it when gone. No keys left stops the timer. A view counts as visible only while its window's `occlusionState` contains `.visible`. History keeps 60 samples; after a pause longer than 5 intervals, clear it so the old graph is not squeezed against the new one.
- **CPU** is (user + nice + system) / (user + nice + system + idle), summed over all cores. User and system also show on their own.
- **Memory used** is (internal pages minus purgeable pages) + wired + compressed, times the page size. That matches Activity Monitor's "Memory Used". Total is `ProcessInfo.physicalMemory`. Pressure level 1 is normal, 2 warning, 4 critical.
- **Units.** Memory uses `ByteCountFormatter` `.memory`. Disk and rates use `.file` (1000 based). Rates in the menu bar are at most four characters: `0K`, `90K`, `999K`, `1.2M`, `12M`, `1.2G`.
- **Menu bar text.** One template image, 22 pt tall, drawn per sample. A metric is a small label (`CPU`, `MEM`, `BAT` or `CHG`, 7.5 pt semibold) over a value (11 pt monospaced digits). Network is two lines, `↑` and `↓`, at 9.5 pt. Each part's width is the widest of its label, `100%`, and the current value. Rates measure against `999K`, `9.9M`, `99M`, `999M`. So the item never jiggles when numbers change.
- **Defaults:** CPU on, Memory on, Network on, Battery off, CPU graph off. A Mac without a battery leaves the battery part out. With every metric off, show an SF Symbol so the popover stays reachable.
- **Redraw** only when a sample arrives: `withObservationTracking` on `latest`, registered again after each change. The item has no timer of its own. Set an accessibility label like "CPU 12%, memory 61%, download 1.2 MB/s, upload 40 KB/s".
- **Popover**, 340 pt wide: CPU card (60-sample sparkline, user and system, one bar per core with efficiency cores lighter; they come first, count from `hw.perflevel1.logicalcpu`), Memory and Disk side by side, Network (sparkline scaled to the peak, never below 50 KB/s so background chatter stays flat), Battery, Bluetooth. Header buttons open Activity Monitor and Settings. Show "Reading…" until the first sample.

The timer, with the one detail that crashes at run time when missed:

```swift
let timer = DispatchSource.makeTimerSource(queue: queue)        // qos: .utility
timer.schedule(deadline: .now() + 0.5, repeating: interval,
               leeway: .milliseconds(Int(interval * 100)))
timer.setEventHandler { @Sendable in                            // see Gotchas
    let sample = reader.read()
    guard reader.hasBaseline else { return }
    DispatchQueue.main.async {
        MainActor.assumeIsolated { StatsSampler.shared.publish(sample) }
    }
}
timer.resume()
```

## Stories

```markdown
# Stories

## M1 Core loop

### S-001 See CPU, memory, and network in the menu bar
As the user, I glance at the menu bar and read CPU, memory, and network speed.
Screens: menubar-item.png
Acceptance:
- [snap] The item shows CPU and MEM as label over percent, then ↑ and ↓ rates, in light and dark menu bars.
- [unit] `compactRate` gives 0K, 90K, 999K, 1.2M, 12M, 1.2G for matching byte rates.
- [self] Ten samples with changing values keep the image width the same.
Status: todo

### S-002 Open the popover
As the user, I click the item and see the cards; a click outside or on the item closes it.
Screens: popover.png
Depends: S-001
Acceptance:
- [snap] The popover shows CPU with sparkline and core bars, Memory, Disk, and Network cards.
- [manual] Clicking the item while the popover is open closes it and does not open it again.
- [snap] Before the first sample the popover shows "Reading…".
Status: todo

### S-003 Read memory pressure and disk space
As the user, I see memory split into app, wired, and compressed, its pressure, and free disk space.
Screens: popover.png
Depends: S-002
Acceptance:
- [snap] Memory shows a three-part bar, "12 GB of 16 GB", a green, yellow, or red pressure dot, and swap only when in use.
- [snap] Disk shows percent used and "N GB free of N GB".
Status: todo

### S-004 See battery charge and status
As the user, I see charge and time left in the popover, and can add it to the menu bar.
Screens: popover.png, menubar-item.png
Depends: S-002
Acceptance:
- [unit] `batteryStatus` gives "Charging, 1:05 until full", "Fully charged", "On power, not charging", "3:20 left".
- [snap] With Battery on, the menu bar shows BAT or CHG over the percent.
- [manual] On a Mac without a battery, no battery card and no battery part show.
Status: todo

### S-005 Choose what the menu bar shows
As the user, I toggle CPU, Memory, Network, and Battery in Settings and see a live preview.
Screens: settings.png
Depends: S-001
Acceptance:
- [snap] Settings shows the four toggles, a preview of the menu bar item, and "Refresh every" with 1, 2, 5 seconds.
- [self] Turning a metric off removes its part from the item within one sample.
- [self] With all metrics off, the item shows a symbol and still opens the popover.
Status: todo

### S-006 Sample only while numbers are visible
As the user, I trust that Stats costs almost nothing while I am not looking.
Depends: S-002
Acceptance:
- [unit] Removing the last demand key stops the timer; adding one starts it.
- [manual] At the 2 second interval, Activity Monitor shows Stats under 1% CPU.
Status: todo

### S-007 No permission prompts
As the user, I install Stats and it never asks for a permission.
Acceptance:
- [manual] A clean install shows no system prompt, and every card fills in.
Status: todo

## M2 Batteries and details

### S-008 See Bluetooth device batteries
As the user, I see the battery of my Magic Keyboard, Mouse, or Trackpad.
Screens: popover.png, settings.png
Acceptance:
- [snap] A Bluetooth card lists each device with an icon, a bar, and the percent; red at 15% or less.
- [snap] With no devices, Settings says "No connected device reports a battery level right now" and that AirPods do not share theirs.
- [unit] A device found under two IOKit classes shows once.
Status: todo

### S-009 Read battery health in Settings
As the user, I see maximum capacity, cycle count, temperature, power draw, and adapter watts.
Screens: settings.png
Acceptance:
- [snap] Each row shows only when the battery reports it.
- [unit] InstantAmperage stored as unsigned gives a negative watt value while on battery.
Status: todo

### S-010 Add a CPU graph to the menu bar
As the user, I turn on a tiny CPU history next to the CPU percent.
Screens: menubar-item.png
Acceptance:
- [snap] A 24-sample bar graph, one point per bar, draws inside a thin rounded frame.
Status: todo

### S-011 Launch at login
As the user, I turn on "Open at login" in Settings.
Acceptance:
- [manual] After a restart, the item is in the menu bar.
Status: todo

## Dropped
- Storage scanner, "Free up space", and largest files: later, it is its own app.
- Top apps by CPU and memory, helpers counted toward their app (libproc, 2 s, 10 s average): later.
- The System row inside the Onyx menu: Stats is its own menu bar item.
- Ring gauges overview with rolling-number animations.
```

## Gotchas

- **Swift 6 traps at run time on the timer.** In a `@MainActor` class, the closure passed to `DispatchSource.setEventHandler` inherits the main actor. It runs on the stats queue, Swift inserts an executor check, and the app crashes seconds after the item appears. The compiler says nothing. Mark it `{ @Sendable in ... }`.
- **`host_processor_info` allocates.** Free the array with `vm_deallocate` after every read, or memory grows each sample.
- **The counters are 32 bits and wrap.** CPU ticks and `if_data` byte counts roll over (bytes at 4 GB). Subtract with `&-`, which survives one rollover.
- **Count only `en*` interfaces.** VPN tunnels (`utun`) and bridges carry the same bytes again, so the rate doubles with a VPN on. Skip loopback and interfaces that are down.
- **Free disk space is not free to read.** `volumeAvailableCapacityForImportantUsage` can make the system count purgeable files. Read it once a minute, not every sample.
- **Battery fields lie a little.** `kIOPSTimeToEmptyKey` is -1 while macOS works it out: show "On battery", not a time. `Temperature` is in hundredths of a degree. `InstantAmperage` is signed but stored unsigned: read it with `int64Value`. Health is `NominalChargeCapacity` / `DesignCapacity`, capped at 100.
- **Bluetooth batteries live in several places.** Search `AppleDeviceManagementHIDEventService`, `IOBluetoothDevice`, `AppleBluetoothHIDKeyboard`, `BNBMouseDevice`, `BNBTrackpadDevice`. Dedupe by `DeviceAddress`, which comes as a string or as raw bytes. AirPods never publish their level to other apps; say so instead of showing nothing.
- **The transient popover reopens itself.** Clicking the item while the popover is open closes it on mouse down, then the button action opens it again. Ignore clicks within 0.3 s of `popoverDidClose`. Call `NSApp.activate()` before `show`, or outside clicks do not close it.
- **Use `NSStatusItem`, not a second scene.** Onyx found that `@AppStorage` in the `App` struct re-runs the scene on every defaults write, and a status item writes its own defaults when it appears: an endless loop. Keep settings out of the `App` struct.
- **Template image, fixed widths.** Draw text in black on an `NSImage` with `isTemplate = true`; macOS tints it for light, dark, and highlighted bars. Measure every part against its widest possible text, or the item and its neighbors shift on every sample.
Done when the menu bar shows CPU, memory, and network that match Activity Monitor within a few percent, the popover shows every card including battery and Bluetooth, and Stats stays under 1% CPU at the 2 second interval.
