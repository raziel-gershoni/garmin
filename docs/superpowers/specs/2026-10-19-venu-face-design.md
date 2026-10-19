# Hebrew Face for Venu 4 — design

Date: 2026-10-19. Target: Venu 4 41 mm (`venu441mm`). Display: 390×390 round, colour AMOLED, touch, always-on display.

Builds on the Instinct 3 face (`2026-10-18-hebrew-face-design.md`). The data is the same: the Gregorian date in Hebrew, the full Hebrew date with sunset rollover, the parasha or holiday from Hebcal, and six swappable slots. The look is new, settled with the user over simulator mock-ups (throwaway probe, not in the repo).

## Look: awake (high power)

```
          ⌒ ח׳ חשון תשפ״ז ⌒          full Hebrew date curved along the top rim
         ♥      ב׳ 19.10      ▲       Gregorian in Hebrew under 12
         68                  42m      plain values on top, no rings
      ( ▮ )                ( 👣 )     gauges with rings below
       3d                   5123      capsule hands, no hub
              ( ☀↓ 18:03 )            next sunrise or sunset above 6
          ⌣  פרשת לך־לך  ⌣            parasha / holiday curved along the bottom rim
                   ╹                  the current second's tick lit orange
```
Revised 2026-10-19 after the user compared it with the Venu's own faces: capsule hands like the native numbered face, the seconds as the current tick lit orange, sunrise/sunset merged into one ring above 6, and the four remaining subdials larger. Only gauges keep a ring (a circle means nothing around a heart rate or an altitude), and they sit in the bottom row.

- **Dial:** 60 grey minute ticks; 12 white hour marks, 4 px wide.
- **Top rim:** the full Hebrew date ("ח׳ חשון תשפ״ז"), white, in the Noto Sans Hebrew Bold vector font (~32 px). It is drawn with `drawRadialText` clockwise, centred on 12 o'clock, at radius `r − 44`.
- **Bottom rim:** the parasha or holiday, orange, same font. It is drawn counter-clockwise, centred on 6 o'clock, so it reads upright. If the title is too long for the arc, "פרשת " is dropped first, then the font steps down.
- **Curved text order:** on the Venu 4 itself, curved text is laid out right-to-left like straight text, so rim strings stay in logical order. The simulator does not reorder curved text and shows rim lines backwards; an earlier build reversed them to suit the simulator, which made them read backwards on the watch (found on the user's Venu, 2026-10-19).
- **Under 12:** "ב׳ 19.10", grey, drawn as two pieces as on the Instinct: the Hebrew weekday in Noto Sans Hebrew, the digits in Roboto. Straight text does get right-to-left reordering.
- **Subdials** (slots 1–4):
  - **Layout:** places of radius 48, centred on a circle of radius 124 at +29° (top row) and −23° (bottom row) from 9 and 3 o'clock. Rings end inside the 5-second marks, which reach 18 px in from the edge (round end included).
  - **Placement:** plain values (heart rate, altitude, notifications, calories) take the top places and gauges the bottom ones, each group in slot order (`RingData.arrange`). The defaults give heart rate and altitude on top, battery and steps below.
  - **Contents:** a 34 px icon at the top and the value under it in Roboto Condensed Bold, up to 30. Gauges (battery, steps, Body Battery) also get a 7 px dark-grey track with the progress arc.
  - **Gauge arc:** a coloured progress arc from 12 o'clock clockwise: battery %, Body Battery, and steps against the daily step goal.
- **Sun ring** above 6: radius 42, 76 px below the centre. It shows the next sunrise or sunset: sunset with its arc filling from sunrise to sunset through the day, sunrise with its arc filling through the night (taken at today's times). Holding it opens that native view.
- **Icons:** Material Design Icons, rendered by a tools script into white anti-aliased PNGs and drawn with `drawBitmap2` plus `:tintColor`. Bitmaps need `automaticPalette="false"`, or the tint throws. Their edges came out smoother than the icon-font route in the A/B test.
  - Colours: heart rate red, battery green, steps blue, altitude grey, sunrise yellow, sunset orange.
  - The battery icon shows its level (20/50/80/full) and turns red at ≤ 20%.
- **Hands**, after the Venu's own numbered face:
  - Hour: a solid capsule 13 px wide whose centre line runs from 10% to 56% of the radius. Minute: a hollow capsule 9 px wide (2.5 px walls, black inside) from 6% to 90%. The round ends reach half the width past those points. Neither hand reaches the centre, and there is no hub.
  - Each hand is a thick anti-aliased line, which the watch draws with smooth round ends, over a black line 4 px wider (a 2 px outline); the minute hand's hollow is a black line 5 px narrower drawn over it. All share one centre line, so walls are even all the way round. Filled polygons came out fuzzy with faceted ends, and separate end circles drifted off the hand and looked detached (seen on the watch).
- **Seconds, awake only:** the tick at the current second is lit orange, a minute tick or a 5-second mark, so the seconds run round the dial on the ticks themselves. A separate orange dot was tried first: a smoothed circle and a smoothed line never centre on each other alike at every angle, so it looked off-centre on some seconds. The ticks are drawn at sub-pixel precision (float endpoints). The awake face redraws every second for the ~10 s after a wrist raise. In always-on there are no seconds: Garmin allows AMOLED faces only one redraw a minute there (the user chose this on 2026-10-19).

## Look: always-on (low power)

Same layout, dimmed. The user wants everything kept in this view.

- Hour marks only, dim grey. No minute ticks.
- Rim texts in Noto Sans Hebrew Regular, the thinner weight: date grey `#9A9A9A`, parasha dim orange `#9A7A30`. Gregorian date in dim grey.
- Rings: 3 px tracks in `#262626`. Arcs and icons at 45% of their colour. Values in Roboto Regular, grey `#8C8C8C`.
- Hands: the same capsules in dim grey `#7A7A7A`, the minute hand still hollow.
- **Burn-in protection:** the whole drawing shifts by up to ±2 px, cycling every minute.
- **Brightness budget:** measured from a simulator screenshot of the four-subdial layout (2026-10-19), about 3.8% mean luminance and 8.7% of pixels lit (above 40/255), against Garmin's 10% limit. If the simulator's always-on checker flags pixel count, drop the ring tracks in low power.
- **Switching:** chosen by `System.getDisplayMode() == DISPLAY_MODE_LOW_POWER` or `onEnterSleep`/`onExitSleep`. Low power redraws once a minute.

## Data

- **Slot values:** from the Complications API where the type exists. The Venu simulator publishes all 42 types with values, including HR, steps, battery, Body Battery, altitude, sunrise, sunset, notifications and calories. Fallback is the existing `Slots` code (ActivityMonitor / SensorHistory).
- **Slot options:** the Instinct list minus Solar (no solar on the Venu), for slots 1–4 (`FaceSlots.COUNT`). Defaults: 1 HR, 2 battery, 3 steps, 4 altitude. Slots 5–6 exist in the settings store but the Venu does not show them; the sun ring replaces them.
- **Hebrew date, parasha and sunset rollover:** the shared `common/` code, unchanged. Sunrise/sunset come from complications, then NOAA, then Jerusalem.
- **Hold-to-open:** touch-and-hold on a ring opens the matching native view via `WatchFaceDelegate.onPress` + `Complications.exitTo`, where the type supports it. Faces get no plain taps.
- **Settings:** the same on-watch Menu2, listing the four ring slots. The light theme is not offered on the Venu: AMOLED faces should stay black.

## Glance app

- **Glance view:** unchanged. It already sizes itself from the dc, and straight Hebrew renders in the system font on the Venu.
- **Detail view:** a round version. The Hebrew date on the top rim, the parasha on the bottom rim, the Gregorian date under 12, and sunrise/sunset ("זריחה 06:44", "שקיעה 18:03") in the middle.

## Project structure

- **One face project and one glance project.** Add `venu441mm` to both manifests.
- **Device-specific code** is split with jungle family qualifiers (verified in a scratch build):
  - `round.sourcePath` adds `source-round` (Venu view, layout, delegate).
  - `semioctagon.sourcePath` adds `source-instinct` (the current Instinct view and layout).
  - Shared code stays in `source` and `common/source`.
- **Venu resources:** `resources-round` holds the icon PNGs and a 54 px launcher icon.
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
