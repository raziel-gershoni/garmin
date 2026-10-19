# Venu 4 Hebrew Face Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the Hebrew watch face and the glance's detail view to the Venu 4 41 mm (`venu441mm`). The face is a round analog design: the Hebrew date and parasha curve along the rim, six ring subdials carry Material Design icons, and the always-on layout is dimmed. The Instinct 3 build must keep working unchanged.

**Architecture:**
- **Projects:** one face project and one glance project serve both watches.
- **Device split:** jungle device-family qualifiers decide which folders compile for which watch. `semioctagon.*` adds Instinct-only folders; `round.*` adds Venu-only folders.
- **Shared code:** calendar, sun, parasha, slots and settings stay in `common/source`, `face/source` and `glance/source`.
- **Venu-only code:** small modules in `face/source-round` and `common/source-round`: dial, rings, ring data, round text and the view.

**Tech Stack:** Connect IQ SDK 9.2.0, Monkey C, API level ≥ 4.2.0 (the Venu runs 6.0.3). Vector fonts: Noto Sans Hebrew, Roboto. Node 20 with `@mdi/svg`, `@resvg/resvg-js` and `pngjs` for the icon assets.

**Spec:** `docs/superpowers/specs/2026-10-19-venu-face-design.md`. Read it before starting. The spec has the look (sizes, colours, angles) and this plan has the code.

## Global Constraints

### Environment and commands

Every shell needs:
```sh
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export PATH="/opt/homebrew/opt/openjdk@17/bin:$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")bin:$PATH"
K=/Users/razielgershoni/.connectiq/developer_key.der
```

Build and test, run from inside `face/` or `glance/`:
```sh
monkeyc -d <device> -f monkey.jungle -o bin/test-<device>.prg -y $K -t 2>&1 | grep -v "annotation will be ignored" | tail -3
monkeydo bin/test-<device>.prg <device> -t 2>&1 | grep -E "ERROR|FAIL|PASS|Ran|passed"
```
- A build failed unless its output contains `BUILD SUCCESSFUL`. Pipes hide monkeyc's exit status, so always check for that text.
- Devices: `instinct3solar45mm` and `venu441mm`.
- A single test: `monkeydo bin/x.prg <device> -t <testName>`.

### Simulator rules

The tests run inside the Connect IQ simulator, which the user also looks at.
- Run one `monkeydo` at a time.
- **Never kill `monkeydo`, its java process, or the simulator.** Killing them wedges the simulator.
- If a test run produces no output for 5 minutes, stop and report. The coordinator restarts the simulator.

### Project rules

- **Instinct regression gate:** `instinct3solar45mm` must keep passing everything it passes today: face 16 tests, glance 9 tests at plan start. Run both suites on both devices at the end of every task that touches shared or Instinct code.
- `minApiLevel` stays `4.2.0`. Guard API 5+ calls with `has`, e.g. `System has :getDisplayMode`.
- **Hebrew strings** stay in logical order in code:
  - geresh is `׳` (U+05F3) and gershayim `״` (U+05F4); use `HebrewFormat.GERESH`/`GERSHAYIM`.
  - Only `RoundText.visual()` reverses text, and only for `drawRadialText`.
  - Straight text gets right-to-left reordering from the firmware.
  - Mixed Hebrew+digit text is drawn as two pieces (`RoundText.drawPair`).
- **Venu sizes** are written for 390 px and scaled as `px * width / 390`, where `width = dc.getWidth()` or `System.getDeviceSettings().screenWidth`.
- **Colours** (from the spec):
  - Awake: date white; parasha and accent `0xFFAA00`; Gregorian `0xBBBBBB`; ring track `0x2A2A2A`; values white.
  - Always-on: date `0x9A9A9A`; parasha `0x9A7A30`; Gregorian `0x7A7A7A`; track `0x262626`; values `0x8C8C8C`; icons and arcs at 45% of their colour; hands outline `0xC8C8C8`.
- **Code style:** match the existing code: module-per-file, `import Toybox.X;` at the top, a short comment above each module and function saying what it is for, no dead code.
- **Commits:**
  - Commit after each task. Message style: a short imperative summary, then a blank line, then why.
  - End every message with these two lines:
    ```
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
    Claude-Session: https://claude.ai/code/session_01PH3Xcskp5dQWmBEt2yyvgD
    ```
  - Never commit `bin/`, `*.prg`, `*.der`, `*.pem` or `node_modules/` (already in `.gitignore`).
- Do not push. The coordinator pushes after the user sees the result.

## Review Focus

1. **A missing reading** (no HR yet, no Body Battery data, complication returns null) should show `--` in the ring, never crash. → Task 6 test `ringDataGivesTextForEveryType`.
2. **Low battery** should show the low-level icon in red. → Task 6 test `batteryIconAndColorFollowLevel`.
3. **A slot set to "Empty"** should draw no ring, and holding that spot should do nothing. → Task 7 render test (all types incl. NONE) and Task 8 test `holdOnRingTargetsItsComplication`.
4. **The Hebrew day changes at sunset or midnight while the face sits in always-on** (cached rim lines). The new date must appear, and switching awake ↔ always-on must swap fonts. → Task 7 test `rimLinesFollowTheDayAndTheMode`.
5. **Steps above the daily goal** should show a full ring, not overflow. → Task 6 test `progressIsClamped`.

---

## File Structure

```
common/source/Today.mc                    NEW  today's civil/Hebrew date with sunset rollover (all views)
common/source-instinct/DateBand.mc        MOVED from common/source (Instinct geometry)
common/resources-instinct/drawables/      MOVED from common/resources/drawables (Instinct band dither)
common/source-round/RoundText.mc          NEW  vector fonts, rim text (reversed), two-piece pairs
face/monkey.jungle, glance/monkey.jungle  MODIFIED family qualifiers
face/manifest.xml, glance/manifest.xml    MODIFIED add venu441mm
face/source/HebrewFaceApp.mc              MODIFIED getInitialView -> FaceViews.initial()
face/source/WatchSun.mc                   NEW  watch's own sunrise/sunset via complications
face/source/Slots.mc                      MODIFIED available()/next() (no Solar on AMOLED)
face/source/SettingsMenu.mc               MODIFIED no theme on AMOLED, cycle with Slots.next()
face/source-instinct/HebrewFaceView.mc    MOVED (+ uses Today/WatchSun)
face/source-instinct/Layout.mc            MOVED
face/source-instinct/FaceViews.mc         NEW  [HebrewFaceView]
face/resources-instinct/fonts/            MOVED from face/resources/fonts (1-bit icon font)
face/source-round/FaceViews.mc            NEW  [HebrewFaceView, RingPressDelegate]
face/source-round/HebrewFaceView.mc       NEW  the Venu face
face/source-round/Dial.mc                 NEW  ticks, hands, hub, burn-in shift
face/source-round/Rings.mc                NEW  ring geometry, hit test, drawing
face/source-round/RingData.mc             NEW  value/progress/icon/colour per slot type
face/source-round/RingPressDelegate.mc    NEW  hold a ring -> native view
face/resources-round/drawables/           NEW  28 px MDI icon PNGs + drawables.xml
face/resources-round/strings/strings.xml  NEW  slot titles for the round layout
face/test/RenderTests.mc                  MODIFIED device-sized dc, Slots.next()
face/test-instinct/LayoutTests.mc         MOVED from face/test
face/test-round/RoundLayoutTests.mc       NEW
face/test-round/RoundRenderTests.mc       NEW
glance/source/HebrewDay.mc                MODIFIED now() uses Today
glance/source-instinct/DetailView.mc      MOVED
glance/source-round/DetailView.mc         NEW
glance/test/RenderTests.mc                MODIFIED device-sized dc
tools/build-icons.mjs, tools/package.json NEW/MODIFIED icon assets
tools/LICENSE-mdi.txt                     NEW  icon licence
tools/make_assets.py                      MODIFIED output paths of Instinct assets
README.md, docs/...spec                   MODIFIED Venu sections
```

---

### Task 1: Split the projects by device family and add the Venu target

**Files:**
- Move (git mv): `face/source/HebrewFaceView.mc` → `face/source-instinct/HebrewFaceView.mc`; `face/source/Layout.mc` → `face/source-instinct/Layout.mc`; `face/test/LayoutTests.mc` → `face/test-instinct/LayoutTests.mc`; `common/source/DateBand.mc` → `common/source-instinct/DateBand.mc`; `common/resources/drawables` → `common/resources-instinct/drawables`; `face/resources/fonts` → `face/resources-instinct/fonts`; `glance/source/DetailView.mc` → `glance/source-instinct/DetailView.mc`
- Create: `face/source-instinct/FaceViews.mc`, `face/source-round/FaceViews.mc`, `face/source-round/HebrewFaceView.mc` (stub), `glance/source-round/DetailView.mc` (stub)
- Modify: `face/monkey.jungle`, `glance/monkey.jungle`, `face/manifest.xml`, `glance/manifest.xml`, `face/source/HebrewFaceApp.mc`, `face/test/RenderTests.mc`, `glance/test/RenderTests.mc`, `tools/make_assets.py`

**Interfaces:**
- Produces: `FaceViews.initial() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates]`, one per family. The class names `HebrewFaceView` (face) and `DetailView` (glance) exist in both families. `FaceTestSupport.screenDc() as Dc` is a device-sized offscreen dc for shared face tests.

- [ ] **Step 1: Move the Instinct-only files**

```sh
cd /Users/razielgershoni/development/garmin
mkdir -p face/source-instinct face/test-instinct face/source-round face/test-round common/source-instinct common/source-round glance/source-instinct glance/source-round face/resources-instinct common/resources-instinct
git mv face/source/HebrewFaceView.mc face/source-instinct/HebrewFaceView.mc
git mv face/source/Layout.mc face/source-instinct/Layout.mc
git mv face/test/LayoutTests.mc face/test-instinct/LayoutTests.mc
git mv common/source/DateBand.mc common/source-instinct/DateBand.mc
git mv common/resources/drawables common/resources-instinct/drawables
git mv face/resources/fonts face/resources-instinct/fonts
git mv glance/source/DetailView.mc glance/source-instinct/DetailView.mc
rmdir common/resources 2>/dev/null || true
```

- [ ] **Step 2: Jungles with family qualifiers**

`face/monkey.jungle` (whole file):
```
project.manifest = manifest.xml
base.sourcePath = source;test;../common/source;../common/test
base.resourcePath = resources
semioctagon.sourcePath = $(semioctagon.sourcePath);source-instinct;test-instinct;../common/source-instinct
semioctagon.resourcePath = $(semioctagon.resourcePath);resources-instinct;../common/resources-instinct
round.sourcePath = $(round.sourcePath);source-round;test-round;../common/source-round
round.resourcePath = $(round.resourcePath);resources-round
```

`glance/monkey.jungle` (whole file):
```
project.manifest = manifest.xml
base.sourcePath = source;test;../common/source;../common/test
base.resourcePath = resources
semioctagon.sourcePath = $(semioctagon.sourcePath);source-instinct;../common/source-instinct
semioctagon.resourcePath = $(semioctagon.resourcePath);../common/resources-instinct
round.sourcePath = $(round.sourcePath);source-round;../common/source-round
```

The `round`/`semioctagon` qualifiers were verified in a scratch build: a broken file in `source-round` fails only the Venu build, and one in `source-instinct` only the Instinct build.

- [ ] **Step 3: Add the Venu to both manifests**

In `face/manifest.xml` and `glance/manifest.xml`, inside `<iq:products>`, after the Instinct line:
```xml
            <iq:product id="venu441mm"/>
```

- [ ] **Step 4: Per-family initial views**

`face/source-instinct/FaceViews.mc`:
```monkeyc
import Toybox.Lang;
import Toybox.WatchUi;

// The face's initial view on the Instinct (no touch, so no delegate).
module FaceViews {

    function initial() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new HebrewFaceView()];
    }
}
```

`face/source-round/FaceViews.mc` (Task 8 adds the delegate):
```monkeyc
import Toybox.Lang;
import Toybox.WatchUi;

// The face's initial view on the Venu.
module FaceViews {

    function initial() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new HebrewFaceView()];
    }
}
```

In `face/source/HebrewFaceApp.mc`, replace the body of `getInitialView`:
```monkeyc
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        Parasha.scheduleSync(true);
        return FaceViews.initial();
    }
```

- [ ] **Step 5: Round stubs so the Venu build compiles (replaced in Tasks 7 and 10)**

`face/source-round/HebrewFaceView.mc`:
```monkeyc
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Venu face (stub until the round layout lands).
class HebrewFaceView extends WatchUi.WatchFace {

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
    }
}
```

`glance/source-round/DetailView.mc`:
```monkeyc
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Venu detail view (stub until the round layout lands).
class DetailView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
    }
}
```

- [ ] **Step 6: Device-sized dcs in the shared render tests**

In `face/test/RenderTests.mc`, add at the top after the imports (also add `import Toybox.Graphics;` and `import Toybox.System;`):
```monkeyc
(:test)
module FaceTestSupport {
    // Offscreen dc the size of the device's screen.
    function screenDc() as Dc {
        var s = System.getDeviceSettings();
        var ref = Graphics.createBufferedBitmap({:width => s.screenWidth, :height => s.screenHeight});
        return (ref.get() as BufferedBitmap).getDc();
    }
}
```
and replace `LayoutTestSupport.offscreenDc()` with `FaceTestSupport.screenDc()` in `faceRendersEverySlotTypeAndTheme`.

In `glance/test/RenderTests.mc`, in `glanceAndDetailRender`, replace `GlanceTestSupport.dc(176, 176)` with:
```monkeyc
GlanceTestSupport.dc(System.getDeviceSettings().screenWidth, System.getDeviceSettings().screenHeight)
```
(add `import Toybox.System;`).

- [ ] **Step 7: Instinct asset paths in tools/make_assets.py**

Replace `ROOT / "face" / "resources" / "fonts"` with `ROOT / "face" / "resources-instinct" / "fonts"`, and `ROOT / "common" / "resources" / "drawables" / "band.png"` with `ROOT / "common" / "resources-instinct" / "drawables" / "band.png"`.

- [ ] **Step 8: Build and test both devices**

Run the Global Constraints commands in `face/` and `glance/` for both devices.

Expected:
- `instinct3solar45mm`: face `Ran 16 tests ... PASSED`, glance `Ran 9 tests ... PASSED`.
- `venu441mm`: both build (a launcher-icon scaling warning is fine), and all tests compiled for it pass. These are the common tests plus the shared render/settings tests.

- [ ] **Step 9: Commit**

```sh
git add -A face glance common tools
git commit -m "Split face and glance by device family; add Venu 4 41mm target

Instinct-only layout code and assets move to *-instinct folders selected by the
semioctagon jungle qualifier; round folders hold the Venu code (stubs for now).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PH3Xcskp5dQWmBEt2yyvgD"
```

---

### Task 2: Shared "today" with sunset rollover, and the watch's own sun times

**Files:**
- Create: `common/source/Today.mc`, `face/source/WatchSun.mc`
- Modify: `face/source-instinct/HebrewFaceView.mc` (use them), `glance/source/HebrewDay.mc` (`now()`), `common/test/CommonTests.mc`

**Interfaces:**
- Produces:
  - `Today.at(now as Time.Moment, fromWatch as Array?) as Array` returns `[Gregorian.Info (FORMAT_SHORT), civilRd as Number, sun as Array<Number>?, hebrewRd as Number]`.
  - `Today.hebrewRd(civilRd as Number, secs as Number, sun as Array<Number>?) as Number`.
  - `WatchSun.get() as Array?` returns `[sunrise, sunset]` seconds, either may be null, or null without the Complications API.

- [ ] **Step 1: Failing test** (append to `common/test/CommonTests.mc`)

```monkeyc
// After sunset the Hebrew date is the next day's; without sun times it never rolls over.
(:test)
function todayRollsOverAtSunset(logger as Logger) as Boolean {
    var sun = [6 * 3600, 17 * 3600];
    return Today.hebrewRd(1000, 12 * 3600, sun) == 1000
        && Today.hebrewRd(1000, 17 * 3600, sun) == 1001
        && Today.hebrewRd(1000, 23 * 3600, null) == 1000;
}
```

- [ ] **Step 2: Run it.** In `face/`, build and run tests for `instinct3solar45mm`. Expected: build ERROR `Undefined symbol ':Today'`.

- [ ] **Step 3: Implement**

`common/source/Today.mc`:
```monkeyc
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Today's dates for every view: the civil date, sunrise/sunset, and the Hebrew date, which
// rolls over at sunset.
(:glance)
module Today {

    // [info (FORMAT_SHORT), civilRd, sun, hebrewRd] for the moment now. fromWatch: the watch's own
    // [sunrise, sunset] (watch faces only, see WatchSun) or null.
    function at(now as Time.Moment, fromWatch as Array?) as Array {
        var t = Gregorian.info(now, Time.FORMAT_SHORT);
        var civilRd = HebrewCalendar.fixedFromGregorian(t.year as Number, t.month as Number, t.day as Number);
        var sun = SunTimes.today(civilRd, fromWatch);
        var secs = (t.hour as Number) * 3600 + (t.min as Number) * 60 + (t.sec as Number);
        return [t, civilRd, sun, hebrewRd(civilRd, secs, sun)];
    }

    // secs: seconds since local midnight.
    function hebrewRd(civilRd as Number, secs as Number, sun as Array<Number>?) as Number {
        return civilRd + ((sun != null && secs >= sun[1]) ? 1 : 0);
    }
}
```

`face/source/WatchSun.mc` (moved logic from the Instinct view's `sunFromWatch`/`complicationValue`):
```monkeyc
import Toybox.Complications;
import Toybox.Lang;

// The watch's own sunrise/sunset (GPS-based), when it publishes them as complications.
// Watch faces only.
module WatchSun {

    // [sunrise, sunset] in seconds since local midnight; either may be null.
    function get() as Array? {
        if (!(Toybox has :Complications)) {
            return null;
        }
        return [value(Complications.COMPLICATION_TYPE_SUNRISE), value(Complications.COMPLICATION_TYPE_SUNSET)];
    }

    function value(type as Complications.Type) as Number? {
        try {
            var v = Complications.getComplication(new Complications.Id(type)).value;
            return v instanceof Number ? v : null;
        } catch (e) {
            return null;
        }
    }
}
```

In `face/source-instinct/HebrewFaceView.mc`:
- Replace the five lines from `var now = Time.now();` through `var hebrewRd = ...;` in `onUpdate` with:
```monkeyc
        var day = Today.at(Time.now(), WatchSun.get());
        var t = day[0] as Gregorian.Info;
        var sun = day[2] as Array<Number>?;
        var hebrewRd = day[3] as Number;
```
- Delete the methods `sunFromWatch()` and `complicationValue()`.
- Delete `import Toybox.Complications;` if nothing else uses it.

In `glance/source/HebrewDay.mc`, replace the body of `now()`:
```monkeyc
    function now() as Array {
        var day = Today.at(Time.now(), null);
        return [HebrewCalendar.fromFixed(day[3] as Number), day[3], day[2]];
    }
```
and drop imports it no longer uses (`Toybox.Time.Gregorian`).

- [ ] **Step 4: Run tests on both devices, face and glance.** Expected: Instinct face 17 (16 + the new one), glance 10, all PASSED. Venu: all PASSED.

- [ ] **Step 5: Commit** — "Share today's date and sunset rollover across views". Add the trailer lines from Global Constraints.

---

### Task 3: Material Design icon assets for the Venu

**Files:**
- Create: `tools/build-icons.mjs`, `tools/LICENSE-mdi.txt`, `face/resources-round/drawables/drawables.xml`, `face/resources-round/strings/strings.xml`
- Generated (committed): `face/resources-round/drawables/icon_*.png`
- Modify: `tools/package.json`

**Interfaces:**
- Produces resource ids: `Rez.Drawables.IconHeart`, `IconBattery`, `IconBattery80`, `IconBattery50`, `IconBattery20`, `IconSteps`, `IconAltitude`, `IconSunrise`, `IconSunset`, `IconBodyBattery`, `IconNotifications`, `IconCalories`. All are 28×28 white-on-transparent and must be drawn with `drawBitmap2(..., {:tintColor => c})`. Also the round slot-title strings.

- [ ] **Step 1: Dependencies**

```sh
cd tools && npm install @mdi/svg@7.4.47 @resvg/resvg-js@2.6.2 pngjs@7.0.0 && cd ..
cp tools/node_modules/@mdi/svg/LICENSE tools/LICENSE-mdi.txt
```
`package.json` gains the three dependencies; commit both `package.json` and `package-lock.json`.

- [ ] **Step 2: The script** `tools/build-icons.mjs`

```js
// Renders the Venu ring icons from Material Design Icons (Pictogrammers, see LICENSE-mdi.txt)
// as white anti-aliased PNGs on transparent, for drawBitmap2 with :tintColor.
// Usage: cd tools && node build-icons.mjs
import { Resvg } from '@resvg/resvg-js';
import { PNG } from 'pngjs';
import fs from 'node:fs';
import path from 'node:path';

const here = path.dirname(new URL(import.meta.url).pathname);
const svgDir = path.join(here, 'node_modules/@mdi/svg/svg');
const out = path.join(here, '../face/resources-round/drawables');
const SIZE = 28; // Venu 4 41 mm; the 45 mm would use 32
// file name -> MDI icon
const ICONS = {
  icon_heart: 'heart',
  icon_battery: 'battery',
  icon_battery80: 'battery-80',
  icon_battery50: 'battery-50',
  icon_battery20: 'battery-20',
  icon_steps: 'shoe-print',
  icon_altitude: 'image-filter-hdr',
  icon_sunrise: 'weather-sunset-up',
  icon_sunset: 'weather-sunset-down',
  icon_bodybattery: 'lightning-bolt',
  icon_notifications: 'bell',
  icon_calories: 'fire',
};

fs.mkdirSync(out, { recursive: true });
for (const [name, mdi] of Object.entries(ICONS)) {
  const svg = fs.readFileSync(path.join(svgDir, mdi + '.svg'), 'utf8').replace('<path ', '<path fill="#FFFFFF" ');
  const png = PNG.sync.read(Buffer.from(new Resvg(svg, { fitTo: { mode: 'width', value: SIZE } }).render().asPng()));
  for (let i = 0; i < png.data.length; i += 4) {
    png.data[i] = png.data[i + 1] = png.data[i + 2] = 255; // white; coverage stays in alpha
  }
  if (png.width !== SIZE || png.height !== SIZE) throw new Error(`${mdi}: ${png.width}x${png.height}`);
  fs.writeFileSync(path.join(out, name + '.png'), PNG.sync.write(png));
}
console.log(`wrote ${Object.keys(ICONS).length} icons to ${out}`);
```

Run: `cd tools && node build-icons.mjs && cd ..`. Expected: `wrote 12 icons to .../face/resources-round/drawables`.

- [ ] **Step 3: Resources**

`face/resources-round/drawables/drawables.xml`. `automaticPalette="false"` is required: tinting a palettized bitmap throws "Source must not use a color palette".
```xml
<drawables>
    <!-- Material Design Icons (tools/build-icons.mjs, tools/LICENSE-mdi.txt), white on transparent, tinted when drawn -->
    <bitmap id="IconHeart" filename="icon_heart.png" automaticPalette="false"/>
    <bitmap id="IconBattery" filename="icon_battery.png" automaticPalette="false"/>
    <bitmap id="IconBattery80" filename="icon_battery80.png" automaticPalette="false"/>
    <bitmap id="IconBattery50" filename="icon_battery50.png" automaticPalette="false"/>
    <bitmap id="IconBattery20" filename="icon_battery20.png" automaticPalette="false"/>
    <bitmap id="IconSteps" filename="icon_steps.png" automaticPalette="false"/>
    <bitmap id="IconAltitude" filename="icon_altitude.png" automaticPalette="false"/>
    <bitmap id="IconSunrise" filename="icon_sunrise.png" automaticPalette="false"/>
    <bitmap id="IconSunset" filename="icon_sunset.png" automaticPalette="false"/>
    <bitmap id="IconBodyBattery" filename="icon_bodybattery.png" automaticPalette="false"/>
    <bitmap id="IconNotifications" filename="icon_notifications.png" automaticPalette="false"/>
    <bitmap id="IconCalories" filename="icon_calories.png" automaticPalette="false"/>
</drawables>
```

`face/resources-round/strings/strings.xml` overrides the Instinct positions in the slot titles. Family resource folders override by id.
```xml
<strings>
    <string id="Slot1Title">Slot 1 (upper left)</string>
    <string id="Slot2Title">Slot 2 (upper right)</string>
    <string id="Slot3Title">Slot 3 (left)</string>
    <string id="Slot4Title">Slot 4 (right)</string>
    <string id="Slot5Title">Slot 5 (lower left)</string>
    <string id="Slot6Title">Slot 6 (lower right)</string>
</strings>
```

- [ ] **Step 4: Verify.** Build the face for `venu441mm`. Expected `BUILD SUCCESSFUL` with no palette warnings. Build for `instinct3solar45mm` too (unaffected).

- [ ] **Step 5: Commit** — "Add Material Design ring icons for the Venu" (body: the source, the licence, why `automaticPalette` is off). Add the trailer lines.

---

### Task 4: RoundText — vector fonts, rim lines and two-piece pairs

**Files:**
- Create: `common/source-round/RoundText.mc`, `face/test-round/RoundLayoutTests.mc`

**Interfaces:**
- Produces:
  - `RoundText.font(face as String, size as Number, width as Number) as Graphics.VectorFont`: size at 390 px, cached.
  - `RoundText.visual(text as String) as String`.
  - `RoundText.rimRadius(width as Number) as Number` and `RoundText.rimMaxLength(width as Number) as Number`.
  - `RoundText.dateOptions(hdate as Array<Number>) as Array<Array>` and `RoundText.titleOptions(title as String) as Array<Array>`: `[text, size]` pairs.
  - `RoundText.fitRim(dc as Dc, options as Array<Array>, width as Number, low as Boolean) as Array`: returns `[visualText, font]`.
  - `RoundText.drawRim(dc, cx, cy, width, line, top as Boolean)`.
  - `RoundText.drawPair(dc, cx, y, hebrew, hebrewFont, other, otherFont, gap)`.
  - Constants `RIM_DEGREES = 64`, `BOLD`, `REGULAR`.
  - `RoundTestSupport.screenDc() as Dc`, test-only.

- [ ] **Step 1: Failing tests** in `face/test-round/RoundLayoutTests.mc`

```monkeyc
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Test;

(:test)
module RoundTestSupport {
    // Offscreen dc the size of the Venu screen.
    function screenDc() as Dc {
        var s = System.getDeviceSettings();
        var ref = Graphics.createBufferedBitmap({:width => s.screenWidth, :height => s.screenHeight});
        return (ref.get() as BufferedBitmap).getDc();
    }

    // Every date of a Hebrew year fits the top rim, awake and always-on; only Adar I/II dates may
    // lose the month's geresh.
    function yearFitsTopRim(logger as Logger, year as Number) as Boolean {
        var dc = screenDc();
        var w = dc.getWidth();
        var max = RoundText.rimMaxLength(w);
        var failures = 0;
        var end = HebrewCalendar.newYear(year + 1);
        for (var rd = HebrewCalendar.newYear(year); rd < end; rd++) {
            var h = HebrewCalendar.fromFixed(rd);
            for (var low = 0; low <= 1; low++) {
                var line = RoundText.fitRim(dc, RoundText.dateOptions(h), w, low == 1);
                var logical = RoundText.visual(line[0] as String);
                var compacted = !logical.equals(HebrewFormat.full(h));
                if (dc.getTextWidthInPixels(line[0] as String, line[1]) > max || (compacted && h[1] < HebrewCalendar.ADAR)) {
                    logger.error(HebrewFormat.full(h) + " -> " + logical);
                    failures++;
                }
            }
        }
        return failures == 0;
    }
}

(:test)
function rimTextReversesIntoVisualOrder(logger as Logger) as Boolean {
    return RoundText.visual("אבג ד״ה").equals("ה״ד גבא") && RoundText.visual("").equals("");
}

// 5787 is a leap year (Adar I/II), 5788 a common year, 5798 a leap year with the widest year letters.
(:test)
function datesOf5787FitTopRim(logger as Logger) as Boolean {
    return RoundTestSupport.yearFitsTopRim(logger, 5787);
}

(:test)
function datesOf5788FitTopRim(logger as Logger) as Boolean {
    return RoundTestSupport.yearFitsTopRim(logger, 5788);
}

(:test)
function datesOf5798FitTopRim(logger as Logger) as Boolean {
    return RoundTestSupport.yearFitsTopRim(logger, 5798);
}

// Every parasha and holiday-Shabbat title (Israel) fits the bottom rim, awake and always-on.
(:test)
function titlesFitBottomRim(logger as Logger) as Boolean {
    var dc = RoundTestSupport.screenDc();
    var w = dc.getWidth();
    var max = RoundText.rimMaxLength(w);
    var titles = TitleFixtures.TITLES.slice(0, null);
    titles.addAll(["פרשת אחרי מות־קדושים", "פרשת תזריע־מצורע", "פרשת בהר־בחוקותי"]);
    var failures = 0;
    for (var i = 0; i < titles.size(); i++) {
        for (var low = 0; low <= 1; low++) {
            var line = RoundText.fitRim(dc, RoundText.titleOptions(titles[i]), w, low == 1);
            if (dc.getTextWidthInPixels(line[0] as String, line[1]) > max) {
                logger.error(titles[i] + " does not fit");
                failures++;
            }
        }
    }
    return failures == 0;
}
```

- [ ] **Step 2: Run on `venu441mm`.** Expected: build ERROR, undefined `RoundText`.

- [ ] **Step 3: Implement** `common/source-round/RoundText.mc`

```monkeyc
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.StringUtil;

// Text on the round Venu screen, shared by the face and the glance's detail view.
// - Rim lines: drawRadialText lays characters out in typing order with no right-to-left
//   reordering (checked in the Venu 4 simulator), so rim strings are reversed into visual order.
//   They are pure Hebrew: no digits or brackets that would need their own direction.
// - Pairs: a Hebrew word with digits beside it ("ב׳ 19.10", "זריחה 06:44"), drawn as two
//   pieces because Noto Sans Hebrew has no digits.
// Sizes are for the 390 px Venu 4 41 mm and scale with the screen width.
module RoundText {

    const BOLD = "NotoSansHebrewBold";
    const REGULAR = "NotoSansHebrewRegular";
    const RIM_INSET = 44;     // baseline radius = screen radius - inset
    const RIM_DEGREES = 64;   // arc a rim line may cover, centred on 12 or 6 o'clock (clear of the rings)
    const SIZES = [32, 28, 26, 24, 22];

    var _fonts = {} as Dictionary<String, Graphics.VectorFont>;

    // A vector font by face (with Roboto as the fallback face) at a 390 px size; cached.
    function font(face as String, size as Number, width as Number) as Graphics.VectorFont {
        var px = size * width / 390;
        var key = face + px;
        var f = _fonts[key];
        if (f == null) {
            f = Graphics.getVectorFont({:face => [face, "RobotoRegular"], :size => px}) as Graphics.VectorFont;
            _fonts[key] = f;
        }
        return f;
    }

    // Pure Hebrew in visual (left-to-right) order, for drawRadialText.
    function visual(text as String) as String {
        var chars = text.toCharArray();
        var n = chars.size();
        for (var i = 0; i < n / 2; i++) {
            var t = chars[i];
            chars[i] = chars[n - 1 - i];
            chars[n - 1 - i] = t;
        }
        return StringUtil.charArrayToString(chars);
    }

    function rimRadius(width as Number) as Number {
        return width / 2 - RIM_INSET * width / 390;
    }

    // Longest text (px) a rim line may have.
    function rimMaxLength(width as Number) as Number {
        return (rimRadius(width) * RIM_DEGREES * Math.PI / 180).toNumber();
    }

    // [text, size] options for the full Hebrew date: the full text at every size, then, for
    // leap-year Adar, without the month's geresh.
    function dateOptions(hdate as Array<Number>) as Array<Array> {
        var dayMonth = HebrewFormat.dayMonth(hdate);
        var year = HebrewFormat.year(hdate);
        var options = sized(dayMonth + " " + year, SIZES);
        if (dayMonth.substring(dayMonth.length() - 1, dayMonth.length()).equals(HebrewFormat.GERESH)) {
            options.addAll(sized(dayMonth.substring(0, dayMonth.length() - 1) + " " + year, [24, 22]));
        }
        return options;
    }

    // [text, size] options for a parasha or holiday: the full title at full size, then (as the
    // spec says) without "פרשת " before the font steps down.
    function titleOptions(title as String) as Array<Array> {
        if (title.find("פרשת ") != 0) {
            return sized(title, SIZES);
        }
        var options = sized(title, [SIZES[0]]);
        options.addAll(sized(title.substring(5, title.length()), SIZES));
        return options;
    }

    function sized(text as String, sizes as Array<Number>) as Array<Array> {
        var out = [] as Array<Array>;
        for (var i = 0; i < sizes.size(); i++) {
            out.add([text, sizes[i]]);
        }
        return out;
    }

    // [visualText, font] for the first option that fits the rim arc; the last option otherwise.
    // low: always-on, which uses the thinner face.
    function fitRim(dc as Dc, options as Array<Array>, width as Number, low as Boolean) as Array {
        var max = rimMaxLength(width);
        var face = low ? REGULAR : BOLD;
        var chosen = options[options.size() - 1];
        for (var i = 0; i < options.size(); i++) {
            var text = visual(options[i][0] as String);
            if (dc.getTextWidthInPixels(text, font(face, options[i][1] as Number, width)) <= max) {
                chosen = options[i];
                break;
            }
        }
        return [visual(chosen[0] as String), font(face, chosen[1] as Number, width)];
    }

    // A rim line centred on 12 o'clock (top) or 6 o'clock, upright either way.
    function drawRim(dc as Dc, cx as Number, cy as Number, width as Number, line as Array, top as Boolean) as Void {
        dc.drawRadialText(cx, cy, line[1] as Graphics.VectorFont, line[0] as String, Graphics.TEXT_JUSTIFY_CENTER,
            top ? 90 : 270, rimRadius(width),
            top ? Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE : Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);
    }

    // A Hebrew word with Latin/digit text to its left, centred on cx: "ב׳ 19.10". Two pieces, so
    // the order never depends on the firmware's handling of mixed text.
    function drawPair(dc as Dc, cx as Number, y as Number, hebrew as String, hebrewFont as Graphics.FontType,
                      other as String, otherFont as Graphics.FontType, gap as Number) as Void {
        var hw = dc.getTextWidthInPixels(hebrew, hebrewFont);
        var right = cx + (hw + gap + dc.getTextWidthInPixels(other, otherFont)) / 2;
        dc.drawText(right, y, hebrewFont, hebrew, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(right - hw - gap, y, otherFont, other, Graphics.TEXT_JUSTIFY_RIGHT);
    }
}
```

- [ ] **Step 4: Run the Venu face tests.** Expected: the 5 new tests PASS.
  - **A date or title fails to fit:** add a smaller size to the end of `SIZES` (e.g. 20) rather than widening `RIM_DEGREES`. The rings set that limit; see Task 6.
  - **A year test hits the watchdog** ("Too many instructions"): split that year into two half-year tests.

- [ ] **Step 5: Commit** — "Fit Hebrew rim text to the round screen". Add the trailer lines.

---

### Task 5: Dial — ticks, hands, hub and burn-in shift

**Files:**
- Create: `face/source-round/Dial.mc`
- Modify: `face/test-round/RoundLayoutTests.mc` (append tests)

**Interfaces:**
- Produces:
  - `Dial.ACCENT = 0xFFAA00`.
  - `Dial.burnInOffset(minute as Number) as Array<Number>`.
  - `Dial.points(cx as Numeric, cy as Numeric, angle as Float, length as Float, width as Float, tail as Float) as Array<Array>`.
  - `Dial.drawTicks(dc as Dc, cx as Number, cy as Number, r as Number, low as Boolean) as Void`.
  - `Dial.drawHands(dc as Dc, cx as Number, cy as Number, r as Number, hour as Number, min as Number, sec as Number?, low as Boolean) as Void`. `sec` is null for no seconds hand.

- [ ] **Step 1: Failing tests** (append to `face/test-round/RoundLayoutTests.mc`)

```monkeyc
// Always-on moves the drawing every minute, never more than 3 px from centre.
(:test)
function burnInShiftMovesEveryMinuteWithinThreePixels(logger as Logger) as Boolean {
    for (var m = 0; m < 60; m++) {
        var o = Dial.burnInOffset(m);
        var n = Dial.burnInOffset((m + 1) % 60);
        if (o[0].abs() > 3 || o[1].abs() > 3 || (o[0] == n[0] && o[1] == n[1])) {
            logger.error("minute " + m + ": " + o + " then " + n);
            return false;
        }
    }
    return true;
}

// A hand's tip points along its clock angle: 12 o'clock is straight up.
(:test)
function handTipFollowsTheAngle(logger as Logger) as Boolean {
    var up = Dial.points(100, 100, 0.0, 50.0, 10.0, 0.0);
    var right = Dial.points(100, 100, (Math.PI / 2).toFloat(), 50.0, 10.0, 0.0);
    return (up[2][1] - 50).abs() < 0.01 && (up[3][1] - 50).abs() < 0.01
        && (right[2][0] - 150).abs() < 0.01 && (right[3][0] - 150).abs() < 0.01;
}
```

- [ ] **Step 2: Run on `venu441mm`.** Expected: build ERROR, undefined `Dial`.

- [ ] **Step 3: Implement** `face/source-round/Dial.mc`

```monkeyc
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// The analog dial on the round screen: ticks, hands and hub, awake and always-on.
// Lengths are for a 195 px radius (Venu 4 41 mm) and scale with r.
module Dial {

    const ACCENT = 0xFFAA00;
    const HANDS_LOW = 0xC8C8C8;
    // Always-on burn-in shift, one step per minute, at most 2 px from centre.
    const SHIFTS = [[0, 0], [2, 0], [2, 2], [0, 2], [-2, 2], [-2, 0], [-2, -2], [0, -2], [2, -2]];

    function burnInOffset(minute as Number) as Array<Number> {
        return SHIFTS[minute % SHIFTS.size()] as Array<Number>;
    }

    // Awake: 60 grey minute ticks and 12 white hour marks. Always-on: dim hour marks only, the
    // quarters a little brighter.
    function drawTicks(dc as Dc, cx as Number, cy as Number, r as Number, low as Boolean) as Void {
        var s = r / 195.0;
        for (var i = 0; i < 60; i += (low ? 5 : 1)) {
            var hour = i % 5 == 0;
            if (low) {
                dc.setColor(i % 15 == 0 ? 0x8A8A8A : 0x5A5A5A, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(i % 15 == 0 ? 3 : 2);
            } else {
                dc.setColor(hour ? Graphics.COLOR_WHITE : 0x666666, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(hour ? 4 : 2);
            }
            var a = i * Math.PI / 30;
            var r0 = r - (hour ? 18 : 9) * s;
            var r1 = r - 3 * s;
            dc.drawLine((cx + Math.sin(a) * r0).toNumber(), (cy - Math.cos(a) * r0).toNumber(),
                        (cx + Math.sin(a) * r1).toNumber(), (cy - Math.cos(a) * r1).toNumber());
        }
        dc.setPenWidth(1);
    }

    // Awake: white hands over a black outline, an orange seconds hand (sec != null) and an orange
    // hub. Always-on: hollow light-grey hands over black, a ring for the hub, no seconds.
    function drawHands(dc as Dc, cx as Number, cy as Number, r as Number, hour as Number, min as Number,
                       sec as Number?, low as Boolean) as Void {
        var s = r / 195.0;
        var ha = (((hour % 12) * 60 + min) * Math.PI / 360).toFloat();
        var ma = (min * Math.PI / 30).toFloat();
        var hl = r * 0.52;
        var ml = r * 0.80;
        fill(dc, cx, cy, ha, hl + 3, 18 * s, 18 * s, Graphics.COLOR_BLACK);
        fill(dc, cx, cy, ma, ml + 3, 14 * s, 18 * s, Graphics.COLOR_BLACK);
        if (low) {
            outline(dc, cx, cy, ha, hl, 12 * s, 18 * s);
            outline(dc, cx, cy, ma, ml, 9 * s, 18 * s);
            dc.setColor(HANDS_LOW, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawCircle(cx, cy, (6 * s).toNumber());
            dc.setPenWidth(1);
            return;
        }
        fill(dc, cx, cy, ha, hl, 12 * s, 18 * s, Graphics.COLOR_WHITE);
        fill(dc, cx, cy, ma, ml, 8 * s, 18 * s, Graphics.COLOR_WHITE);
        if (sec != null) {
            fill(dc, cx, cy, (sec * Math.PI / 30).toFloat(), r * 0.86, 3 * s, 24 * s, ACCENT);
        }
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (9 * s).toNumber());
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (3 * s).toNumber());
    }

    // Tapered hand from tail to tip along a clock angle (0 = 12 o'clock, clockwise): the
    // corners [tail left, tail right, tip right, tip left].
    function points(cx as Numeric, cy as Numeric, angle as Float, length as Float, width as Float, tail as Float) as Array<Array> {
        var sn = Math.sin(angle);
        var cs = Math.cos(angle);
        return [
            [cx - cs * width / 2 - sn * tail, cy - sn * width / 2 + cs * tail],
            [cx + cs * width / 2 - sn * tail, cy + sn * width / 2 + cs * tail],
            [cx + cs * width / 4 + sn * length, cy + sn * width / 4 - cs * length],
            [cx - cs * width / 4 + sn * length, cy - sn * width / 4 - cs * length]
        ];
    }

    function fill(dc as Dc, cx as Number, cy as Number, angle as Float, length as Float, width as Float,
                  tail as Float, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(points(cx, cy, angle, length, width, tail));
    }

    function outline(dc as Dc, cx as Number, cy as Number, angle as Float, length as Float, width as Float,
                     tail as Float) as Void {
        var p = points(cx, cy, angle, length, width, tail);
        dc.setColor(HANDS_LOW, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var i = 0; i < 4; i++) {
            var a = p[i];
            var b = p[(i + 1) % 4];
            dc.drawLine((a[0] as Float).toNumber(), (a[1] as Float).toNumber(), (b[0] as Float).toNumber(), (b[1] as Float).toNumber());
        }
        dc.setPenWidth(1);
    }
}
```

- [ ] **Step 4: Run the Venu tests.** Expected: the 2 new tests PASS.
- [ ] **Step 5: Commit** — "Add the analog dial for the Venu face". Add the trailer lines.

---

### Task 6: Rings and ring data

**Files:**
- Create: `face/source-round/Rings.mc`, `face/source-round/RingData.mc`
- Modify: `face/test-round/RoundLayoutTests.mc` (append tests)

**Interfaces:**
- Consumes: `RoundText.font`, `RoundText.rimRadius`, `RoundText.RIM_DEGREES` (Task 4); `Slots.*` (existing); icon ids (Task 3).
- Produces:
  - `Rings.centre(slot as Number, width as Number) as Array<Number>` and `Rings.radius(width as Number) as Number`.
  - `Rings.hit(x as Number, y as Number, width as Number) as Number`: the slot, or 0.
  - `Rings.valueFont(dc as Dc, text as String, width as Number, low as Boolean) as Graphics.VectorFont`.
  - `Rings.draw(dc as Dc, slot as Number, width as Number, offset as Array<Number>, ring as Array, low as Boolean) as Void`. `ring` is `[icon as BitmapResource, color as Number, value as String, progress as Float]`.
  - `RingData.complicationType(type as Number) as Number`: -1 if none.
  - `RingData.value(type as Number, sun as Array<Number>?) as String` and `RingData.progress(type as Number) as Float` (-1.0 = no arc).
  - `RingData.icon(type as Number) as ResourceId?`, `RingData.color(type as Number) as Number`.
  - `RingData.batteryIcon(level as Float) as ResourceId`, `RingData.batteryColor(level as Float) as Number`.
  - `RingData.clamp(p as Float) as Float`, plus `RingData.COLORS` and `RingData.LOW_COLOR`.

- [ ] **Step 1: Failing tests** (append to `face/test-round/RoundLayoutTests.mc`; add `import Toybox.Complications;`)

```monkeyc
// Rings stay inside the dial, apart from each other, and clear of the rim lines' arcs.
(:test)
function ringsFitBetweenRimLines(logger as Logger) as Boolean {
    var w = System.getDeviceSettings().screenWidth;
    var c = w / 2;
    var r = Rings.radius(w);
    var half = Math.toRadians(RoundText.RIM_DEGREES / 2.0);
    for (var a = 1; a <= 6; a++) {
        var p = Rings.centre(a, w);
        var d = Math.sqrt((p[0] - c) * (p[0] - c) + (p[1] - c) * (p[1] - c));
        if (d + r > c - 9 * w / 390) {
            logger.error("slot " + a + " reaches the ticks");
            return false;
        }
        for (var b = a + 1; b <= 6; b++) {
            var q = Rings.centre(b, w);
            if (Math.sqrt((p[0] - q[0]) * (p[0] - q[0]) + (p[1] - q[1]) * (p[1] - q[1])) < 2 * r + 4) {
                logger.error("slots " + a + " and " + b + " touch");
                return false;
            }
        }
        // Angle of the ring centre from 3 o'clock; distance of its nearest edge to the 12-6 axis.
        var angle = Math.atan2((c - p[1]).toFloat(), (p[0] - c).toFloat());
        var gap = ((angle.abs() - Math.PI / 2).abs() - Math.asin(r.toFloat() / d)) - half;
        if (gap < Math.toRadians(1)) {
            logger.error("slot " + a + " runs into a rim line");
            return false;
        }
    }
    return true;
}

(:test)
function ringHitTest(logger as Logger) as Boolean {
    var w = System.getDeviceSettings().screenWidth;
    for (var s = 1; s <= 6; s++) {
        var p = Rings.centre(s, w);
        if (Rings.hit(p[0], p[1], w) != s) {
            return false;
        }
    }
    return Rings.hit(w / 2, w / 2, w) == 0 && Rings.hit(0, 0, w) == 0;
}

// The widest realistic values fit inside a ring at the value line, awake and always-on.
(:test)
function widestValuesFitInsideRings(logger as Logger) as Boolean {
    var dc = RoundTestSupport.screenDc();
    var w = dc.getWidth();
    var r = Rings.radius(w) - 2;
    var dy = Rings.VALUE_DY * w / 390 + 9 * w / 390;   // lower edge of the digits
    var chord = 2 * Math.sqrt(r * r - dy * dy) - 4;
    var values = ["88888", "23:59", "12:59", "100%", "3999m", "-417m", "--:--", "--"];
    for (var low = 0; low <= 1; low++) {
        for (var i = 0; i < values.size(); i++) {
            var f = Rings.valueFont(dc, values[i], w, low == 1);
            if (dc.getTextWidthInPixels(values[i], f) > chord) {
                logger.error(values[i] + " wider than " + chord);
                return false;
            }
        }
    }
    return true;
}

// Review focus: a missing reading shows text ("--"), never crashes, for every type.
(:test)
function ringDataGivesTextForEveryType(logger as Logger) as Boolean {
    for (var type = 1; type < Slots.TYPE_COUNT; type++) {
        var v = RingData.value(type, null);
        if (!(v instanceof String) || v.length() == 0) {
            logger.error("type " + type);
            return false;
        }
    }
    return true;
}

// Review focus: the battery icon follows the level and turns red when low.
(:test)
function batteryIconAndColorFollowLevel(logger as Logger) as Boolean {
    return RingData.batteryIcon(100.0) == Rez.Drawables.IconBattery
        && RingData.batteryIcon(70.0) == Rez.Drawables.IconBattery80
        && RingData.batteryIcon(40.0) == Rez.Drawables.IconBattery50
        && RingData.batteryIcon(10.0) == Rez.Drawables.IconBattery20
        && RingData.batteryColor(15.0) == RingData.LOW_COLOR
        && RingData.batteryColor(50.0) == RingData.COLORS[Slots.BATTERY];
}

// Review focus: steps above the goal fill the ring and no more.
(:test)
function progressIsClamped(logger as Logger) as Boolean {
    var p = RingData.progress(Slots.STEPS);
    return RingData.clamp(1.7) == 1.0 && RingData.clamp(-0.2) == 0.0 && RingData.clamp(0.5) == 0.5
        && (p == -1.0 || (p >= 0.0 && p <= 1.0))
        && RingData.progress(Slots.HEART_RATE) == -1.0;
}
```

- [ ] **Step 2: Run on `venu441mm`.** Expected: build ERROR, undefined `Rings`/`RingData`.

- [ ] **Step 3: Implement** `face/source-round/Rings.mc`

```monkeyc
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// Six ring subdials, three per side between the rim lines: slots 1, 3, 5 on the left, 2, 4, 6 on
// the right, rows top to bottom (the Instinct's row pairs). Each ring has an icon on top, the value
// under it, a thin track and, for gauge slots, a progress arc from 12 o'clock.
// Geometry is for 390 px and scales with the width.
module Rings {

    const ORBIT = 134;     // ring centre distance from the screen centre
    const RADIUS = 38;
    const SPREAD = 37;     // degrees between rows
    const ICON_DY = -30;   // icon top relative to the ring centre
    const VALUE_DY = 15;   // value centre relative to the ring centre
    const VALUE_SIZES = [24, 21];
    const TRACK = 0x2A2A2A;
    const TRACK_LOW = 0x262626;
    const VALUE_LOW = 0x8C8C8C;

    function centre(slot as Number, width as Number) as Array<Number> {
        var row = (slot - 1) / 2;
        var left = (slot - 1) % 2 == 0;
        var a = Math.toRadians((row - 1) * SPREAD);
        var c = width / 2;
        var orbit = ORBIT * width / 390.0;
        var dx = orbit * Math.cos(a);
        return [(left ? c - dx : c + dx).toNumber(), (c + orbit * Math.sin(a)).toNumber()];
    }

    function radius(width as Number) as Number {
        return RADIUS * width / 390;
    }

    // Slot (1-6) whose ring contains (x, y), or 0.
    function hit(x as Number, y as Number, width as Number) as Number {
        var r = radius(width);
        for (var slot = 1; slot <= 6; slot++) {
            var p = centre(slot, width);
            var dx = x - p[0];
            var dy = y - p[1];
            if (dx * dx + dy * dy <= r * r) {
                return slot;
            }
        }
        return 0;
    }

    // The largest value font whose text fits inside the ring.
    function valueFont(dc as Dc, text as String, width as Number, low as Boolean) as Graphics.VectorFont {
        var face = low ? "RobotoRegular" : "RobotoCondensedBold";
        var r = radius(width) - 2;
        var dy = (VALUE_DY + 9) * width / 390;
        var chord = 2 * Math.sqrt(r * r - dy * dy) - 4;
        var f = RoundText.font(face, VALUE_SIZES[0], width);
        if (dc.getTextWidthInPixels(text, f) > chord) {
            f = RoundText.font(face, VALUE_SIZES[1], width);
        }
        return f;
    }

    // ring: [icon, color, value, progress]; offset: always-on burn-in shift.
    function draw(dc as Dc, slot as Number, width as Number, offset as Array<Number>, ring as Array, low as Boolean) as Void {
        var p = centre(slot, width);
        var x = p[0] + offset[0];
        var y = p[1] + offset[1];
        var r = radius(width);
        var color = low ? dimmed(ring[1] as Number, 0.45) : ring[1] as Number;
        var progress = ring[3] as Float;
        dc.setPenWidth(low ? 2 : 4);
        dc.setColor(low ? TRACK_LOW : TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, r);
        if (progress > 0.005) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(x, y, r, Graphics.ARC_CLOCKWISE, 90, 90 - (360 * progress).toNumber());
        }
        dc.setPenWidth(1);
        var icon = ring[0] as BitmapResource;
        dc.drawBitmap2(x - icon.getWidth() / 2, y + ICON_DY * width / 390, icon, {:tintColor => color});
        var text = ring[2] as String;
        dc.setColor(low ? VALUE_LOW : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + VALUE_DY * width / 390, valueFont(dc, text, width, low), text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // A colour with its RGB channels scaled by f (0..1).
    function dimmed(color as Number, f as Float) as Number {
        var r = (((color >> 16) & 0xFF) * f).toNumber();
        var g = (((color >> 8) & 0xFF) * f).toNumber();
        var b = ((color & 0xFF) * f).toNumber();
        return (r << 16) | (g << 8) | b;
    }
}
```

`face/source-round/RingData.mc`:
```monkeyc
import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// What a ring shows for each slot type on the Venu: value text, progress, icon and colour.
// Values come from the watch's own complications where they exist, else from Slots.
module RingData {

    // Indexed by Slots.Type: none, HR, battery, steps, altitude, sunrise, sunset, Body Battery,
    // solar, notifications, calories.
    const COLORS = [0x000000, 0xFF4D5E, 0x4CD964, 0x3FA9F5, 0xB8C2CC, 0xFFC83D, 0xFF8A3D, 0x4FD8FF,
                    0xFFD000, 0xC79BFF, 0xFF7A45];
    const LOW_BATTERY = 20;
    const LOW_COLOR = 0xFF3B30;

    // The native complication behind a slot type, or -1. Also what a press on the ring opens.
    function complicationType(type as Number) as Number {
        switch (type) {
            case Slots.HEART_RATE: return Complications.COMPLICATION_TYPE_HEART_RATE as Number;
            case Slots.BATTERY: return Complications.COMPLICATION_TYPE_BATTERY as Number;
            case Slots.STEPS: return Complications.COMPLICATION_TYPE_STEPS as Number;
            case Slots.ALTITUDE: return Complications.COMPLICATION_TYPE_ALTITUDE as Number;
            case Slots.SUNRISE: return Complications.COMPLICATION_TYPE_SUNRISE as Number;
            case Slots.SUNSET: return Complications.COMPLICATION_TYPE_SUNSET as Number;
            case Slots.BODY_BATTERY: return Complications.COMPLICATION_TYPE_BODY_BATTERY as Number;
            case Slots.NOTIFICATIONS: return Complications.COMPLICATION_TYPE_NOTIFICATION_COUNT as Number;
            case Slots.CALORIES: return Complications.COMPLICATION_TYPE_CALORIES as Number;
        }
        return -1;
    }

    function complicationValue(type as Number) {
        var ct = complicationType(type);
        if (ct < 0 || !(Toybox has :Complications)) {
            return null;
        }
        try {
            return Complications.getComplication(new Complications.Id(ct as Complications.Type)).value;
        } catch (e) {
            return null;
        }
    }

    // Ring text; "--" when the watch has no reading. Sunrise/sunset come from the view's sun
    // times, which already prefer the watch's own.
    function value(type as Number, sun as Array<Number>?) as String {
        if (type != Slots.SUNRISE && type != Slots.SUNSET) {
            var v = complicationValue(type);
            if (v instanceof Number || v instanceof Float || v instanceof Long || v instanceof Double) {
                var n = v.toNumber();
                if (type == Slots.BATTERY) {
                    return n.format("%d") + "%";
                }
                if (type == Slots.ALTITUDE) {
                    return n.format("%d") + "m";
                }
                return n.format("%d");
            }
        }
        return Slots.value(type, sun);
    }

    // 0..1 for gauge types (battery, Body Battery, steps against the daily goal); -1 otherwise
    // or without a reading.
    function progress(type as Number) as Float {
        if (type == Slots.BATTERY) {
            return clamp(System.getSystemStats().battery / 100.0);
        }
        if (type == Slots.BODY_BATTERY) {
            var v = complicationValue(type);
            if (!(v instanceof Number)) {
                v = Slots.latestSample(:getBodyBatteryHistory);
            }
            return v == null ? -1.0 : clamp(v.toFloat() / 100.0);
        }
        if (type == Slots.STEPS) {
            var info = ActivityMonitor.getInfo();
            var goal = info.stepGoal;
            return (info.steps == null || goal == null || goal <= 0) ? -1.0 : clamp((info.steps as Number).toFloat() / goal);
        }
        return -1.0;
    }

    function clamp(p as Float) as Float {
        return p < 0.0 ? 0.0 : (p > 1.0 ? 1.0 : p);
    }

    // Icon for a slot type; the battery icon follows the charge. Null for types without one
    // (Solar, which the Venu does not offer).
    function icon(type as Number) as ResourceId? {
        switch (type) {
            case Slots.HEART_RATE: return Rez.Drawables.IconHeart;
            case Slots.BATTERY: return batteryIcon(System.getSystemStats().battery);
            case Slots.STEPS: return Rez.Drawables.IconSteps;
            case Slots.ALTITUDE: return Rez.Drawables.IconAltitude;
            case Slots.SUNRISE: return Rez.Drawables.IconSunrise;
            case Slots.SUNSET: return Rez.Drawables.IconSunset;
            case Slots.BODY_BATTERY: return Rez.Drawables.IconBodyBattery;
            case Slots.NOTIFICATIONS: return Rez.Drawables.IconNotifications;
            case Slots.CALORIES: return Rez.Drawables.IconCalories;
        }
        return null;
    }

    function color(type as Number) as Number {
        return type == Slots.BATTERY ? batteryColor(System.getSystemStats().battery) : COLORS[type] as Number;
    }

    function batteryIcon(level as Float) as ResourceId {
        if (level >= 95) {
            return Rez.Drawables.IconBattery;
        }
        if (level >= 65) {
            return Rez.Drawables.IconBattery80;
        }
        return level >= 35 ? Rez.Drawables.IconBattery50 : Rez.Drawables.IconBattery20;
    }

    function batteryColor(level as Float) as Number {
        return level <= LOW_BATTERY ? LOW_COLOR : COLORS[Slots.BATTERY] as Number;
    }
}
```

If the type checker rejects `Complications.COMPLICATION_TYPE_* as Number`, keep the switch and change the return type to `Complications.Type or Number`. Then compare with `== -1` at call sites. The tests compare with the enum constants either way.

- [ ] **Step 4: Run the Venu tests.** Expected: the 6 new tests PASS. If `widestValuesFitInsideRings` fails for a value, add a smaller size to `VALUE_SIZES` and make `valueFont` walk all sizes. Do not shrink `RADIUS`: the rings were sized with the user.
- [ ] **Step 5: Commit** — "Add ring subdials and their data for the Venu face". Add the trailer lines.

---

### Task 7: The Venu face view (awake and always-on)

**Files:**
- Modify (replace stub): `face/source-round/HebrewFaceView.mc`
- Create: `face/test-round/RoundRenderTests.mc`

**Interfaces:**
- Consumes: `Today.at`, `WatchSun.get` (Task 2); `RoundText.*` (Task 4); `Dial.*` (Task 5); `Rings.*`, `RingData.*` (Task 6); `Parasha.titleFor`, `Parasha.changed`, `Parasha.log`; `Slots.typeOf`, `Slots.SLOT_COUNT`, `Slots.NONE`; `HebrewFormat.weekday`.
- Produces: `HebrewFaceView` with `onLayout`, `onUpdate`, `onEnterSleep`, `onExitSleep`, and these test hooks:
  - `setLowPower(low as Boolean?) as Void` (null = follow the watch);
  - `refreshLines(dc as Dc, hebrewRd as Number, width as Number) as Void`;
  - fields `_dateLine` and `_parashaLine`.

- [ ] **Step 1: Failing tests** `face/test-round/RoundRenderTests.mc`

```monkeyc
import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// Draws the Venu face awake and always-on with every slot type (including Empty) in every slot,
// with and without a parasha, so every drawing path runs.
(:test)
function roundFaceRendersAwakeAndAlwaysOn(logger as Logger) as Boolean {
    var dc = RoundTestSupport.screenDc();
    var view = new HebrewFaceView();
    view.onLayout(dc);
    var saved = TestCache.save();
    var today = Parasha.todayRd();
    Storage.setValue(Parasha.ITEMS_KEY, [[HebrewCalendar.shabbatOnOrAfter(today), "פרשת אחרי מות־קדושים", true],
        [HebrewCalendar.shabbatOnOrAfter(today + 1), "פרשת אחרי מות־קדושים", true]]);
    Parasha.changed = true;
    for (var low = 0; low <= 1; low++) {
        view.setLowPower(low == 1);
        for (var type = 0; type < Slots.TYPE_COUNT; type++) {
            for (var slot = 1; slot <= Slots.SLOT_COUNT; slot++) {
                Slots.setType(slot, type);
            }
            view.onUpdate(dc);
        }
    }
    Storage.deleteValue(Parasha.ITEMS_KEY);
    Parasha.changed = true;
    view.onUpdate(dc);
    for (var slot = 1; slot <= Slots.SLOT_COUNT; slot++) {
        Slots.setType(slot, Slots.DEFAULTS[slot - 1]);
    }
    view.setLowPower(null);
    TestCache.restore(saved);
    return true;
}

// Review focus: the cached rim lines follow the Hebrew day and the display mode.
(:test)
function rimLinesFollowTheDayAndTheMode(logger as Logger) as Boolean {
    var dc = RoundTestSupport.screenDc();
    var w = dc.getWidth();
    var view = new HebrewFaceView();
    var rd = Parasha.todayRd();
    view.setLowPower(false);
    view.refreshLines(dc, rd, w);
    var awake = view._dateLine as Array;
    view.refreshLines(dc, rd + 1, w);
    var nextDay = view._dateLine as Array;
    view.setLowPower(true);
    view.refreshLines(dc, rd + 1, w);
    var dim = view._dateLine as Array;
    return !(awake[0] as String).equals(nextDay[0] as String) && dim[1] != nextDay[1];
}
```

- [ ] **Step 2: Run on `venu441mm`.** Expected: build ERROR, `setLowPower`/`refreshLines` not found on the stub.

- [ ] **Step 3: Implement** `face/source-round/HebrewFaceView.mc` (replaces the stub)

```monkeyc
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Venu face: analog dial, the full Hebrew date along the top rim, the parasha (or holiday) along
// the bottom rim, the Gregorian date in Hebrew under 12 and six ring subdials. Always-on draws the
// same layout thin and dim, shifted a few pixels each minute against burn-in.
class HebrewFaceView extends WatchUi.WatchFace {

    const GREGORIAN_DY = -107;   // under 12, relative to the centre at 390 px

    var _asleep = false;
    var _forcedLow = null as Boolean?;
    var _icons = {} as Dictionary<ResourceId, BitmapResource>;
    var _lineRd = -1;
    var _lineLow = false;
    var _dateLine = null as Array?;
    var _parashaLine = null as Array?;
    var _loggedMemory = false;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var r = w / 2;
        var low = lowPower();
        var day = Today.at(Time.now(), WatchSun.get());
        var t = day[0] as Gregorian.Info;
        var sun = day[2] as Array<Number>?;
        var off = low ? Dial.burnInOffset(t.min as Number) : [0, 0];
        var cx = r + off[0];
        var cy = r + off[1];

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setAntiAlias(true);
        Dial.drawTicks(dc, cx, cy, r, low);
        refreshLines(dc, day[3] as Number, w);
        dc.setColor(low ? 0x9A9A9A : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        RoundText.drawRim(dc, cx, cy, w, _dateLine as Array, true);
        if (_parashaLine != null) {
            dc.setColor(low ? 0x9A7A30 : Dial.ACCENT, Graphics.COLOR_TRANSPARENT);
            RoundText.drawRim(dc, cx, cy, w, _parashaLine as Array, false);
        }
        drawGregorian(dc, t, cx, cy + GREGORIAN_DY * w / 390, w, low);
        drawRings(dc, sun, w, off, low);
        Dial.drawHands(dc, cx, cy, r, t.hour as Number, t.min as Number, low ? null : t.sec as Number, low);

        if (!_loggedMemory) {
            var stats = System.getSystemStats();
            Parasha.log("face mem " + stats.usedMemory + "/" + stats.totalMemory + " sun " + sun);
            _loggedMemory = true;
        }
    }

    // Always-on: the display mode where available (API 5), else the sleep callbacks.
    function lowPower() as Boolean {
        if (_forcedLow != null) {
            return _forcedLow as Boolean;
        }
        if (System has :getDisplayMode) {
            return System.getDisplayMode() == System.DISPLAY_MODE_LOW_POWER;
        }
        return _asleep;
    }

    // Test hook: force awake (false) or always-on (true); null follows the watch.
    function setLowPower(low as Boolean?) as Void {
        _forcedLow = low;
    }

    // Fits the rim lines once per Hebrew day and display mode (the fonts differ), and again
    // when a background sync changes the parasha cache.
    function refreshLines(dc as Dc, hebrewRd as Number, width as Number) as Void {
        var low = lowPower();
        if (hebrewRd == _lineRd && low == _lineLow && !Parasha.changed) {
            return;
        }
        _dateLine = RoundText.fitRim(dc, RoundText.dateOptions(HebrewCalendar.fromFixed(hebrewRd)), width, low);
        var title = Parasha.titleFor(hebrewRd);
        _parashaLine = title == null ? null : RoundText.fitRim(dc, RoundText.titleOptions(title), width, low);
        _lineRd = hebrewRd;
        _lineLow = low;
        Parasha.changed = false;
    }

    // "ב׳ 19.10": Hebrew weekday letter, day.month in Roboto.
    function drawGregorian(dc as Dc, t as Gregorian.Info, cx as Number, y as Number, w as Number, low as Boolean) as Void {
        dc.setColor(low ? 0x7A7A7A : 0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        RoundText.drawPair(dc, cx, y,
            HebrewFormat.weekday(t.day_of_week as Number), RoundText.font(RoundText.REGULAR, 28, w),
            t.day + "." + t.month, RoundText.font(low ? "RobotoRegular" : "RobotoCondensedBold", 30, w),
            8 * w / 390);
    }

    function drawRings(dc as Dc, sun as Array<Number>?, w as Number, off as Array<Number>, low as Boolean) as Void {
        for (var slot = 1; slot <= Slots.SLOT_COUNT; slot++) {
            var type = Slots.typeOf(slot);
            var iconId = RingData.icon(type);
            if (type == Slots.NONE || iconId == null) {
                continue;
            }
            Rings.draw(dc, slot, w, off,
                [bitmap(iconId as ResourceId), RingData.color(type), RingData.value(type, sun), RingData.progress(type)], low);
        }
    }

    function bitmap(id as ResourceId) as BitmapResource {
        var b = _icons[id];
        if (b == null) {
            b = WatchUi.loadResource(id) as BitmapResource;
            _icons[id] = b;
        }
        return b;
    }

    function onEnterSleep() as Void {
        _asleep = System.getDeviceSettings().requiresBurnInProtection;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _asleep = false;
        WatchUi.requestUpdate();
    }
}
```

- [ ] **Step 4: Run all tests on both devices.** Expected: everything PASSES. The Instinct face suite is unchanged (17), and the Venu adds the two new tests.

- [ ] **Step 5: Look at it.** Build the face (not tests) for `venu441mm` and run it: `monkeyc -d venu441mm -f monkey.jungle -o bin/HebrewFace-venu.prg -y $K` then `monkeydo bin/HebrewFace-venu.prg venu441mm` in the background. Report back so the coordinator can get a screenshot from the user. Do not judge the look yourself.

- [ ] **Step 6: Commit** — "Draw the Venu face: rim dates, rings and dial, awake and always-on". Add the trailer lines.

---

### Task 8: Hold a ring to open the matching native view

**Files:**
- Create: `face/source-round/RingPressDelegate.mc`
- Modify: `face/source-round/FaceViews.mc`, `face/test-round/RoundLayoutTests.mc` (append)

**Interfaces:**
- Consumes: `Rings.hit`, `RingData.complicationType`, `Slots.typeOf`.
- Produces: `RingPressDelegate` (a `WatchUi.WatchFaceDelegate`) with `static function target(x as Number, y as Number, width as Number) as Number`, which returns -1 for nothing to open.

- [ ] **Step 1: Failing test** (append)

```monkeyc
// Holding a ring targets its complication; an empty slot or the centre targets nothing.
(:test)
function holdOnRingTargetsItsComplication(logger as Logger) as Boolean {
    var w = System.getDeviceSettings().screenWidth;
    var before = Slots.typeOf(1);
    var p = Rings.centre(1, w);
    Slots.setType(1, Slots.HEART_RATE);
    var ok = RingPressDelegate.target(p[0], p[1], w) == Complications.COMPLICATION_TYPE_HEART_RATE;
    Slots.setType(1, Slots.NONE);
    ok = ok && RingPressDelegate.target(p[0], p[1], w) == -1;
    ok = ok && RingPressDelegate.target(w / 2, w / 2, w) == -1;
    Slots.setType(1, before);
    return ok;
}
```

- [ ] **Step 2: Run on `venu441mm`.** Expected: build ERROR, undefined `RingPressDelegate`.

- [ ] **Step 3: Implement** `face/source-round/RingPressDelegate.mc`

```monkeyc
import Toybox.Complications;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Touch-and-hold on a ring opens the matching native view (faces get no plain taps).
class RingPressDelegate extends WatchUi.WatchFaceDelegate {

    function initialize() {
        WatchFaceDelegate.initialize();
    }

    function onPress(event as WatchUi.ClickEvent) as Boolean {
        var xy = event.getCoordinates();
        var ct = target(xy[0], xy[1], System.getDeviceSettings().screenWidth);
        if (ct < 0) {
            return false;
        }
        try {
            Complications.exitTo(new Complications.Id(ct as Complications.Type));
            return true;
        } catch (e) {
            return false;
        }
    }

    // Complication to open for a press at (x, y), or -1.
    static function target(x as Number, y as Number, width as Number) as Number {
        var slot = Rings.hit(x, y, width);
        return slot == 0 ? -1 : RingData.complicationType(Slots.typeOf(slot));
    }
}
```

In `face/source-round/FaceViews.mc`, return the delegate:
```monkeyc
        return [new HebrewFaceView(), new RingPressDelegate()] as [WatchUi.Views, WatchUi.InputDelegates];
```
Also update the module comment to mention hold-to-open.

- [ ] **Step 4: Run the Venu tests.** Expected: PASS. Run the Instinct suites too (unchanged).
- [ ] **Step 5: Commit** — "Open the native view when a ring is held". Add the trailer lines.

---

### Task 9: Settings on the Venu — no Solar, no light theme

**Files:**
- Modify: `face/source/Slots.mc`, `face/source/SettingsMenu.mc`, `face/test/RenderTests.mc`

**Interfaces:**
- Produces: `Slots.available(type as Number) as Boolean`, `Slots.next(type as Number) as Number`, `SettingsMenu.amoled() as Boolean`.

- [ ] **Step 1: Failing tests** (append to `face/test/RenderTests.mc`; add `import Toybox.System;` if missing)

```monkeyc
// Solar is offered only where there is solar charging (not on AMOLED watches), and cycling
// the slot setting skips what is not offered.
(:test)
function solarSlotOnlyWithSolarCharging(logger as Logger) as Boolean {
    var amoled = SettingsMenu.amoled();
    return Slots.available(Slots.SOLAR) == !amoled
        && Slots.next(Slots.BODY_BATTERY) == (amoled ? Slots.NOTIFICATIONS : Slots.SOLAR)
        && Slots.next(Slots.CALORIES) == Slots.NONE;
}

// The light background is offered only on memory-in-pixel screens; AMOLED faces stay black.
(:test)
function themeOnlyWithoutAmoled(logger as Logger) as Boolean {
    var menu = SettingsMenu.build()[0] as WatchUi.Menu2;
    return (menu.findItemById(:theme) == -1) == SettingsMenu.amoled();
}
```
In the existing `settingsMenuBuildsAndCycles`, replace `(before + 1) % Slots.TYPE_COUNT` with `Slots.next(before)`.

- [ ] **Step 2: Run on both devices.** Expected: build ERROR, undefined `available`/`next`/`amoled`.

- [ ] **Step 3: Implement**

In `face/source/Slots.mc`, after `setType`:
```monkeyc
    // AMOLED watches (the Venu) have no solar charging, so Solar is not offered there.
    function available(type as Number) as Boolean {
        return type != SOLAR || !System.getDeviceSettings().requiresBurnInProtection;
    }

    // The next type offered after type, wrapping round to Empty.
    function next(type as Number) as Number {
        var n = (type + 1) % TYPE_COUNT;
        while (!available(n)) {
            n = (n + 1) % TYPE_COUNT;
        }
        return n;
    }
```

In `face/source/SettingsMenu.mc`:
- In `build()`, wrap the theme item:
```monkeyc
        if (!amoled()) {
            menu.addItem(new WatchUi.MenuItem(Rez.Strings.ThemeTitle, themeName(), :theme, null));
        }
```
- Add:
```monkeyc
    // AMOLED faces stay black: a light background would burn power and break always-on rules.
    function amoled() as Boolean {
        return System.getDeviceSettings().requiresBurnInProtection;
    }
```
  Add `import Toybox.System;`.
- In `SettingsDelegate.onSelect`, replace the `next` computation with `var next = Slots.next(Slots.typeOf(slot));`.

- [ ] **Step 4: Run all tests on both devices.** Expected: PASS. Instinct: face 19, glance 10.
- [ ] **Step 5: Commit** — "Hide Solar and the light theme on AMOLED watches". Add the trailer lines.

---

### Task 10: Round detail view for the glance app

**Files:**
- Modify (replace stub): `glance/source-round/DetailView.mc`

**Interfaces:**
- Consumes: `HebrewDay.now()` (Task 2), `RoundText.*` (Task 4), `Parasha.titleFor`, `SunTimes.format`, `Rez.Strings.Sunrise`/`Sunset` (glance strings: "זריחה"/"שקיעה").

- [ ] **Step 1: Test.** The existing `glance/test/RenderTests.mc::glanceAndDetailRender` already lays out and draws `DetailView` with and without a parasha on every device. It is the test for this task, and it must keep passing on `venu441mm` against the real view.

- [ ] **Step 2: Implement** `glance/source-round/DetailView.mc`

```monkeyc
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Opened from the glance on the Venu: the Hebrew date along the top rim, the parasha along the
// bottom rim, the Gregorian date in Hebrew under 12, and sunrise and sunset in the middle.
class DetailView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var c = w / 2;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setAntiAlias(true);
        var day = HebrewDay.now();
        var sun = day[2] as Array<Number>?;
        var t = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        RoundText.drawRim(dc, c, c, w, RoundText.fitRim(dc, RoundText.dateOptions(day[0] as Array<Number>), w, false), true);
        var title = Parasha.titleFor(day[1] as Number);
        if (title != null) {
            dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
            RoundText.drawRim(dc, c, c, w, RoundText.fitRim(dc, RoundText.titleOptions(title), w, false), false);
        }

        var hebrew = RoundText.font(RoundText.REGULAR, 28, w);
        var digits = RoundText.font("RobotoCondensedBold", 30, w);
        var gap = 8 * w / 390;
        dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        RoundText.drawPair(dc, c, c - 107 * w / 390, HebrewFormat.weekday(t.day_of_week as Number), hebrew,
            t.day + "." + t.month + "." + t.year, digits, gap);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        RoundText.drawPair(dc, c, c - 40 * w / 390, WatchUi.loadResource(Rez.Strings.Sunrise) as String, hebrew,
            SunTimes.format(sun == null ? null : sun[0]), digits, gap);
        RoundText.drawPair(dc, c, c + 10 * w / 390, WatchUi.loadResource(Rez.Strings.Sunset) as String, hebrew,
            SunTimes.format(sun == null ? null : sun[1]), digits, gap);
    }
}
```

- [ ] **Step 3: Run the glance tests on both devices.** Expected: PASS, Instinct 10.
- [ ] **Step 4: Commit** — "Round detail view for the glance on the Venu". Add the trailer lines.

---

### Task 11: Docs, release builds and verification

**Files:**
- Modify: `README.md`, `docs/superpowers/specs/2026-10-19-venu-face-design.md` (add a line "Implemented: see plan 2026-10-19-venu-face-plan.md")

- [ ] **Step 1: README.**
  - Add a "Venu 4 (41 mm)" subsection under the Hebrew Face bullet. Describe the look in 4–6 lines, following the spec: rim date and parasha, the Gregorian date under 12, six rings with Material icons, outlined hands, seconds hand while awake, a dim always-on view, and holding a ring opening the native view.
  - Under Build, add the Venu command: `monkeyc -d venu441mm -f monkey.jungle -o bin/HebrewFace-venu.prg -y ~/.connectiq/developer_key.der -r` (same for `glance/` → `bin/HebrewDate-venu.prg`), and note that `-r` makes the small release build. Also add `-r` to the existing Instinct build command.
  - Under Tests: run the suite on both devices.
  - Under tools: `node build-icons.mjs` regenerates the Venu icons (MDI, licence in `tools/LICENSE-mdi.txt`).

- [ ] **Step 2: Full test pass.** Run face and glance, on both devices. Record the counts in the commit message. Expected: Instinct face 19 / glance 10, and Venu all passing.

- [ ] **Step 3: Release builds.** Build both apps for both devices with `-r` into `bin/` (Instinct: `HebrewFace.prg`, `HebrewDate.prg`; Venu: `HebrewFace-venu.prg`, `HebrewDate-venu.prg`). Expected: four `BUILD SUCCESSFUL`.

- [ ] **Step 4: Simulator check.** Run `monkeydo face/bin/HebrewFace-venu.prg venu441mm` in the background and confirm a `face mem` log line appears. Report the line. Then tell the coordinator the user must:
  - screenshot the awake face;
  - switch the simulator's display mode to always-on (simulator menu, Display Mode → Always On) and screenshot again;
  - watch the console for any "Screen update will be shutoff ... luminance / pixels" warning, which means the always-on budget is exceeded.

- [ ] **Step 5: Commit** — "Document the Venu face and its builds". Add the trailer lines. Do not push.
