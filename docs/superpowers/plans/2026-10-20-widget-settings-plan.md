# Widget Settings Brush-up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fourteen more widgets on both watches. The Venu's widgets are picked in the watch's own face editor, five spots with the sun ring as spot 5. The Instinct gets a pick list per slot. Each face logs once what its watch really publishes.

**Architecture:**
- A shared `Slots` module holds the widget set: its types, its complication mapping, one value reader and formatter, and gauges.
- Each watch has its own `FaceSlots` module that says which widget each slot holds. The Instinct reads it from properties written by its menu. The Venu reads it from `WatchFaceConfig`, the editor's settings.
- The Venu's `WatchFaceDelegate` gains the three editor callbacks.

**Tech Stack:** Monkey C (Connect IQ SDK 9.2.0, API 5.1+), resource XML, Python 3 (`tools/make_assets.py`), Node (`tools/build-icons.mjs`).

**Spec:** `docs/superpowers/specs/2026-10-20-widget-settings-design.md`

## Global Constraints

- **Build env:**
  - Every shell needs: `export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home PATH="/opt/homebrew/opt/openjdk@17/bin:$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")bin:$PATH"; K=/Users/razielgershoni/.connectiq/developer_key.der`
  - Work in `face/`.
- **Tests:**
  - Build them with `monkeyc -d <dev> -f monkey.jungle -o bin/test-<dev>.prg -y $K -t`, then run them with `monkeydo bin/test-<dev>.prg <dev> -t`.
  - `<dev>` is `venu441mm` and `instinct3solar45mm`. Both suites must pass after every task. The Instinct had 27 tests and the Venu 39 before this plan.
- **Simulator:** only one `monkeydo` at a time.
  - If the simulator hangs or quits, restart it: `pkill -f "com.garmin.monkeybrains.monkeydo"; pkill -f "ConnectIQ.app/Contents/MacOS/simulator"; open "$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")bin/ConnectIQ.app"`, wait about 10 s, then rerun.
  - Reviewers never run the simulator.
- **Release builds:**
  - Instinct: `monkeyc -d instinct3solar45mm -f monkey.jungle -o bin/HebrewFace.prg -y $K -r`.
  - Venu: `monkeyc -d venu441mm -f monkey.jungle -o bin/HebrewFace-venu.prg -y $K -r`.
- **Git:**
  - Never commit `*.der`, `*.pem` or `bin/`. Commit on branch `instinct-digital` and never push.
  - End every commit message with the two trailer lines: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01PH3Xcskp5dQWmBEt2yyvgD`.
- **Saved numbers:** saved slot choices are `Slots.Type` numbers. Never renumber or reorder types 0–10. New types go after `CALORIES`, in this plan's order.
- **No silent failures:** every `catch` logs through `Parasha.log(...)`.
- **Text:**
  - Never cut or abbreviate a value. Widths fall back through the existing font chain.
  - User-facing strings live in resources. The settings strings stay English.
- **Style:** match the surrounding code. Write one plain-English comment above each function saying what it does, keep the existing comment density and naming, and avoid Monkey C switch fall-through (write a separate `case` with its own `return` each time).
- **Safety check:** `rm` with variable paths is blocked, so use literal paths.

## Review Focus

These inputs are implied by the spec but easy to miss. Each one is pinned by a test in the task named.
1. **Unexpected value kinds:** a complication returns a String for a numeric type, or a Float for a count. The text shows it, or the rounded number, and never crashes. Task 1: `readingsFormatLikeTheNativeFaces`.
2. **Old or bad saved numbers on the Instinct:** saved choices 0–10 keep their meaning, and a saved number out of range (99, −1, or a String) falls back to the default. Task 1: `savedSlotNumbersKeepTheirMeaning`.
3. **No sun times:** SUN with no sun times shows `--:--` with an empty arc, the same as Sunrise. Task 1: `sunShowsTheNextSunriseOrSunset`.
4. **Odd editor settings:** a spot outside 1–5, a missing complication id, an unknown type, or Sunrise/Sunset in spots 1–4 → defaults or literal types. Task 3: `editorChoicesMapToSpots`.
5. **Missing glyphs:** the degree sign and every new Instinct icon must exist in the fonts, because a missing glyph draws nothing. Task 2: `everyIconGlyphIsInTheFont` and `degreeSignIsInTheFonts`.

---

### Task 1: Shared widget set

**Files:**
- Modify: `face/source/Slots.mc` (rewrite below)
- Modify: `face/resources/strings/strings.xml`
- Modify: `face/source-instinct/FaceSlots.mc`, `face/source-round/FaceSlots.mc`
- Modify: `face/source-instinct/HebrewFaceView.mc` (`drawSlots`, `drawWindow`)
- Modify: `face/source/SettingsMenu.mc` (`Slots.typeOf/setType` → `FaceSlots.typeOf/setType`)
- Modify: `face/source-round/RingData.mc`, `face/source-round/HebrewFaceView.mc`, `face/source-round/RingPressDelegate.mc`
- Create: `face/test-instinct/TestSlots.mc`, `face/test-round/TestSlots.mc`
- Test: `face/test/SlotsTests.mc` (rewrite), `face/test/RenderTests.mc`, `face/test-round/RoundRenderTests.mc`, `face/test-round/RoundLayoutTests.mc`

**Interfaces:**
- Produces in `Slots`:
  - Types and tables: `enum Type` with the 25 types below, `TYPE_COUNT = 25`, `SLOT_COUNT = 6`, `ORDER`, `ICONS`, `COMPLICATIONS`, `GAUGES`.
  - Lookups: `names() as Array<ResourceId>`, `complicationType(type) as Number`, `fromComplication(ct as Number?) as Number`, `isGauge(type) as Boolean`, `available(type) as Boolean`, `offered() as Array<Number>`, `complication(type) as Complications.Complication?`.
  - Values: `value(type, sun) as String`, `reading(type)`, `format(type, v, imperial as Boolean) as String`.
  - Gauges and sun: `progress(type, sun) as Float`, `ratio(v, goal) as Float`, `nextSun(sun, now) as Array`, `resolve(type, sun) as Number`, `now() as Number`.
  - Helpers: `whole`, `clamp`, `battery`, `heartRate`, `altitude`, `latestSample`.
  - `next(type)` is kept until Task 2.
- Produces in `FaceSlots` (both watches): `COUNT`, `DEFAULTS`, `typeOf(slot) as Number`, `setType(slot, type) as Void`.
- Produces in `TestSlots` (both): `set(slot, type)`, `setAll(type)`, `save() as Array`, `restore(saved)`, `reset()`.
- Removes `RingData.complicationType/complicationValue/value/progress/nextSun/isGauge`; their callers use the `Slots` ones. `RingData.ringed` uses `Slots.isGauge`.

- [ ] **Step 1: Write the failing tests.** Replace `face/test/SlotsTests.mc` with:

```monkeyc
import Toybox.Application;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.Test;

// Every type has a name, an Instinct glyph entry and a complication entry, and ORDER offers each
// type exactly once with Empty last.
(:test)
function everyTypeHasItsTables(logger as Logger) as Boolean {
    if (Slots.names().size() != Slots.TYPE_COUNT || Slots.ICONS.size() != Slots.TYPE_COUNT
            || Slots.COMPLICATIONS.size() != Slots.TYPE_COUNT || Slots.ORDER.size() != Slots.TYPE_COUNT) {
        return false;
    }
    for (var t = 0; t < Slots.TYPE_COUNT; t++) {
        if (Slots.ORDER.indexOf(t) < 0) {
            logger.error("ORDER misses " + t);
            return false;
        }
    }
    return Slots.ORDER[Slots.TYPE_COUNT - 1] == Slots.NONE;
}

// Each type maps to the watch's own complication type and back; types without one (Empty, SUN)
// and complications we do not show map to nothing.
(:test)
function complicationMappingMatchesTheWatch(logger as Logger) as Boolean {
    var expected = {
        Slots.HEART_RATE => Complications.COMPLICATION_TYPE_HEART_RATE,
        Slots.BATTERY => Complications.COMPLICATION_TYPE_BATTERY,
        Slots.STEPS => Complications.COMPLICATION_TYPE_STEPS,
        Slots.ALTITUDE => Complications.COMPLICATION_TYPE_ALTITUDE,
        Slots.SUNRISE => Complications.COMPLICATION_TYPE_SUNRISE,
        Slots.SUNSET => Complications.COMPLICATION_TYPE_SUNSET,
        Slots.BODY_BATTERY => Complications.COMPLICATION_TYPE_BODY_BATTERY,
        Slots.SOLAR => Complications.COMPLICATION_TYPE_SOLAR_INPUT,
        Slots.NOTIFICATIONS => Complications.COMPLICATION_TYPE_NOTIFICATION_COUNT,
        Slots.CALORIES => Complications.COMPLICATION_TYPE_CALORIES,
        Slots.STRESS => Complications.COMPLICATION_TYPE_STRESS,
        Slots.FLOORS => Complications.COMPLICATION_TYPE_FLOORS_CLIMBED,
        Slots.INTENSITY => Complications.COMPLICATION_TYPE_INTENSITY_MINUTES,
        Slots.TEMPERATURE => Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE,
        Slots.HIGH_LOW => Complications.COMPLICATION_TYPE_HIGH_LOW_TEMPERATURE,
        Slots.PULSE_OX => Complications.COMPLICATION_TYPE_PULSE_OX,
        Slots.RESPIRATION => Complications.COMPLICATION_TYPE_RESPIRATION_RATE,
        Slots.SLEEP_SCORE => Complications.COMPLICATION_TYPE_SLEEP_SCORE,
        Slots.PRESSURE => Complications.COMPLICATION_TYPE_SEA_LEVEL_PRESSURE,
        Slots.RECOVERY => Complications.COMPLICATION_TYPE_RECOVERY_TIME,
        Slots.VO2_MAX => Complications.COMPLICATION_TYPE_VO2MAX_RUN,
        Slots.NEXT_EVENT => Complications.COMPLICATION_TYPE_CALENDAR_EVENTS,
        Slots.RUN_WEEK => Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE
    };
    var keys = expected.keys();
    for (var i = 0; i < keys.size(); i++) {
        var t = keys[i] as Number;
        if (Slots.complicationType(t) != expected[t] || Slots.fromComplication(expected[t] as Number) != t) {
            logger.error("type " + t);
            return false;
        }
    }
    return keys.size() == Slots.TYPE_COUNT - 2
        && Slots.complicationType(Slots.NONE) == -1 && Slots.complicationType(Slots.SUN) == -1
        && Slots.fromComplication(Complications.COMPLICATION_TYPE_DATE as Number) == Slots.NONE
        && Slots.fromComplication(null) == Slots.NONE && Slots.fromComplication(-1) == Slots.NONE;
}

// Readings read like the native faces: rounded whole numbers, °C or °F, hPa, hours, km or miles
// with one decimal under 100, the watch's own strings as they are, and "--" without a reading.
// Review focus: a String for a numeric type shows as it is, a Float count is rounded, and a
// reading of some other kind shows "--".
(:test)
function readingsFormatLikeTheNativeFaces(logger as Logger) as Boolean {
    var cases = [
        [Slots.TEMPERATURE, 23.4, false, "23°"], [Slots.TEMPERATURE, 0.0, true, "32°"],
        [Slots.TEMPERATURE, -5.6, false, "-6°"], [Slots.PRESSURE, 101325.0, false, "1013"],
        [Slots.RECOVERY, 300, false, "5h"], [Slots.RECOVERY, 90, false, "2h"],
        [Slots.RUN_WEEK, 12345.0, false, "12.3km"], [Slots.RUN_WEEK, 12345.0, true, "7.7mi"],
        [Slots.RUN_WEEK, 150000.0, false, "150km"], [Slots.RUN_WEEK, 0.0, false, "0.0km"],
        [Slots.PULSE_OX, 96, false, "96%"], [Slots.ALTITUDE, 2124.4, false, "2124m"],
        [Slots.HIGH_LOW, "28/19", false, "28/19"], [Slots.NEXT_EVENT, "14:30", false, "14:30"],
        [Slots.STRESS, null, false, "--"], [Slots.STEPS, 7456, false, "7456"],
        [Slots.STRESS, 42.6, false, "43"], [Slots.STEPS, "abc", false, "abc"],
        [Slots.STEPS, [1], false, "--"]
    ];
    var failures = 0;
    for (var i = 0; i < cases.size(); i++) {
        var c = cases[i];
        var got = Slots.format(c[0] as Number, c[1], c[2] as Boolean);
        if (!got.equals(c[3])) {
            logger.error("format " + c + " gave " + got);
            failures++;
        }
    }
    return failures == 0;
}

// Gauges fill against 100 or the watch's goal, clamped, and show no arc without a reading or a
// goal; only the gauge types are gauges.
(:test)
function gaugeProgressAgainstGoals(logger as Logger) as Boolean {
    var battery = Slots.progress(Slots.BATTERY, null);
    var gauges = [Slots.BATTERY, Slots.STEPS, Slots.BODY_BATTERY, Slots.STRESS, Slots.FLOORS,
                  Slots.INTENSITY, Slots.SLEEP_SCORE, Slots.SUN];
    for (var t = 0; t < Slots.TYPE_COUNT; t++) {
        if (Slots.isGauge(t) != (gauges.indexOf(t) >= 0)) {
            logger.error("gauge " + t);
            return false;
        }
    }
    return Slots.ratio(50, 100) == 0.5 && Slots.ratio(150, 100) == 1.0 && Slots.ratio(-5, 100) == 0.0
        && Slots.ratio(null, 100) == -1.0 && Slots.ratio(5, 0) == -1.0 && Slots.ratio(5, null) == -1.0
        && Slots.ratio("x", 100) == -1.0
        && battery >= 0.0 && battery <= 1.0
        && Slots.progress(Slots.HEART_RATE, null) == -1.0 && Slots.progress(Slots.ALTITUDE, null) == -1.0
        && Slots.progress(Slots.TEMPERATURE, null) == -1.0;
}

// The sun widget shows sunset through the day and sunrise through the night, flipping exactly at
// each, with how far each has run, also when sunset falls after midnight; without sun times it
// shows sunrise with an empty arc.
(:test)
function sunWidgetFlipsAtSunriseAndSunset(logger as Logger) as Boolean {
    var sun = [6 * 3600, 18 * 3600];
    var dawn = Slots.nextSun(sun, 3 * 3600);
    var rise = Slots.nextSun(sun, 6 * 3600);
    var noon = Slots.nextSun(sun, 12 * 3600);
    var set = Slots.nextSun(sun, 18 * 3600);
    var late = Slots.nextSun([20 * 3600, 2 * 3600], 23 * 3600);
    var none = Slots.nextSun(null, 0);
    return dawn[0] == Slots.SUNRISE && (dawn[1] - 0.75).abs() < 0.001
        && rise[0] == Slots.SUNSET && rise[1] == 0.0
        && noon[0] == Slots.SUNSET && (noon[1] - 0.5).abs() < 0.001
        && set[0] == Slots.SUNRISE && set[1] == 0.0
        && late[0] == Slots.SUNSET && (late[1] - 0.5).abs() < 0.001
        && none[0] == Slots.SUNRISE && none[1] == 0.0;
}

// SUN reads, and draws its icon, as the next sunrise or sunset; every other type is itself.
// Review focus: without sun times it reads like Sunrise ("--:--") with an empty arc.
(:test)
function sunShowsTheNextSunriseOrSunset(logger as Logger) as Boolean {
    var sun = WatchSun.get();
    var day = Today.at(Time.now(), sun)[2] as Array<Number>?;
    var shown = Slots.resolve(Slots.SUN, day);
    return (shown == Slots.SUNRISE || shown == Slots.SUNSET)
        && shown == Slots.nextSun(day, Slots.now())[0]
        && Slots.value(Slots.SUN, day).equals(Slots.value(shown, day))
        && Slots.resolve(Slots.HEART_RATE, day) == Slots.HEART_RATE
        && Slots.resolve(Slots.SUN, null) == Slots.SUNRISE
        && Slots.value(Slots.SUN, null).equals(Slots.value(Slots.SUNRISE, null))
        && Slots.progress(Slots.SUN, null) == 0.0;
}

// Review focus: every type gives text (a missing reading is "--"), never a crash.
(:test)
function everyTypeGivesText(logger as Logger) as Boolean {
    for (var type = 1; type < Slots.TYPE_COUNT; type++) {
        var v = Slots.value(type, null);
        if (!(v instanceof String) || v.length() == 0) {
            logger.error("type " + type);
            return false;
        }
    }
    return Slots.value(Slots.NONE, null).equals("");
}

// The newer types are offered only where the watch publishes their complication; the original
// ones and SUN always (Solar only with solar charging), and the offered list keeps ORDER with
// Empty last.
(:test)
function newerTypesNeedTheirComplication(logger as Logger) as Boolean {
    var offered = Slots.offered();
    for (var i = 0; i < offered.size(); i++) {
        if (!Slots.available(offered[i])) {
            return false;
        }
    }
    return Slots.available(Slots.STRESS) == (Slots.complication(Slots.STRESS) != null)
        && Slots.available(Slots.HEART_RATE) && Slots.available(Slots.SUN) && Slots.available(Slots.NONE)
        && offered[offered.size() - 1] == Slots.NONE
        && Slots.available(Slots.SOLAR) == !System.getDeviceSettings().requiresBurnInProtection;
}

// Readings show as whole numbers rounded to the nearest, like the watch's own screens: 2.8 days
// of battery is "3d", not "2d".
(:test)
function readingsRoundToNearest(logger as Logger) as Boolean {
    return Slots.whole(2.8).equals("3") && Slots.whole(2.5).equals("3") && Slots.whole(2.2).equals("2")
        && Slots.whole(-17.6).equals("-18") && Slots.whole(80).equals("80") && Slots.whole(2124.4d).equals("2124");
}
```

Add `import Toybox.System;` and `import Toybox.Time;` to that file's imports (`System.getDeviceSettings`, `Time.now`).

Append to `face/test-instinct/LayoutTests.mc` (it is Instinct-only; the Instinct stores choices as properties):

```monkeyc
// Review focus: the Instinct's saved choices (Slots.Type numbers 0-10 from before this change)
// keep their meaning, and a saved value out of range or of the wrong kind falls back to the default.
(:test)
function savedSlotNumbersKeepTheirMeaning(logger as Logger) as Boolean {
    var saved = TestSlots.save();
    Properties.setValue("Slot1", 7);
    var bodyBattery = FaceSlots.typeOf(1) == Slots.BODY_BATTERY;
    Properties.setValue("Slot1", 99);
    var high = FaceSlots.typeOf(1) == FaceSlots.DEFAULTS[0];
    Properties.setValue("Slot1", -1);
    var low = FaceSlots.typeOf(1) == FaceSlots.DEFAULTS[0];
    Properties.setValue("Slot1", "7");
    var text = FaceSlots.typeOf(1) == FaceSlots.DEFAULTS[0];
    TestSlots.restore(saved);
    return bodyBattery && high && low && text && Slots.CALORIES == 10 && Slots.SUN == 24;
}
```

Add `import Toybox.Application;` to `face/test-instinct/LayoutTests.mc` if it is missing.

- [ ] **Step 2: Create the test helpers.** Create `face/test-instinct/TestSlots.mc` and `face/test-round/TestSlots.mc` with this same content (Task 3 changes the Venu one):

```monkeyc
import Toybox.Lang;
import Toybox.Test;

// Sets slot choices for tests through this watch's own FaceSlots, and puts them back.
(:test)
module TestSlots {

    function set(slot as Number, type as Number) as Void {
        FaceSlots.setType(slot, type);
    }

    function setAll(type as Number) as Void {
        for (var slot = 1; slot <= FaceSlots.COUNT; slot++) {
            set(slot, type);
        }
    }

    function save() as Array<Number> {
        var types = [];
        for (var slot = 1; slot <= FaceSlots.COUNT; slot++) {
            types.add(FaceSlots.typeOf(slot));
        }
        return types;
    }

    function restore(saved as Array<Number>) as Void {
        for (var slot = 1; slot <= saved.size(); slot++) {
            set(slot, saved[slot - 1]);
        }
    }

    function reset() as Void {
        restore(FaceSlots.DEFAULTS.slice(0, FaceSlots.COUNT) as Array<Number>);
    }
}
```

- [ ] **Step 3: Point the existing tests at the new names.**
  - In `face/test/RenderTests.mc`:
    - In `faceRendersEverySlotTypeAndTheme`, replace the inner `for (var slot ...) { Slots.setType(slot, type); }` with `TestSlots.setAll(type);`, and the closing reset loop with `TestSlots.reset();`.
    - In `settingsMenuBuildsAndCycles`, use `FaceSlots.typeOf(1)` and `FaceSlots.setType(1, before)` in place of the `Slots.` versions.
  - In `face/test-round/RoundRenderTests.mc`, make the same `TestSlots.setAll(type)` / `TestSlots.reset()` replacement.
  - In `face/test-round/RoundLayoutTests.mc`:
    - Delete `sunRingFlipsAtSunriseAndSunset` (moved to `SlotsTests`), `ringDataGivesTextForEveryType` (now `everyTypeGivesText`) and `batteryRingShowsDays` (`RingData.value` is gone).
    - In `progressIsClamped`, replace `RingData.progress(Slots.STEPS)` with `Slots.progress(Slots.STEPS, null)` and `RingData.progress(Slots.HEART_RATE)` with `Slots.progress(Slots.HEART_RATE, null)`.
    - In `holdOnRingTargetsItsComplication`:
      - replace `var saved = [Slots.typeOf(1), ...]` with `var saved = TestSlots.save();`;
      - replace each `Slots.setType(n, X)` with `TestSlots.set(n, X)`, deleting the `Slots.setType(5, ...)` line;
      - replace the final restore loop with `TestSlots.restore(saved);`;
      - replace `RingData.complicationType(RingData.nextSun(` with `Slots.complicationType(Slots.nextSun(`.
    - Append the following test:

```monkeyc
// Every type has a Venu ring colour.
(:test)
function everyTypeHasAColour(logger as Logger) as Boolean {
    return RingData.COLORS.size() == Slots.TYPE_COUNT;
}
```

- [ ] **Step 4: Run the tests to see them fail.** Build the Venu tests: `monkeyc -d venu441mm -f monkey.jungle -o bin/test-venu441mm.prg -y $K -t`. Expected: compile errors such as `Undefined symbol ':format'`, `':ratio'` and `':TestSlots'`.

- [ ] **Step 5: Write `face/source/Slots.mc`.** Replace the whole file:

```monkeyc
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.WatchUi;

// The widgets a slot can show on either watch: what each is, where its reading comes from (the
// watch's own complication first, then the face's own sources), how it reads and whether it is a
// gauge. Which widget each slot holds is up to each watch's FaceSlots.
module Slots {

    // Saved settings hold these numbers, so new types only ever go at the end.
    enum Type {
        NONE, HEART_RATE, BATTERY, STEPS, ALTITUDE, SUNRISE, SUNSET,
        BODY_BATTERY, SOLAR, NOTIFICATIONS, CALORIES,
        STRESS, FLOORS, INTENSITY, TEMPERATURE, HIGH_LOW, PULSE_OX, RESPIRATION, SLEEP_SCORE,
        PRESSURE, RECOVERY, VO2_MAX, NEXT_EVENT, RUN_WEEK, SUN
    }
    const TYPE_COUNT = 25;
    const SLOT_COUNT = 6;

    // The order lists offer the types in (the Instinct's slot lists, the Venu's editor), Empty last.
    const ORDER = [HEART_RATE, BATTERY, BODY_BATTERY, STRESS, STEPS, FLOORS, INTENSITY, CALORIES,
                   SLEEP_SCORE, PULSE_OX, RESPIRATION, RECOVERY, VO2_MAX, RUN_WEEK, ALTITUDE, PRESSURE,
                   TEMPERATURE, HIGH_LOW, SUN, SUNRISE, SUNSET, SOLAR, NOTIFICATIONS, NEXT_EVENT, NONE];

    // Glyphs in the Instinct's Icons font (tools/make_assets.py), indexed by Type. SUN draws the
    // glyph of the next sunrise or sunset (resolve).
    const ICONS = ["", "H", "B", "S", "A", "R", "T", "Y", "O", "N", "C",
                   "X", "F", "I", "E", "L", "P", "W", "Z", "G", "K", "V", "D", "U", ""];

    // The watch's complication behind each type (Complications.Type numbers: heart rate 18,
    // battery 1, steps 2, altitude 15, sunrise 13, sunset 14, Body Battery 23, solar input 37,
    // notifications 17, calories 3, stress 22, floors 4, intensity minutes 5, temperature 38,
    // high/low 39, pulse ox 35, respiration 36, sleep score 42, sea-level pressure 16, recovery
    // time 21, VO2 max run 24, calendar events 12, weekly run distance 19), or -1. It is also
    // what a hold on a Venu ring opens.
    const COMPLICATIONS = [-1, 18, 1, 2, 15, 13, 14, 23, 37, 17, 3,
                           22, 4, 5, 38, 39, 35, 36, 42, 16, 21, 24, 12, 19, -1];

    // Types with a natural 0..1 progress (progress).
    const GAUGES = [BATTERY, STEPS, BODY_BATTERY, STRESS, FLOORS, INTENSITY, SLEEP_SCORE, SUN];

    function names() as Array<ResourceId> {
        return [Rez.Strings.SlotNone, Rez.Strings.SlotHeartRate, Rez.Strings.SlotBattery, Rez.Strings.SlotSteps,
                Rez.Strings.SlotAltitude, Rez.Strings.SlotSunrise, Rez.Strings.SlotSunset, Rez.Strings.SlotBodyBattery,
                Rez.Strings.SlotSolar, Rez.Strings.SlotNotifications, Rez.Strings.SlotCalories,
                Rez.Strings.SlotStress, Rez.Strings.SlotFloors, Rez.Strings.SlotIntensity, Rez.Strings.SlotTemperature,
                Rez.Strings.SlotHighLow, Rez.Strings.SlotPulseOx, Rez.Strings.SlotRespiration, Rez.Strings.SlotSleepScore,
                Rez.Strings.SlotPressure, Rez.Strings.SlotRecovery, Rez.Strings.SlotVo2Max, Rez.Strings.SlotNextEvent,
                Rez.Strings.SlotRunWeek, Rez.Strings.SlotSun];
    }

    function complicationType(type as Number) as Number {
        return COMPLICATIONS[type] as Number;
    }

    // The type a complication type stands for, or NONE for one the face does not show.
    function fromComplication(ct as Number?) as Number {
        if (ct == null || ct < 0) {
            return NONE;
        }
        var t = COMPLICATIONS.indexOf(ct);
        return t < 0 ? NONE : t;
    }

    function isGauge(type as Number) as Boolean {
        return GAUGES.indexOf(type) >= 0;
    }

    // Whether this watch can show type: Solar only with solar charging (AMOLED watches have none),
    // the newer types only where the watch publishes their complication, the rest always (they
    // have the face's own sources).
    function available(type as Number) as Boolean {
        if (type == SOLAR) {
            return !System.getDeviceSettings().requiresBurnInProtection;
        }
        return type < STRESS || type == SUN || complication(type) != null;
    }

    // ORDER without the types this watch cannot show.
    function offered() as Array<Number> {
        var list = [];
        for (var i = 0; i < ORDER.size(); i++) {
            if (available(ORDER[i])) {
                list.add(ORDER[i]);
            }
        }
        return list;
    }

    // The watch's complication behind type, or null where it has none.
    function complication(type as Number) as Complications.Complication? {
        var ct = COMPLICATIONS[type] as Number;
        if (ct < 0 || !(Toybox has :Complications)) {
            return null;
        }
        try {
            return Complications.getComplication(new Complications.Id(ct as Complications.Type));
        } catch (e) {
            Parasha.log("no complication " + ct + ": " + e.getErrorMessage());
            return null;
        }
    }

    // SUN shows the next sunrise or sunset; every other type is itself.
    function resolve(type as Number, sun as Array<Number>?) as Number {
        return type == SUN ? nextSun(sun, now())[0] as Number : type;
    }

    // Seconds since local midnight.
    function now() as Number {
        var c = System.getClockTime();
        return c.hour * 3600 + c.min * 60 + c.sec;
    }

    // Text for a slot type; "--" when the watch has no reading.
    function value(type as Number, sun as Array<Number>?) as String {
        switch (type) {
            case NONE:
                return "";
            case SUN:
                return value(resolve(type, sun), sun);
            case SUNRISE:
                return SunTimes.format(sun == null ? null : sun[0]);
            case SUNSET:
                return SunTimes.format(sun == null ? null : sun[1]);
            case BATTERY:
                return battery();
            case SOLAR:
                var s = System.getSystemStats().solarIntensity;
                return (s == null || s < 0) ? "--" : s.format("%d") + "%";
        }
        var settings = System.getDeviceSettings();
        var units = type == TEMPERATURE ? settings.temperatureUnits : settings.distanceUnits;
        return format(type, reading(type), units == System.UNIT_STATUTE);
    }

    // The reading behind type: the watch's complication first, then the face's own source for the
    // original types; null without one.
    function reading(type as Number) {
        var c = complication(type);
        if (c != null && c.value != null) {
            return c.value;
        }
        switch (type) {
            case HEART_RATE:
                return heartRate();
            case STEPS:
                return ActivityMonitor.getInfo().steps;
            case ALTITUDE:
                return altitude();
            case BODY_BATTERY:
                return latestSample(:getBodyBatteryHistory);
            case NOTIFICATIONS:
                return System.getDeviceSettings().notificationCount;
            case CALORIES:
                return ActivityMonitor.getInfo().calories;
        }
        return null;
    }

    // How a reading reads: whole numbers rounded to the nearest, with a unit where the native faces
    // show one; the watch's own strings as they are; "--" without a reading. imperial: °F for
    // temperature, miles for distance.
    function format(type as Number, v, imperial as Boolean) as String {
        if (v == null) {
            return "--";
        }
        if (v instanceof String) {
            return v;
        }
        if (!(v instanceof Number || v instanceof Float || v instanceof Long || v instanceof Double)) {
            return "--";
        }
        switch (type) {
            case ALTITUDE:
                return whole(v) + "m";
            case TEMPERATURE:
                return whole(imperial ? v * 9.0 / 5.0 + 32 : v) + "°";
            case PULSE_OX:
                return whole(v) + "%";
            case PRESSURE:
                return whole(v / 100.0);
            case RECOVERY:
                return whole(v / 60.0) + "h";
            case RUN_WEEK:
                var d = v / (imperial ? 1609.344 : 1000.0);
                return (d < 99.95 ? d.format("%.1f") : whole(d)) + (imperial ? "mi" : "km");
        }
        return whole(v);
    }

    // A reading as a whole number, rounded to the nearest like the watch's own screens (format("%d")
    // would cut 2.8 days down to 2).
    function whole(v as Numeric) as String {
        return (v instanceof Float || v instanceof Double ? Math.round(v) : v).toNumber().format("%d");
    }

    // 0..1 for gauges: battery, Body Battery, stress and sleep score out of 100; steps, floors and
    // this week's intensity minutes against the watch's goals; SUN the day or night so far. -1 for
    // the other types or without a reading.
    function progress(type as Number, sun as Array<Number>?) as Float {
        switch (type) {
            case BATTERY:
                return clamp(System.getSystemStats().battery / 100.0);
            case BODY_BATTERY:
                return ratio(reading(type), 100);
            case STRESS:
                return ratio(reading(type), 100);
            case SLEEP_SCORE:
                return ratio(reading(type), 100);
            case STEPS:
                return ratio(reading(type), ActivityMonitor.getInfo().stepGoal);
            case FLOORS:
                return ratio(reading(type), ActivityMonitor.getInfo().floorsClimbedGoal);
            case INTENSITY:
                return ratio(reading(type), ActivityMonitor.getInfo().activeMinutesWeekGoal);
            case SUN:
                return nextSun(sun, now())[1] as Float;
        }
        return -1.0;
    }

    // v / goal within 0..1, or -1 without a numeric reading or a goal.
    function ratio(v, goal) as Float {
        if (!(v instanceof Number || v instanceof Float || v instanceof Long || v instanceof Double)
                || goal == null || goal <= 0) {
            return -1.0;
        }
        return clamp(v.toFloat() / goal);
    }

    function clamp(p as Float) as Float {
        return p < 0.0 ? 0.0 : (p > 1.0 ? 1.0 : p);
    }

    // [SUNSET or SUNRISE, progress] for the next of the two, with how far the day (sunrise to
    // sunset) or the night (sunset to the next sunrise, taken at today's times) has run. sun is
    // [sunrise, sunset] in seconds after midnight, either way round past midnight; without it,
    // sunrise and an empty arc.
    function nextSun(sun as Array<Number>?, now as Number) as Array {
        if (sun == null) {
            return [SUNRISE, 0.0];
        }
        var day = (sun[1] - sun[0] + 86400) % 86400;
        var sinceRise = (now - sun[0] + 86400) % 86400;
        if (sinceRise < day) {
            return [SUNSET, sinceRise.toFloat() / day];
        }
        return [SUNRISE, (sinceRise - day).toFloat() / (86400 - day)];
    }

    // The next type offered after type, wrapping round to Empty. (Removed in Task 2.)
    function next(type as Number) as Number {
        var n = (type + 1) % TYPE_COUNT;
        while (!available(n)) {
            n = (n + 1) % TYPE_COUNT;
        }
        return n;
    }

    // Battery as days left where the watch estimates them (like the native faces), else percent.
    function battery() as String {
        var stats = System.getSystemStats();
        if ((stats has :batteryInDays) && stats.batteryInDays != null) {
            return whole(stats.batteryInDays) + "d";
        }
        return whole(stats.battery) + "%";
    }

    function heartRate() as Number? {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) {
            return info.currentHeartRate;
        }
        if (ActivityMonitor has :getHeartRateHistory) {
            var sample = ActivityMonitor.getHeartRateHistory(1, true).next();
            if (sample != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                return sample.heartRate;
            }
        }
        return null;
    }

    function altitude() as Numeric? {
        var info = Activity.getActivityInfo();
        if (info != null && info.altitude != null) {
            return info.altitude;
        }
        return latestSample(:getElevationHistory);
    }

    function latestSample(history as Symbol) as Numeric? {
        if (!(Toybox has :SensorHistory) || !(SensorHistory has history)) {
            return null;
        }
        var getter = new Lang.Method(SensorHistory, history);
        var sample = getter.invoke({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST}).next();
        return sample == null ? null : sample.data;
    }
}
```

`fromComplication` relies on `COMPLICATIONS.indexOf(ct)`. Every complication number appears once in the array, and only the two `-1` entries repeat, which the `ct < 0` check excludes. If the compiler's type checker rejects `indexOf` on a `const` array, loop over the array instead.

- [ ] **Step 6: Add the strings.** In `face/resources/strings/strings.xml`, after `SlotCalories`, add:

```xml
    <string id="SlotStress">Stress</string>
    <string id="SlotFloors">Floors climbed</string>
    <string id="SlotIntensity">Intensity minutes</string>
    <string id="SlotTemperature">Temperature</string>
    <string id="SlotHighLow">High/low temperature</string>
    <string id="SlotPulseOx">Pulse ox</string>
    <string id="SlotRespiration">Respiration</string>
    <string id="SlotSleepScore">Sleep score</string>
    <string id="SlotPressure">Pressure</string>
    <string id="SlotRecovery">Recovery time</string>
    <string id="SlotVo2Max">VO2 max</string>
    <string id="SlotNextEvent">Next event</string>
    <string id="SlotRunWeek">Weekly run distance</string>
    <string id="SlotSun">Sunrise/sunset</string>
```

- [ ] **Step 7: Move the slot choice into FaceSlots.** Replace `face/source-instinct/FaceSlots.mc` with the following:

```monkeyc
import Toybox.Application;
import Toybox.Lang;

// How many of the swappable slots this face shows, their defaults (also in
// resources/settings/properties.xml), and the user's choice for each, saved as Slots.Type numbers
// in the SlotN properties by the settings menu.
module FaceSlots {
    const COUNT = 6;
    const DEFAULTS = [Slots.HEART_RATE, Slots.BATTERY, Slots.STEPS, Slots.ALTITUDE, Slots.SUNRISE, Slots.SUNSET];

    // slot is 1-based.
    function typeOf(slot as Number) as Number {
        var v = Properties.getValue("Slot" + slot);
        return (v instanceof Number && v >= 0 && v < Slots.TYPE_COUNT) ? v : DEFAULTS[slot - 1];
    }

    function setType(slot as Number, type as Number) as Void {
        Properties.setValue("Slot" + slot, type);
    }
}
```

Replace `face/source-round/FaceSlots.mc` with the same file, changing only these three things (Task 3 replaces this with the editor):
- the first comment line: `// How many of the swappable slots this face shows (four places, slot N at place N: 1-2 the top row, 3-4 the bottom; the sun ring above 6 always shows the next sunrise or sunset), ...`
- `COUNT = 4`
- `DEFAULTS = [Slots.HEART_RATE, Slots.ALTITUDE, Slots.BATTERY, Slots.STEPS, Slots.SUNRISE, Slots.SUNSET]`

- [ ] **Step 8: Update the callers.**
  - **Instinct `face/source-instinct/HebrewFaceView.mc`, `drawSlots`:** use `FaceSlots.typeOf(...)` for the five types, and draw each icon as the shown type:

```monkeyc
    function drawSlots(dc as Dc, sun as Array<Number>?) as Void {
        var types = [FaceSlots.typeOf(1), FaceSlots.typeOf(2), FaceSlots.typeOf(4), FaceSlots.typeOf(5), FaceSlots.typeOf(6)];
        var texts = [null, null, null, null, null] as Array<String?>;
        for (var i = 0; i < types.size(); i++) {
            texts[i] = types[i] == Slots.NONE ? null : Slots.value(types[i], sun);
            types[i] = Slots.resolve(types[i], sun);
        }
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        var pair = Layout.line(dc, Layout.PAIR_Y, texts[0], texts[1]);
        drawItem(dc, pair[0], types[0], texts[0]);
        drawItem(dc, pair[1], types[1], texts[1]);
        drawItem(dc, Layout.line(dc, Layout.SLOT4_Y, texts[2], null)[0], types[2], texts[2]);
        var bottom = Layout.bottomRow(dc, texts[3], texts[4]);
        drawItem(dc, bottom[0], types[3], texts[3]);
        drawItem(dc, bottom[1], types[4], texts[4]);
    }
```
  - **Instinct `drawWindow`:**

```monkeyc
    function drawWindow(dc as Dc, sun as Array<Number>?) as Void {
        var type = FaceSlots.typeOf(3);
        if (type != Slots.NONE) {
            Window.draw(dc, _windowX, _windowY, _windowR, Slots.resolve(type, sun), Slots.value(type, sun),
                Slots.progress(type, sun), _iconFont as FontResource, _fg, _bg);
        }
    }
```
  - **`face/source-instinct/Window.mc`:** change the comment `(Slots.progress: steps to the daily goal, battery, Body Battery)` to `(Slots.progress)`, and the `type` parameter's role to "the type whose icon shows (Slots.resolve)" in the header comment.
  - **`face/source/SettingsMenu.mc`:** replace `Slots.typeOf` with `FaceSlots.typeOf` and `Slots.setType` with `FaceSlots.setType`.
  - **Venu `face/source-round/RingData.mc`:**
    - Delete `complicationType`, `complicationValue`, `value`, `progress`, `nextSun` and `isGauge`. Drop the now-unused `import Toybox.Complications;`.
    - Change `ringed` to call `Slots.isGauge(type)`.
    - Extend `COLORS` and its comment to every type:

```monkeyc
    // Indexed by Slots.Type: none, HR, battery, steps, altitude, sunrise, sunset, Body Battery,
    // solar, notifications, calories, stress, floors, intensity minutes, temperature, high/low,
    // pulse ox, respiration, sleep score, pressure, recovery, VO2 max, next event, weekly run,
    // sun (unused: SUN takes the colour of the next sunrise or sunset).
    const COLORS = [0x000000, 0xFF4D5E, 0x4CD964, 0x3FA9F5, 0xB8C2CC, 0xFFC83D, 0xFF8A3D, 0x4FD8FF,
                    0xFFD000, 0xC79BFF, 0xFF7A45,
                    0xF5A623, 0x34C3A0, 0xFF6B9A, 0xFFA07A, 0xFFA07A, 0x7FA7FF, 0x7FE0D0, 0x9C8CFF,
                    0xB8C2CC, 0x8CD47E, 0xFF7AA2, 0x6FC3FF, 0x5AC8FA, 0x000000];
```
  - **Venu `face/source-round/HebrewFaceView.mc`, `drawRings`:**

```monkeyc
    function drawRings(dc as Dc, sun as Array<Number>?, now as Number, w as Number, off as Array<Number>, low as Boolean) as Void {
        for (var place = 1; place <= FaceSlots.COUNT; place++) {
            var type = FaceSlots.typeOf(place);
            var shown = Slots.resolve(type, sun);
            var iconId = RingData.icon(shown);
            if (type == Slots.NONE || iconId == null) {
                continue;
            }
            Rings.draw(dc, place, w, off, [bitmap(iconId as ResourceId), RingData.color(shown), Slots.value(type, sun),
                Slots.progress(type, sun), RingData.ringed(type, place)], low);
        }
        var next = Slots.nextSun(sun, now);
        var type = next[0] as Number;
        Rings.draw(dc, Rings.SUN, w, off,
            [bitmap(RingData.icon(type) as ResourceId), RingData.color(type), Slots.value(type, sun), next[1], true], low);
    }
```
  - **Venu `face/source-round/RingPressDelegate.mc`, `target`:**

```monkeyc
    static function target(x as Number, y as Number, width as Number) as Number {
        var place = Rings.hit(x, y, width);
        if (place == 0) {
            return -1;
        }
        var sun = Today.at(Time.now(), WatchSun.get())[2] as Array<Number>?;
        var type = place == Rings.SUN ? Slots.SUN : FaceSlots.typeOf(place);
        return Slots.complicationType(Slots.resolve(type, sun));
    }
```
    Then drop any imports in that file that are no longer used, such as `Toybox.Time.Gregorian`.

- [ ] **Step 9: Run both suites.**
  - Build and run the Venu tests, then the Instinct tests (commands in Global Constraints).
  - Expected: all pass. The counts change: the Venu loses three tests and gains `everyTypeHasAColour` plus the shared ones; the Instinct gains the shared ones and `savedSlotNumbersKeepTheirMeaning`.
  - If `everyTypeGivesText` or a render test crashes on a new type, fix the cause in `Slots`. Never weaken the test.

- [ ] **Step 10: Commit.**

```bash
git add face/source face/source-instinct face/source-round face/resources/strings/strings.xml face/test face/test-instinct face/test-round
git commit -m "Shared widget set: fourteen more types, one value reader, slot choice per watch" -m "<trailers>"
```

---

### Task 2: Instinct: icons and a list for each slot

**Files:**
- Modify: `tools/make_assets.py` (13 glyphs); regenerated `face/resources-instinct/fonts/icons.png`, `icons.fnt`
- Move and rewrite: `face/source/SettingsMenu.mc` → `face/source-instinct/SettingsMenu.mc`
- Modify: `face/source/HebrewFaceApp.mc` (`getSettingsView`), `face/source-instinct/FaceViews.mc`, `face/source-round/FaceViews.mc`
- Modify: `face/source/Slots.mc` (delete `next`)
- Modify: `face/resources-instinct/settings/settings.xml`
- Create: `face/test-instinct/SettingsTests.mc`
- Modify: `face/test/RenderTests.mc` (move the settings tests out), `face/test-instinct/LayoutTests.mc` (widest values, glyphs), `face/test-round/RoundLayoutTests.mc` (settings test)

**Interfaces:**
- Consumes: from Task 1, `Slots.offered()`, `Slots.names()`, `Slots.ICONS`, `FaceSlots.typeOf/setType` and `TestSlots`.
- Produces:
  - `FaceViews.settings() as [WatchUi.Views, WatchUi.InputDelegates] or Null`. The Instinct returns the menu; the Venu returns null.
  - `SettingsMenu.build()`, `SettingsMenu.title(slot) as ResourceId`, `SettingsMenu.slotList(slot) as WatchUi.CheckboxMenu`, `SettingsMenu.isLight()`, `SettingsMenu.themeName()`.
  - `class SettingsDelegate`, and `class SlotListDelegate(slot, slotItem)` with `pick(type)`.

- [ ] **Step 1: Write the failing tests.** Create `face/test-instinct/SettingsTests.mc`:

```monkeyc
import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;
import Toybox.WatchUi;

// The settings list every slot, each showing its widget, then the background.
(:test)
function settingsListEverySlotAndTheBackground(logger as Logger) as Boolean {
    var menu = SettingsMenu.build()[0] as WatchUi.Menu2;
    for (var slot = 1; slot <= FaceSlots.COUNT; slot++) {
        if (menu.findItemById(slot) != slot - 1) {
            return false;
        }
    }
    return menu.findItemById(:theme) == FaceSlots.COUNT;
}

// A slot's list offers every widget the watch can show, in Slots.ORDER with Empty last, and ticks
// only the slot's current one.
(:test)
function slotListTicksTheCurrentWidget(logger as Logger) as Boolean {
    var saved = TestSlots.save();
    TestSlots.set(2, Slots.STEPS);
    var list = SettingsMenu.slotList(2);
    var types = Slots.offered();
    var ticked = 0;
    var ok = list.getItem(types.size()) == null;
    for (var i = 0; i < types.size(); i++) {
        var item = list.getItem(i) as WatchUi.CheckboxMenuItem;
        ok = ok && item.getId() == types[i];
        if (item.isChecked()) {
            ticked++;
            ok = ok && types[i] == Slots.STEPS;
        }
    }
    TestSlots.restore(saved);
    return ok && ticked == 1 && types[types.size() - 1] == Slots.NONE;
}

// Picking a widget saves it for the slot and shows it under the slot's name.
(:test)
function pickingAWidgetSavesIt(logger as Logger) as Boolean {
    var saved = TestSlots.save();
    var item = new WatchUi.MenuItem("Slot 4", "", 4, null);
    new SlotListDelegate(4, item).pick(Slots.STRESS);
    var ok = FaceSlots.typeOf(4) == Slots.STRESS && item.getSubLabel() != null;
    TestSlots.restore(saved);
    return ok;
}

// The background item flips between dark and light.
(:test)
function backgroundItemFlipsTheTheme(logger as Logger) as Boolean {
    var delegate = SettingsMenu.build()[1] as SettingsDelegate;
    var theme = new WatchUi.MenuItem("Theme", "", :theme, null);
    var was = SettingsMenu.isLight();
    delegate.onSelect(theme);
    var flipped = SettingsMenu.isLight() != was;
    delegate.onSelect(theme);
    return flipped && SettingsMenu.isLight() == was;
}
```

  - In `face/test/RenderTests.mc`, delete `settingsMenuBuildsAndCycles`, `themeOnlyWithoutAmoled` and `solarSlotOnlyWithSolarCharging`; the menu is Instinct-only, and the solar rule is covered by `newerTypesNeedTheirComplication`.
  - In `face/test-round/RoundLayoutTests.mc`, replace `settingsListTheRingSlots` with:

```monkeyc
// The Venu has no settings menu: its widgets are picked in the watch's own face editor.
(:test)
function venuHasNoSettingsMenu(logger as Logger) as Boolean {
    return FaceViews.settings() == null;
}
```

Append to `face/test-instinct/LayoutTests.mc`:

```monkeyc
// Review focus: every type's icon is in the Icons font (a missing glyph draws nothing), each one
// glyph of the font's advance.
(:test)
function everyIconGlyphIsInTheFont(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var font = WatchUi.loadResource(Rez.Fonts.Icons) as FontResource;
    for (var t = 1; t < Slots.TYPE_COUNT; t++) {
        var glyph = Slots.ICONS[t] as String;
        if (t != Slots.SUN && (glyph.length() != 1 || dc.getTextWidthInPixels(glyph, font) != 14)) {
            logger.error("no glyph for type " + t);
            return false;
        }
    }
    return true;
}

// Review focus: the temperature's degree sign is in both slot fonts.
(:test)
function degreeSignIsInTheFonts(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    return dc.getTextWidthInPixels("°", Graphics.FONT_SMALL) > 0 && dc.getTextWidthInPixels("°", Graphics.FONT_XTINY) > 0;
}
```

Also add the new types' widest values to the existing width tests in `face/test-instinct/LayoutTests.mc`:
- `columnLinesFit`, `singles`: append `"-40°"`, `"120°"`, `"28/19"`, `"105/88"`, `"1085"`, `"96h"`, `"23:59"`, `"99.9km"`, `"999km"`, `"62.1mi"`.
- `anyPairStaysOnScreen`, `values`: append `"-40°"`, `"105/88"`, `"1085"`, `"96h"`, `"99.9km"`.
- `bottomRowFits`, `values`: append `"-40°"`, `"105/88"`, `"1085"`, `"96h"`, `"99.9km"`.
- `windowValuesFit`, `values`: append `"100"`, `"-40°"`, `"28/19"`, `"1085"`, `"96h"`, `"12.3km"`.

The window has no icon fallback. If a realistic window value fails `windowValuesFit`, keep the test strict and report it as DONE_WITH_CONCERNS with the measured widths; do not shorten any format.

- [ ] **Step 2: Run the Instinct tests to see them fail.** Build them. Expected: `Undefined symbol ':slotList'`, `':SlotListDelegate'` and `':settings'`.

- [ ] **Step 3: Add the glyphs.** In `tools/make_assets.py`, add these entries to the `ICONS` dict after `"C"`, keeping the existing entries as they are:

```python
    "X": """
.............
.............
.............
..#.....#....
.###...###...
##.##.##.##.#
#...###...###
.....#.....#.
.............
.............
.............
.............
.............""",  # stress (a jagged trace)
    "F": """
.............
.............
.........####
.........####
.........#...
......####...
......#......
...####......
...#.........
####.........
#............
#############
.............""",  # floors climbed (stairs)
    "I": """
.....###.....
......#......
...#######...
..##.....##..
.##...#...##.
.#....#....#.
.#....#....#.
.#....###..#.
.#.........#.
.##.......##.
..##.....##..
...#######...
.............""",  # intensity minutes (stopwatch)
    "E": """
.....###.....
....#...#....
....#.#.#....
....#.#.#....
....#.#.#....
....#.#.#....
....#.#.#....
...#.###.#...
..#.#####.#..
..#.#####.#..
..#..###..#..
...#.....#...
....#####....""",  # temperature (thermometer)
    "L": """
..#..........
.###.........
#####........
..#..........
..#..........
..#.......#..
..#.......#..
..........#..
..........#..
..........#..
........#####
.........###.
..........#..""",  # high/low temperature (up and down arrows)
    "P": """
......#......
.....###.....
.....###.....
....#####....
....#####....
...#######...
..#########..
..####.####..
..###...###..
..####.####..
...#######...
....#####....
.............""",  # pulse ox (a drop with an O)
    "W": """
......#......
......#......
...##.#.##...
..###.#.###..
.####.#.####.
.####...####.
.####...####.
.####...####.
.####...####.
.###.....###.
..#.......#..
.............
.............""",  # respiration (lungs)
    "Z": """
....####.....
..###........
.###.........
.##..........
###..........
###..........
###..........
###.........#
.###.......##
.####....###.
..#########..
....#####....
.............""",  # sleep score (crescent moon)
    "G": """
.............
....#####....
..##.....##..
.#.........#.
.#.......#.#.
#.......#...#
#......#....#
#.....#.....#
#....###....#
.#...###...#.
.............
.............
.............""",  # pressure (a dial)
    "K": """
.###########.
..#.......#..
..#.......#..
...#.....#...
....#.###....
.....###.....
......#......
.....#.#.....
....#...#....
...#..#..#...
..#..###..#..
..#.#####.#..
.###########.""",  # recovery time (hourglass)
    "V": """
.............
..###...###..
.#...#.#...#.
#.....#.....#
#...........#
#..#........#
####.#..#####
.#..#.#.#..#.
..#....#..#..
...#.....#...
....#...#....
.....#.#.....
......#......""",  # VO2 max (a heart with a pulse line)
    "D": """
..#.....#....
#############
#############
#...........#
#.##.##.##..#
#...........#
#.##.##.##..#
#...........#
#.##.##.....#
#...........#
#############
.............
.............""",  # next calendar event (calendar)
    "U": """
.........##..
.........##..
......####...
.....#.##.#..
....#..##..#.
......##.....
.....#..##...
....#.....#..
...#......#..
..#..........
.............
.............
.............""",  # weekly run distance (a runner)
```

Then run `python3 tools/make_assets.py` from the repo root and check `git status`:
- Only `face/resources-instinct/fonts/icons.png` and `icons.fnt` may change. The `.fnt` should say `chars count=23`.
- If the launcher icons, the band or the time font also change, restore them with `git checkout -- <file>` and report it.

- [ ] **Step 4: Write the menu.**
  - Run `git mv face/source/SettingsMenu.mc face/source-instinct/SettingsMenu.mc`.
  - Replace its content with:

```monkeyc
import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// On-watch settings (sideloaded apps get no phone settings): one item per slot, showing its
// widget and opening the list of widgets for it, then the background colour.
module SettingsMenu {

    function build() as [WatchUi.Views, WatchUi.InputDelegates] {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.SettingsTitle});
        var names = Slots.names();
        for (var slot = 1; slot <= FaceSlots.COUNT; slot++) {
            menu.addItem(new WatchUi.MenuItem(title(slot), names[FaceSlots.typeOf(slot)], slot, null));
        }
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.ThemeTitle, themeName(), :theme, null));
        return [menu, new SettingsDelegate()];
    }

    function title(slot as Number) as ResourceId {
        return [Rez.Strings.Slot1Title, Rez.Strings.Slot2Title, Rez.Strings.Slot3Title,
                Rez.Strings.Slot4Title, Rez.Strings.Slot5Title, Rez.Strings.Slot6Title][slot - 1];
    }

    // Every widget this watch offers for slot (Slots.offered), with the current one ticked and the
    // list opening on it.
    function slotList(slot as Number) as WatchUi.CheckboxMenu {
        var types = Slots.offered();
        var current = FaceSlots.typeOf(slot);
        var focus = types.indexOf(current);
        var list = new WatchUi.CheckboxMenu({:title => title(slot), :focus => focus < 0 ? 0 : focus});
        var names = Slots.names();
        for (var i = 0; i < types.size(); i++) {
            list.addItem(new WatchUi.CheckboxMenuItem(names[types[i]], null, types[i], types[i] == current, null));
        }
        return list;
    }

    function isLight() as Boolean {
        return Properties.getValue("Theme") == 1;
    }

    function themeName() as ResourceId {
        return isLight() ? Rez.Strings.ThemeLight : Rez.Strings.ThemeDark;
    }
}

class SettingsDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    // A slot opens its list; the background flips between dark and light.
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :theme) {
            Properties.setValue("Theme", SettingsMenu.isLight() ? 0 : 1);
            item.setSubLabel(SettingsMenu.themeName());
            WatchUi.requestUpdate();
        } else {
            var slot = id as Number;
            WatchUi.pushView(SettingsMenu.slotList(slot), new SlotListDelegate(slot, item), WatchUi.SLIDE_LEFT);
        }
    }
}

// A slot's list: picking a widget saves it, shows it under the slot's name and goes back; Back
// leaves the slot as it was.
class SlotListDelegate extends WatchUi.Menu2InputDelegate {

    var _slot as Number;
    var _slotItem as WatchUi.MenuItem;

    function initialize(slot as Number, slotItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _slot = slot;
        _slotItem = slotItem;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        pick(item.getId() as Number);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function pick(type as Number) as Void {
        FaceSlots.setType(_slot, type);
        _slotItem.setSubLabel(Slots.names()[type]);
        WatchUi.requestUpdate();
    }
}
```

- [ ] **Step 5: Route the settings per watch, and drop tap-to-cycle.**
  - In `face/source/HebrewFaceApp.mc`, `getSettingsView` returns `FaceViews.settings();`.
  - Add to `module FaceViews` in `face/source-instinct/FaceViews.mc`:

```monkeyc
    // The on-watch settings: a list of widgets for each slot, and the background.
    function settings() as [WatchUi.Views, WatchUi.InputDelegates] or Null {
        return SettingsMenu.build();
    }
```
  - Add to `module FaceViews` in `face/source-round/FaceViews.mc`:

```monkeyc
    // None: the Venu's widgets are picked in the watch's own face editor (FaceSlots).
    function settings() as [WatchUi.Views, WatchUi.InputDelegates] or Null {
        return null;
    }
```
  - Delete `Slots.next` from `face/source/Slots.mc`.
  - Update the header comment of `face/source-instinct/HebrewFaceView.mc` if it mentions cycling.

- [ ] **Step 6: Update the phone-settings mirror.** Regenerate `face/resources-instinct/settings/settings.xml` so every slot lists the types in `Slots.ORDER`. Run from the repo root:

```bash
python3 - <<'EOF'
order = [("1","SlotHeartRate"),("2","SlotBattery"),("7","SlotBodyBattery"),("11","SlotStress"),("3","SlotSteps"),
         ("12","SlotFloors"),("13","SlotIntensity"),("10","SlotCalories"),("18","SlotSleepScore"),("16","SlotPulseOx"),
         ("17","SlotRespiration"),("20","SlotRecovery"),("21","SlotVo2Max"),("23","SlotRunWeek"),("4","SlotAltitude"),
         ("19","SlotPressure"),("14","SlotTemperature"),("15","SlotHighLow"),("24","SlotSun"),("5","SlotSunrise"),
         ("6","SlotSunset"),("8","SlotSolar"),("9","SlotNotifications"),("22","SlotNextEvent"),("0","SlotNone")]
out = ["<settings>"]
for slot in range(1, 7):
    out.append(f'    <setting propertyKey="@Properties.Slot{slot}" title="@Strings.Slot{slot}Title">')
    out.append('        <settingConfig type="list">')
    out += [f'            <listEntry value="{v}">@Strings.{s}</listEntry>' for v, s in order]
    out.append('        </settingConfig>')
    out.append('    </setting>')
out += ['    <setting propertyKey="@Properties.Theme" title="@Strings.ThemeTitle">',
        '        <settingConfig type="list">',
        '            <listEntry value="0">@Strings.ThemeDark</listEntry>',
        '            <listEntry value="1">@Strings.ThemeLight</listEntry>',
        '        </settingConfig>',
        '    </setting>', '</settings>']
open("face/resources-instinct/settings/settings.xml", "w").write("\n".join(out) + "\n")
EOF
```

- [ ] **Step 7: Run both suites.**
  - Expected: all pass, including the four settings tests, the two glyph tests and the widened width tests on the Instinct, and `venuHasNoSettingsMenu` on the Venu.
  - If `anyPairStaysOnScreen` or `bottomRowFits` fails for a new value, the layout chain has a real gap. Report it as DONE_WITH_CONCERNS with the logged widths, and do not change the layout constants.

- [ ] **Step 8: Commit.**

```bash
git add tools/make_assets.py face/resources-instinct face/source face/source-instinct face/source-round face/test face/test-instinct face/test-round
git commit -m "Instinct: a list of widgets for each slot, icons for the new widgets" -m "<trailers>"
```

---

### Task 3: Venu: the watch's own face editor

**Files:**
- Modify: `tools/build-icons.mjs`; new PNGs in `face/resources-round/drawables/`; `face/resources-round/drawables/drawables.xml`
- Create: `face/resources-round/configs/watchface.xml`
- Modify: `face/source-round/FaceSlots.mc` (rewrite), `face/test-round/TestSlots.mc` (rewrite)
- Modify: `face/source-round/RingData.mc` (`icon`), `face/source-round/Rings.mc` (`box`), `face/source-round/HebrewFaceView.mc`, `face/source-round/RingPressDelegate.mc`, `face/source-round/FaceViews.mc`
- Create: `face/source-round/RingDrawable.mc`
- Modify: `face/manifest.xml` (`minApiLevel="5.1.0"`)
- Delete: `face/resources-round/settings/settings.xml`, `face/resources-round/settings/properties.xml`
- Test: `face/test-round/RoundLayoutTests.mc`, `face/test-round/RoundRenderTests.mc`

**Interfaces:**
- Consumes:
  - From Task 1: `Slots.*` and the Task 1 `RingData.COLORS`.
  - From Task 2: `FaceViews.settings()`, which returns null on the Venu.
- Produces:
  - `FaceSlots` (Venu): `COUNT = 5`, `DEFAULTS`, `forced` (test hook), `typeOf(slot)`, `load(id as WatchFaceConfig.Id?)`, `fromPairs(pairs as Array) as Array<Number>`.
  - `Rings.box(place, width) as Array<Number>`.
  - `HebrewFaceView`: `editing as Number` (0 = none), `places() as Array<Number>`, and `drawSlot(dc, place, sun, w, off, low)`.
  - `RingDrawable(view, place, box)`.
  - `RingPressDelegate(view)` with `onTap`, `getComplicationDrawable` and `onWatchFaceConfigEdited`.

- [ ] **Step 1: Write the failing tests.** Append to `face/test-round/RoundLayoutTests.mc`:

```monkeyc
// The editor's choices fill the five spots; a missing spot, an unknown or missing type, or a spot
// outside 1-5 keeps the default; Sunrise or Sunset in spot 5 is the flipping sun, elsewhere just
// that time.
// Review focus: odd editor settings never crash and never leave a spot unset.
(:test)
function editorChoicesMapToSpots(logger as Logger) as Boolean {
    var d = FaceSlots.DEFAULTS;
    var none = FaceSlots.fromPairs([]);
    var some = FaceSlots.fromPairs([[1, Complications.COMPLICATION_TYPE_STRESS],
                                    [3, Complications.COMPLICATION_TYPE_SLEEP_SCORE]]);
    var sunset5 = FaceSlots.fromPairs([[5, Complications.COMPLICATION_TYPE_SUNSET]]);
    var sunrise5 = FaceSlots.fromPairs([[5, Complications.COMPLICATION_TYPE_SUNRISE]]);
    var steps5 = FaceSlots.fromPairs([[5, Complications.COMPLICATION_TYPE_STEPS]]);
    var sunset2 = FaceSlots.fromPairs([[2, Complications.COMPLICATION_TYPE_SUNSET]]);
    var odd = FaceSlots.fromPairs([[1, Complications.COMPLICATION_TYPE_DATE], [9, Complications.COMPLICATION_TYPE_STEPS],
                                   [null, Complications.COMPLICATION_TYPE_STEPS], [2, null]]);
    return none.toString().equals(d.toString())
        && some[0] == Slots.STRESS && some[2] == Slots.SLEEP_SCORE && some[1] == d[1] && some[4] == d[4]
        && sunset5[4] == Slots.SUN && sunrise5[4] == Slots.SUN && steps5[4] == Slots.STEPS
        && sunset2[1] == Slots.SUNSET && odd.toString().equals(d.toString())
        && d.size() == FaceSlots.COUNT && d[4] == Slots.SUN;
}

// The editor's highlight box holds its subdial with the stroke, inside the screen.
(:test)
function highlightBoxCoversItsSubdial(logger as Logger) as Boolean {
    var w = System.getDeviceSettings().screenWidth;
    for (var place = 1; place <= FaceSlots.COUNT; place++) {
        var p = Rings.centre(place, w);
        var reach = Rings.radius(place, w) + Rings.PEN * w / 390 / 2;
        var b = Rings.box(place, w);
        if (b[0] > p[0] - reach || b[1] > p[1] - reach || b[0] + b[2] < p[0] + reach || b[1] + b[3] < p[1] + reach
                || b[0] < 0 || b[1] < 0 || b[0] + b[2] > w || b[1] + b[3] > w) {
            logger.error("box " + place + " " + b);
            return false;
        }
    }
    return true;
}

// While a spot is being edited the face leaves it out, so only the editor's pulsing copy shows.
(:test)
function editedSpotIsLeftOut(logger as Logger) as Boolean {
    var view = new HebrewFaceView();
    var all = view.places().toString();
    view.editing = 3;
    var three = view.places().toString();
    view.editing = 0;
    return all.equals("[1, 2, 3, 4, 5]") && three.equals("[1, 2, 4, 5]");
}

// Spot 5 counts as the bottom row: gauges and the sun get a ring there, plain values do not.
(:test)
function spotFiveRingsItsGauges(logger as Logger) as Boolean {
    return RingData.ringed(Slots.STEPS, 5) && RingData.ringed(Slots.SUN, 5) && !RingData.ringed(Slots.HEART_RATE, 5);
}

// Every widget the editor offers has a Venu icon (Solar is not offered; SUN shows the sunrise or
// sunset icon).
(:test)
function everyOfferedTypeHasAnIcon(logger as Logger) as Boolean {
    for (var t = 1; t < Slots.TYPE_COUNT; t++) {
        if (t != Slots.SOLAR && t != Slots.SUN && RingData.icon(t) == null) {
            logger.error("no icon for " + t);
            return false;
        }
    }
    return true;
}

// Where the simulator has editor settings, its defaults (resources-round/configs/watchface.xml)
// match FaceSlots.DEFAULTS.
(:test)
function editorDefaultsMatchTheFace(logger as Logger) as Boolean {
    var settings = WatchFaceConfig.getSettings(null);
    if (settings == null || settings.complicationSettings == null) {
        logger.debug("simulator has no editor settings");
        return true;
    }
    var saved = FaceSlots.forced;
    FaceSlots.forced = null;
    FaceSlots.load(null);
    var ok = true;
    for (var spot = 1; spot <= FaceSlots.COUNT; spot++) {
        ok = ok && FaceSlots.typeOf(spot) == FaceSlots.DEFAULTS[spot - 1];
    }
    FaceSlots.forced = saved;
    return ok;
}
```

Add `import Toybox.Application.WatchFaceConfig;` to that file's imports.

Then change two existing tests:
- `holdOnRingTargetsItsComplication`, replacing the block after the `ok = ok && RingPressDelegate.target(top[0], top[1], w) == -1 && ...(w / 2, w / 2, w) == -1;` line:

```monkeyc
    TestSlots.set(5, Slots.SUN);
    var day = Today.at(Time.now(), WatchSun.get())[2] as Array<Number>?;
    var sun = Rings.centre(Rings.SUN, w);
    ok = ok && RingPressDelegate.target(sun[0], sun[1], w) == Slots.complicationType(Slots.resolve(Slots.SUN, day));
    TestSlots.set(5, Slots.STEPS);
    ok = ok && RingPressDelegate.target(sun[0], sun[1], w) == Complications.COMPLICATION_TYPE_STEPS;
    TestSlots.restore(saved);
    return ok;
```
- `defaultsPutGaugesInTheBottomRow`, adding `&& d[4] == Slots.SUN` to its return.

Before Task 3, the sun place was not a slot, so the hold test's spot-5 assertions fail until the editor lands.

- [ ] **Step 2: Run the Venu tests to see them fail.** Expected: compile errors `Undefined symbol ':fromPairs'`, `':box'`, `':places'`, `':editing'` and `':forced'`.

- [ ] **Step 3: Add the icons.**
  - Add to `ICONS` in `tools/build-icons.mjs`:

```js
  icon_stress: 'head-flash',
  icon_floors: 'stairs',
  icon_intensity: 'run-fast',
  icon_temperature: 'thermometer',
  icon_highlow: 'thermometer-lines',
  icon_pulseox: 'water-percent',
  icon_respiration: 'lungs',
  icon_sleep: 'sleep',
  icon_pressure: 'gauge',
  icon_recovery: 'timer-sand',
  icon_vo2max: 'heart-pulse',
  icon_nextevent: 'calendar',
  icon_runweek: 'run',
```
  - Run `cd tools && (test -d node_modules || npm install) && node build-icons.mjs`. Expected output: `wrote 25 icons`.
  - Check `git status`: the 12 existing PNGs must be unchanged, and 13 new PNGs appear.
  - If an MDI name is missing from `node_modules/@mdi/svg/svg/`, pick the closest existing name and say so in the report.
  - Add to `face/resources-round/drawables/drawables.xml`, before `</drawables>`:

```xml
    <bitmap id="IconStress" filename="icon_stress.png" automaticPalette="false"/>
    <bitmap id="IconFloors" filename="icon_floors.png" automaticPalette="false"/>
    <bitmap id="IconIntensity" filename="icon_intensity.png" automaticPalette="false"/>
    <bitmap id="IconTemperature" filename="icon_temperature.png" automaticPalette="false"/>
    <bitmap id="IconHighLow" filename="icon_highlow.png" automaticPalette="false"/>
    <bitmap id="IconPulseOx" filename="icon_pulseox.png" automaticPalette="false"/>
    <bitmap id="IconRespiration" filename="icon_respiration.png" automaticPalette="false"/>
    <bitmap id="IconSleep" filename="icon_sleep.png" automaticPalette="false"/>
    <bitmap id="IconPressure" filename="icon_pressure.png" automaticPalette="false"/>
    <bitmap id="IconRecovery" filename="icon_recovery.png" automaticPalette="false"/>
    <bitmap id="IconVo2Max" filename="icon_vo2max.png" automaticPalette="false"/>
    <bitmap id="IconNextEvent" filename="icon_nextevent.png" automaticPalette="false"/>
    <bitmap id="IconRunWeek" filename="icon_runweek.png" automaticPalette="false"/>
```
  - In `RingData.icon`, add before the closing `}` of the switch:

```monkeyc
            case Slots.STRESS: return Rez.Drawables.IconStress;
            case Slots.FLOORS: return Rez.Drawables.IconFloors;
            case Slots.INTENSITY: return Rez.Drawables.IconIntensity;
            case Slots.TEMPERATURE: return Rez.Drawables.IconTemperature;
            case Slots.HIGH_LOW: return Rez.Drawables.IconHighLow;
            case Slots.PULSE_OX: return Rez.Drawables.IconPulseOx;
            case Slots.RESPIRATION: return Rez.Drawables.IconRespiration;
            case Slots.SLEEP_SCORE: return Rez.Drawables.IconSleep;
            case Slots.PRESSURE: return Rez.Drawables.IconPressure;
            case Slots.RECOVERY: return Rez.Drawables.IconRecovery;
            case Slots.VO2_MAX: return Rez.Drawables.IconVo2Max;
            case Slots.NEXT_EVENT: return Rez.Drawables.IconNextEvent;
            case Slots.RUN_WEEK: return Rez.Drawables.IconRunWeek;
```
  - Update the comment above `icon` to: `Null for types without one (Solar, which the Venu does not offer, and SUN, which shows the icon of the next sunrise or sunset).`

- [ ] **Step 4: Declare the editor's spots.** Generate `face/resources-round/configs/watchface.xml`. Run from the repo root:

```bash
python3 - <<'EOF'
types = ["HEART_RATE", "BATTERY", "BODY_BATTERY", "STRESS", "STEPS", "FLOORS_CLIMBED", "INTENSITY_MINUTES",
         "CALORIES", "SLEEP_SCORE", "PULSE_OX", "RESPIRATION_RATE", "RECOVERY_TIME", "VO2MAX_RUN",
         "WEEKLY_RUN_DISTANCE", "ALTITUDE", "SEA_LEVEL_PRESSURE", "CURRENT_TEMPERATURE", "HIGH_LOW_TEMPERATURE",
         "SUNRISE", "SUNSET", "NOTIFICATION_COUNT", "CALENDAR_EVENTS"]
defaults = {1: "HEART_RATE", 2: "ALTITUDE", 3: "BATTERY", 4: "STEPS", 5: "SUNRISE"}
out = ["<resources>",
       "    <!-- The Venu's five spots for the watch's own face editor (FaceSlots): subdials 1-4 and spot 5,",
       "         the ring above 6. Same widgets and order as Slots.ORDER, without Solar and SUN; defaults as",
       "         FaceSlots.DEFAULTS (Sunrise in spot 5 shows whichever of sunrise and sunset comes next). -->",
       "    <watchface-config>", "        <data>"]
for spot in range(1, 6):
    out.append(f'            <complication id="{spot}">')
    for t in types:
        d = ' default="true"' if defaults[spot] == t else ""
        out.append(f"                <type{d}>Complications.COMPLICATION_TYPE_{t}</type>")
    out.append("            </complication>")
out += ["        </data>", "    </watchface-config>", "</resources>"]
open("face/resources-round/configs/watchface.xml", "w").write("\n".join(out) + "\n")
EOF
```

Check that the jungle picks up `resources-round/configs/`, since `round.resourcePath` includes `resources-round`. If the compiler ignores the folder, move the file to `face/resources-round/settings/watchface.xml` and say so in the report.

- [ ] **Step 5: Read the spots from the editor.**
  - Replace `face/source-round/FaceSlots.mc` with:

```monkeyc
import Toybox.Application;
import Toybox.Application.WatchFaceConfig;
import Toybox.Lang;

// The Venu's five spots: subdials 1-4 (slot N at place N, 1-2 the top row, 3-4 the bottom) and
// spot 5, the ring above 6. The user picks each spot's widget in the watch's own face editor
// (resources-round/configs/watchface.xml, with the same defaults as DEFAULTS); Sunrise or Sunset in
// spot 5 shows whichever comes next (Slots.SUN), as the native faces' sunrise/sunset does.
module FaceSlots {
    const COUNT = 5;
    const DEFAULTS = [Slots.HEART_RATE, Slots.ALTITUDE, Slots.BATTERY, Slots.STEPS, Slots.SUN];

    // Test hook: the spots' types, or null to follow the editor.
    var forced as Array<Number>? = null;
    var _types as Array<Number>? = null;

    // slot is 1-based.
    function typeOf(slot as Number) as Number {
        if (forced != null) {
            return (forced as Array<Number>)[slot - 1];
        }
        if (_types == null) {
            load(null);
        }
        return (_types as Array<Number>)[slot - 1];
    }

    // Reads the editor's choices for configuration id (null: the active one).
    function load(id as WatchFaceConfig.Id?) as Void {
        var pairs = [];
        try {
            var settings = WatchFaceConfig.getSettings(id);
            var refs = settings == null ? null : settings.complicationSettings;
            if (refs != null) {
                for (var i = 0; i < refs.size(); i++) {
                    var ref = refs[i];
                    pairs.add([ref.uniqueIdentifier, ref.complicationId == null ? null : ref.complicationId.getType()]);
                }
            }
        } catch (e) {
            Parasha.log("face config: " + e.getErrorMessage());
        }
        _types = fromPairs(pairs);
    }

    // [[spot, complication type], ...] -> each spot's Slots type: DEFAULTS where a spot is missing,
    // outside 1-5 or of a type the face does not show, and SUN for Sunrise or Sunset in spot 5.
    function fromPairs(pairs as Array) as Array<Number> {
        var types = DEFAULTS.slice(0, null) as Array<Number>;
        for (var i = 0; i < pairs.size(); i++) {
            var spot = (pairs[i] as Array)[0];
            var type = Slots.fromComplication((pairs[i] as Array)[1] as Number?);
            if (spot instanceof Number && spot >= 1 && spot <= COUNT && type != Slots.NONE) {
                types[spot - 1] = spot == COUNT && (type == Slots.SUNRISE || type == Slots.SUNSET) ? Slots.SUN : type;
            }
        }
        return types;
    }
}
```
  - Replace `face/test-round/TestSlots.mc` with:

```monkeyc
import Toybox.Lang;
import Toybox.Test;

// Sets the Venu's spots for tests through FaceSlots.forced (the editor's settings cannot be
// written from a test), and puts them back.
(:test)
module TestSlots {

    function set(slot as Number, type as Number) as Void {
        var types = save();
        types[slot - 1] = type;
        FaceSlots.forced = types;
    }

    function setAll(type as Number) as Void {
        for (var slot = 1; slot <= FaceSlots.COUNT; slot++) {
            set(slot, type);
        }
    }

    function save() as Array<Number> {
        var types = [];
        for (var slot = 1; slot <= FaceSlots.COUNT; slot++) {
            types.add(FaceSlots.typeOf(slot));
        }
        return types;
    }

    function restore(saved as Array<Number>) as Void {
        FaceSlots.forced = saved;
    }

    function reset() as Void {
        FaceSlots.forced = null;
    }
}
```

`save()` returns the current types, forced or from the editor. `restore` therefore always leaves a forced array behind. Tests that need the editor again call `reset()`. `RoundRenderTests` already ends with `TestSlots.reset()`.

- [ ] **Step 6: Draw five spots, and leave out the one being edited.**
  - In `face/source-round/HebrewFaceView.mc`:
    - Add the fields `var editing = 0;` (the spot the watch's editor is pulsing, 0 for none) and `var _sun = null as Array<Number>?;`.
    - In `onUpdate`, set `_sun = sun;` after `sun` is read, and call `drawRings(dc, sun, w, off, low);`.
    - Replace `drawRings` with the following:

```monkeyc
    // The five spots (rings only for gauges in the bottom row and spot 5), minus the one the watch's
    // editor is pulsing.
    function drawRings(dc as Dc, sun as Array<Number>?, w as Number, off as Array<Number>, low as Boolean) as Void {
        var list = places();
        for (var i = 0; i < list.size(); i++) {
            drawSlot(dc, list[i], sun, w, off, low);
        }
    }

    // Places to draw: all five, without the one being edited.
    function places() as Array<Number> {
        var list = [];
        for (var place = 1; place <= FaceSlots.COUNT; place++) {
            if (place != editing) {
                list.add(place);
            }
        }
        return list;
    }

    // One spot's subdial: its widget's icon, colour, value and ring (SUN shows the next sunrise or
    // sunset); nothing for Empty.
    function drawSlot(dc as Dc, place as Number, sun as Array<Number>?, w as Number, off as Array<Number>, low as Boolean) as Void {
        var type = FaceSlots.typeOf(place);
        var shown = Slots.resolve(type, sun);
        var iconId = RingData.icon(shown);
        if (type == Slots.NONE || iconId == null) {
            return;
        }
        Rings.draw(dc, place, w, off, [bitmap(iconId as ResourceId), RingData.color(shown), Slots.value(type, sun),
            Slots.progress(type, sun), RingData.ringed(type, place)], low);
    }

    // The latest sun times, for the editor's copy of a subdial (RingDrawable).
    function lastSun() as Array<Number>? {
        return _sun;
    }
```
    - In `onLayout`, call `FaceSlots.load(null);` so a fresh start reads the editor once. If the view has no `onLayout`, add one that also calls `View.onLayout(dc)` where the class requires it.
    - Update the header comment: "four subdials" becomes "five spots picked in the watch's face editor: four subdials and the ring above 6, which shows the next sunrise or sunset by default".
  - In `face/source-round/Rings.mc`, add the following:

```monkeyc
    // [x, y, width, height] around place's ring and its stroke, for the editor's highlight.
    function box(place as Number, width as Number) as Array<Number> {
        var p = centre(place, width);
        var r = radius(place, width) + PEN * width / 390 / 2 + 1;
        return [p[0] - r, p[1] - r, 2 * r, 2 * r];
    }
```
  - Change the `Rings` header comment so that place 5 is "spot 5, the ring above 6 (SUN), sunrise/sunset by default".

- [ ] **Step 7: Hook up the editor.**
  - Create `face/source-round/RingDrawable.mc`:

```monkeyc
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// One spot's subdial as a Drawable, for the watch's face editor to pulse while that spot is
// being edited (the face itself leaves the spot out meanwhile).
class RingDrawable extends WatchUi.Drawable {

    var _view as HebrewFaceView;
    var _place as Number;

    function initialize(view as HebrewFaceView, place as Number, box as Array<Number>) {
        Drawable.initialize({:locX => box[0], :locY => box[1], :width => box[2], :height => box[3]});
        _view = view;
        _place = place;
    }

    // The editor's dc shares the screen's origin, so the subdial draws at its usual place.
    function draw(dc as Dc) as Void {
        dc.setAntiAlias(true);
        _view.drawSlot(dc, _place, _view.lastSun(), System.getDeviceSettings().screenWidth, [0, 0], false);
    }
}
```
  - In `face/source-round/RingPressDelegate.mc`:
    - Give the class a `var _view as HebrewFaceView;` set by `initialize(view as HebrewFaceView)`.
    - Add `import Toybox.Application.WatchFaceConfig;` and `import Toybox.Graphics;`.
    - Change the header comment to: `Touch-and-hold on a subdial opens the matching native view (faces get no plain taps); in the watch's face editor, a tap selects a spot and the spot being edited is handed to the editor to pulse.`
    - Replace `target` with the following:

```monkeyc
    // Complication to open for a press at (x, y), or -1: the widget at that spot (SUN opens the
    // next sunrise or sunset); Empty or the centre opens nothing.
    static function target(x as Number, y as Number, width as Number) as Number {
        var place = Rings.hit(x, y, width);
        if (place == 0) {
            return -1;
        }
        var sun = Today.at(Time.now(), WatchSun.get())[2] as Array<Number>?;
        return Slots.complicationType(Slots.resolve(FaceSlots.typeOf(place), sun));
    }
```
    - Add these three handlers:

```monkeyc
    // Editor only: a tap on a subdial selects its spot.
    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var xy = event.getCoordinates();
        var place = Rings.hit(xy[0], xy[1], System.getDeviceSettings().screenWidth);
        if (place == 0) {
            return false;
        }
        setSelectedComplication(place);
        return true;
    }

    // Editor only: the spot being edited, drawn on its own for the editor to pulse; the face
    // leaves it out meanwhile.
    function getComplicationDrawable(ref as WatchFaceConfig.ComplicationRef) as WatchUi.Drawable or WatchUi.ComplicationDrawableRef or Null {
        var place = ref.uniqueIdentifier;
        if (place == null || place < 1 || place > FaceSlots.COUNT) {
            Parasha.log("editor asked for spot " + place);
            return null;
        }
        _view.editing = place;
        WatchUi.requestUpdate();
        var box = Rings.box(place, System.getDeviceSettings().screenWidth);
        var bounds = new Graphics.BoundingBox();
        bounds.addRectangle(box[0], box[1], box[2], box[3]);
        return new WatchUi.ComplicationDrawableRef({:drawable => new RingDrawable(_view, place, box), :boundingBox => bounds});
    }

    // Editor only: a changed choice is drawn at once; every spot shows again once a spot is no
    // longer being edited.
    function onWatchFaceConfigEdited(options as {:configId as WatchFaceConfig.Id, :type as WatchUi.WatchFaceConfigType or Null, :committed as Boolean}) as Void {
        FaceSlots.load(options[:configId] as WatchFaceConfig.Id?);
        if (options[:type] != WatchUi.WATCH_FACE_CONFIG_TYPE_COMPLICATION) {
            _view.editing = 0;
        }
        WatchUi.requestUpdate();
    }
```
  - In `face/source-round/FaceViews.mc`, use `initial()`:

```monkeyc
    function initial() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new HebrewFaceView();
        return [view, new RingPressDelegate(view)] as [WatchUi.Views, WatchUi.InputDelegates];
    }
```
    and update its comment to mention the editor.
  - In `face/manifest.xml`, set `minApiLevel="5.1.0"`.
  - Run `git rm face/resources-round/settings/settings.xml face/resources-round/settings/properties.xml`.
  - Check how `Graphics.BoundingBox` is constructed in the SDK sample `samples/ConfigurableWatchFace/source/ComplicationDrawable.mc`, and match it.

- [ ] **Step 8: Run both suites.**
  - Expected: all pass. The Venu's `roundFaceRendersAwakeAndAlwaysOn` now covers five spots, and the Instinct is unchanged.
  - Then run the Venu release build. Expected: `BUILD SUCCESSFUL` with no new errors from the config XML.
  - Log the result of `editorDefaultsMatchTheFace`: does the simulator have editor settings?

- [ ] **Step 9: Commit.**

```bash
git add tools/build-icons.mjs face/resources-round face/source-round face/test-round face/manifest.xml
git commit -m "Venu: widgets picked in the watch's own face editor, sun ring is spot 5" -m "<trailers>"
```

---

### Task 4: Diagnostics, docs, and simulator checks

**Files:**
- Modify: `face/source/Slots.mc` (`logComplications`), `face/source-instinct/HebrewFaceView.mc` and `face/source-round/HebrewFaceView.mc` (call it with the first-draw log)
- Modify: `README.md`, `docs/superpowers/specs/2026-10-19-venu-face-design.md`, `docs/superpowers/specs/2026-10-20-widget-settings-design.md` (one line: lists follow `Slots.ORDER`, grouped by kind, Empty last)
- Test: `face/test/SlotsTests.mc`

**Interfaces:**
- Consumes: everything above.
- Produces: `Slots.logComplications() as Void`.

- [ ] **Step 1: Write the failing test.** Append to `face/test/SlotsTests.mc`:

```monkeyc
// The face can list what the watch publishes into its log without failing.
(:test)
function complicationListLogs(logger as Logger) as Boolean {
    Slots.logComplications();
    return true;
}
```

- [ ] **Step 2: Run it to see it fail.** Expected: `Undefined symbol ':logComplications'`.

- [ ] **Step 3: Implement it.** Add to `module Slots`:

```monkeyc
    // One log line per complication the watch publishes (its type number and the watch's own
    // label), so the real list can be read off the face's log file.
    function logComplications() as Void {
        if (!(Toybox has :Complications)) {
            return;
        }
        var it = Complications.getComplications();
        for (var c = it.next(); c != null; c = it.next()) {
            Parasha.log("comp " + c.getType() + " " + c.longLabel);
        }
    }
```

Then call `Slots.logComplications();` right after the existing `Parasha.log("face mem " ...)` line in both `HebrewFaceView.onUpdate`s. On the Venu that is inside `if (!_loggedMemory)`; on the Instinct it is inside `if (_hebrewRd == -1)`.

- [ ] **Step 4: Run both suites.** Expected: all pass, and the test output shows `comp 1 Battery` ….

- [ ] **Step 5: Check the faces in the simulator by eye.**
  - Build both release files.
  - For each watch, set a mix of new widgets with a scratch test outside the repo, using an extra jungle file in the scratchpad that adds a scratch source path. On the Instinct, the scratch test calls `FaceSlots.setType`.
    - Instinct: 1 stress, 2 sleep score, 3 floors (a gauge in the window), 4 temperature, 5 pressure, 6 the sun.
  - On the Venu, properties don't drive the spots and `forced` lives only in the test build. So check the Venu through `roundFaceRendersAwakeAndAlwaysOn`, plus a scratch test that draws a `BufferedBitmap` and saves nothing. Report that the Venu's look with new widgets is checked on the watch.
  - Run each face with `monkeydo bin/<file>.prg <dev>` in the background, wait for `face mem` in its output, capture the window with `screencapture -x -o -l <window id>`, and look at the image.
  - Check: every icon shows, the degree sign shows, nothing overlaps, and the Instinct's `face mem` stays well under 65536.
  - Record the `face mem` numbers in the report.

- [ ] **Step 6: Update the docs.**
  - **README:** list the new widgets once. The Venu picks widgets in the watch's own editor (Watch Face → Hebrew Face → Data), with five spots, the ring above 6 being spot 5. The Instinct's settings show a list per slot.
  - **Venu spec:**
    - Its "Subdials" and settings parts: the editor, five spots, and spot 5 behaviour.
    - Its testing notes: the Venu has no settings menu any more.
  - **Widget spec:** the ORDER line.
  - Keep each edit short.

- [ ] **Step 7: Commit.**

```bash
git add face/source face/test README.md docs
git commit -m "Faces log the complications their watch publishes; docs for the widget settings" -m "<trailers>"
```
