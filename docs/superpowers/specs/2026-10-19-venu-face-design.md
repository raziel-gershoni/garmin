# Hebrew Face for Venu 4 — design

Date: 2026-10-19. Target: Venu 4 41 mm (`venu441mm`). Display: 390×390 round, colour AMOLED, touch, always-on display.

Builds on the Instinct 3 face (`2026-10-18-hebrew-face-design.md`). The data is the same: the Gregorian date in Hebrew, the full Hebrew date with sunset rollover, the parasha or holiday from Hebcal, and six swappable slots. The look is new, settled with the user over simulator mock-ups (throwaway probe, not in the repo).

## Look: awake (high power)

```
          ⌒ ח׳ חשון תשפ״ז ⌒          full Hebrew date curved along the top rim
        (♥)     ב׳ 19.10     (▮)      Gregorian in Hebrew under 12
        68                    88%
    (👣)           ●           (▲)    six ring subdials, three per side
    5123                       42m    hands pivot in the centre
        (☀↑)                (☀↓)
        06:44               18:03
          ⌣  פרשת לך־לך  ⌣            parasha / holiday curved along the bottom rim
```

- **Dial:** 60 grey minute ticks; 12 white hour marks, 4 px wide.
- **Top rim:** the full Hebrew date ("ח׳ חשון תשפ״ז"), white, in the Noto Sans Hebrew Bold vector font (~32 px). It is drawn with `drawRadialText` clockwise, centred on 12 o'clock, at radius `r − 44`.
- **Bottom rim:** the parasha or holiday, orange, same font. It is drawn counter-clockwise, centred on 6 o'clock, so it reads upright. If the title is too long for the arc, "פרשת " is dropped first, then the font steps down.
- **Curved text order:** curved text gets no right-to-left reordering (verified in the simulator), so rim strings are reversed character by character before drawing. They contain no digits.
- **Under 12:** "ב׳ 19.10", grey, drawn as two pieces as on the Instinct: the Hebrew weekday in Noto Sans Hebrew, the digits in Roboto. Straight text does get right-to-left reordering.
- **Ring subdials** (slots 1–6):
  - **Layout:** radius 38. Centres on a circle of radius 134 at −37°, 0° and +37° from 9 o'clock (slots 1, 3, 5) and from 3 o'clock (slots 2, 4, 6). So rows pair up as on the Instinct: 1–2, 3–4, 5–6.
  - **Contents:** a 4 px dark-grey track, with a 28 px icon at the top and the value under it in Roboto Condensed Bold 24.
  - **Gauge arc:** gauge slots get a coloured progress arc from 12 o'clock clockwise: battery %, Body Battery, and steps against the daily step goal.
- **Icons:** Material Design Icons, rendered by a tools script into white anti-aliased PNGs and drawn with `drawBitmap2` plus `:tintColor`. Bitmaps need `automaticPalette="false"`, or the tint throws. Their edges came out smoother than the icon-font route in the A/B test.
  - Colours: heart rate red, battery green, steps blue, altitude grey, sunrise yellow, sunset orange.
  - The battery icon shows its level (20/50/80/full) and turns red at ≤ 20%.
- **Hands:**
  - Shape: tapered polygons with a short tail, anti-aliased. The hour hand is 52% of the radius and the minute hand 80%.
  - Each hand is drawn white over a slightly larger black copy, a 3 px outline, so it stays distinct over the subdials.
  - Hub: orange with a black centre.
- **Seconds hand, awake only:** a thin orange hand matching the hub, with a short tail. The awake face redraws every second for the ~10 s after a wrist raise. In always-on there is no seconds hand: Garmin allows AMOLED faces only one redraw a minute there (the user chose this on 2026-10-19).

## Look: always-on (low power)

Same layout, dimmed. The user wants everything kept in this view.

- Hour marks only, dim grey. No minute ticks.
- Rim texts in Noto Sans Hebrew Regular, the thinner weight: date grey `#9A9A9A`, parasha dim orange `#9A7A30`. Gregorian date in dim grey.
- Rings: 2 px tracks in `#262626`. Arcs and icons at 45% of their colour. Values in Roboto Regular, grey `#8C8C8C`.
- Hands are outlines only (2 px light grey) over a black outline; the hub is a 2 px ring.
- **Burn-in protection:** the whole drawing shifts by up to ±3 px, cycling every minute.
- **Brightness budget:** measured from a simulator screenshot, about 3% mean luminance against Garmin's 10% limit. Lit pixels came to about 11%, inflated by screenshot blur. If the simulator's always-on checker flags pixel count, drop the ring tracks in low power (saves about 2.5%).
- **Switching:** chosen by `System.getDisplayMode() == DISPLAY_MODE_LOW_POWER` or `onEnterSleep`/`onExitSleep`. Low power redraws once a minute.

## Data

- **Slot values:** from the Complications API where the type exists. The Venu simulator publishes all 42 types with values, including HR, steps, battery, Body Battery, altitude, sunrise, sunset, notifications and calories. Fallback is the existing `Slots` code (ActivityMonitor / SensorHistory).
- **Slot options:** the Instinct list minus Solar (no solar on the Venu). Defaults: 1 HR, 2 battery, 3 steps, 4 altitude, 5 sunrise, 6 sunset.
- **Hebrew date, parasha and sunset rollover:** the shared `common/` code, unchanged. Sunrise/sunset come from complications, then NOAA, then Jerusalem.
- **Hold-to-open:** touch-and-hold on a ring opens the matching native view via `WatchFaceDelegate.onPress` + `Complications.exitTo`, where the type supports it. Faces get no plain taps.
- **Settings:** the same on-watch Menu2 for the six slots. The light theme is not offered on the Venu: AMOLED faces should stay black.

## Glance app

- **Glance view:** unchanged. It already sizes itself from the dc, and straight Hebrew renders in the system font on the Venu.
- **Detail view:** a round version. The Hebrew date on the top rim, the parasha on the bottom rim, the Gregorian date under 12, and sunrise/sunset ("זריחה 06:44", "שקיעה 18:03") in the middle.

## Project structure

- **One face project and one glance project.** Add `venu441mm` to both manifests.
- **Device-specific code** is split with jungle family qualifiers (verified in a scratch build):
  - `round.sourcePath` adds `source-round` (Venu view, layout, delegate).
  - `semioctagon.sourcePath` adds `source-instinct` (the current Instinct view and layout).
  - Shared code stays in `source` and `common/source`.
- **Venu resources:** `resources-round-390x390` holds the icon PNGs and a 54 px launcher icon.
- **Icons:** `tools/` gains the icon build script (`@mdi/svg` + `@resvg/resvg-js`). The generated PNGs are committed. The MDI licence text goes with them (Pictogrammers Free License / Apache 2.0).
- **Memory:** limits double on the Venu (face 128 KB, glance and background 64 KB). Bitmaps live in the 4 MB graphics pool.

## Testing

- **Unit tests** run on both devices. Common tests are unchanged; Instinct layout tests stay Instinct-only.
- **New Venu layout tests** check that:
  - every Hebrew date of a leap and a common year fits the top arc;
  - every parasha/holiday title fits the bottom arc;
  - the widest slot values fit inside a ring;
  - rings don't overlap each other or the rim texts.
- **Simulator:** screenshots of awake and always-on, from the user. The simulator's always-on checker (low-power warnings in the log) must stay silent.
- **On the watch:** the always-on look and brightness, hold-to-open, the settings entry, and battery over a day.

## Out of scope for now

- The 45 mm Venu 4 (`venu445mm`). The layout is in proportions of the radius, so adding it later is mostly a resource folder and a check.
- Zmanim, candle lighting, Omer and Shabbat mode (discussed as options; not requested).

Implemented: see plan 2026-10-19-venu-face-plan.md
