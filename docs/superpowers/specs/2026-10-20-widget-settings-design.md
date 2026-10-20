# Widget settings brush-up — design

Date: 2026-10-20. Branch: `instinct-digital`. Builds on the Venu face spec (`2026-10-19-venu-face-design.md`) and the fixed widget spots of `cc585a5`.

## What the user asked for

- "In the settings can you do some brushup? Can it be like the native faces? Or at least have more widget options and a list for each?"
- "Won't sunrise/sunset be slot 5?" The user showed a photo of the Venu's own editor, where a native face offers one combined "זריחה/שקיעה" (sunrise/sunset) choice.
- The user accepted every recommendation: approach A, a curated widget list (2a), and the sun ring as slot 5 (3a), plus a one-time list of the data sources each watch publishes.

## What Garmin allows (checked in SDK 9.2.0 docs, its samples and the simulator)

- **Venu 4 41 mm:** it supports the watch's own face editor for Connect IQ faces (Watch Face Configuration API, API 5.1.0). The face declares a `<watchface-config>` resource listing its data spots and the choices for each. The watch's Watch Face menu then offers **Data** for our face, as it does for native faces: you tap a spot, it pulses, and you swipe through the list. The list labels come from the watch, in the watch's language. The user can save up to four versions of the face.
  - Evidence: `doc/docs/Core_Topics/Editing_Watch_Faces_On_Device.html`; `WatchFaceConfig` and `WatchFaceDelegate.setSelectedComplication/getComplicationDrawable/onWatchFaceConfigEdited` list "Venu 4 41mm"; `samples/ConfigurableWatchFace` builds for `venu441mm`; the simulator has a "Watch Face Editor".
  - Not yet checked: that the watch offers it for a sideloaded face.
- **Instinct 3 Solar 45 mm:** it has no such API, since none of those classes list it. Its settings stay our own on-watch menu (`getSettingsView`). The list classes we need exist there: `Menu2` and `CheckboxMenu`, API 3.0.
- **Data sources:** both simulated watches publish 41–42 complications, the watch's own data feeds that a face can read by type. Sunrise and Sunset are two separate entries; there is no combined one. The simulator lists every type the SDK knows (it even gives the Venu "Solar Input"), so the real watches' lists may differ. The face logs the real lists once (see Diagnostics).

## Design

### 1. One shared widget set

The `Slots.Type` enum stays the widget identity on both watches. New types are appended after `CALORIES` (10), so the Instinct's saved choices (stored as these numbers) keep their meaning.

| # | Type | Watch data (complication) | Shown as | Gauge (0..1) |
|---|------|---------------------------|----------|--------------|
| 1–10 | existing: heart rate, battery, steps, altitude, sunrise, sunset, Body Battery, solar, notifications, calories | unchanged | unchanged | battery, steps, Body Battery |
| 11 | STRESS | STRESS | `42` | value / 100 |
| 12 | FLOORS | FLOORS_CLIMBED | `8` | floors / `floorsClimbedGoal` |
| 13 | INTENSITY | INTENSITY_MINUTES (this week) | `95` | minutes / `activeMinutesWeekGoal` |
| 14 | TEMPERATURE | CURRENT_TEMPERATURE | `23°`, °C or °F per the watch's units | – |
| 15 | HIGH_LOW | HIGH_LOW_TEMPERATURE | `28/19`: the watch's "H 28 / L 19" as its first two numbers, high/low; text without two numbers as it is | – |
| 16 | PULSE_OX | PULSE_OX | `96%` | – |
| 17 | RESPIRATION | RESPIRATION_RATE | `14` | – |
| 18 | SLEEP_SCORE | SLEEP_SCORE | `77` | value / 100 |
| 19 | PRESSURE | SEA_LEVEL_PRESSURE (Pa) | `1013`, hPa | – |
| 20 | RECOVERY | RECOVERY_TIME (minutes) | `5h`, rounded to the nearest hour | – |
| 21 | VO2_MAX | VO2MAX_RUN | `48` | – |
| 22 | NEXT_EVENT | CALENDAR_EVENTS | `14:30`, as the watch formats it | – |
| 23 | RUN_WEEK | WEEKLY_RUN_DISTANCE (m) | `12.3km`, km or mi per the watch's units, one decimal under 100 | – |
| 24 | SUN | none (our own) | the next sunrise or sunset, with its icon | the day or night so far |

- **Left out:** current weather (it needs an icon for each of about 50 conditions), training status (a long word that doesn't fit a widget), race predictions, date and weekday (the face already shows the date), and other apps' widgets (option 2b).
- **Values:** one shared reader, `Slots.value(type, sun)`.
  - It reads the watch's complication first where the type has one. Today only the Venu does this, in `RingData.value`; that logic moves into the shared code.
  - It then falls back to today's sources: heart-rate history, battery days, the face's own sun times, SensorHistory and ActivityMonitor.
  - With no reading, it shows `--`. Readings are whole numbers rounded to the nearest (`Slots.whole`).
- **Progress:** `Slots.progress(type)` covers the new gauges. Goals come from `ActivityMonitor.Info`.
- **Availability:**
  - `Slots.available(type)` hides a type when the watch lacks its data: no complication of that type, or no fallback.
  - Solar stays hidden on the Venu.
  - SUN is always available.

### 2. Venu: the watch's own editor

- **The `<watchface-config>` resource** lives in `resources-round` only. It declares data spots 1–5:
  - Spots 1–4 are the subdials, in the fixed places of `cc585a5`. Spot 5 is the ring above 6.
  - Every spot offers the same curated list: types 1–23 that have a complication, minus Solar, in `Slots.ORDER`.
  - Defaults: 1 heart rate, 2 altitude, 3 battery, 4 steps, 5 sunrise.
  - No styles and no colour pickers.
- **Reading the choice:**
  - `FaceSlots.typeOf(slot)` reads `WatchFaceConfig.getSettings(FaceSlots.configId).complicationSettings`. The face reads `:configId` from `onStart` (the settings the watch launches it with; null means the active ones), and an edit's `:configId` replaces it. It maps each spot's complication type back to our `Slots.Type`, and falls back to `FaceSlots.DEFAULTS` when the settings are missing or a type is unknown.
  - It caches the result, loading it in `onLayout` and again on `onWatchFaceConfigEdited`.
  - The Instinct's `FaceSlots.typeOf` keeps reading the `SlotN` properties.
  - `Slots.typeOf` goes away, and every caller uses `FaceSlots.typeOf`.
- **Spot 5:** Sunrise or Sunset there becomes SUN. That is today's ring, which flips to whichever comes next and arcs over the day or night. Any other choice shows that widget in place 5 instead.
- **Rings:** place 5 counts as the bottom row, so a gauge there gets its ring. `RingData.ringed` already returns true for places above 2, so it needs no change.
- **What the editor can't offer:** it lists only the watch's data types. So a Venu spot can't be left empty, and the combined SUN can't be picked in spots 1–4. Sunrise or Sunset there shows that one time only.
- **Editing mode:** the face keeps no editor-mode flag; the watch calls the editor handlers only while editing.
  - The face's `WatchFaceDelegate` gains three handlers:
    - `onTap` maps a tap to its place with `Rings.hit` and calls `setSelectedComplication(place)`.
    - `getComplicationDrawable` returns a `ComplicationDrawableRef` for that place: a small Drawable that draws the one subdial, with its bounding box.
    - `onWatchFaceConfigEdited` reloads the choices and redraws.
  - While a spot is being edited, the face leaves that subdial out, so only the system's pulsing copy shows (as the SDK sample does).
- **Outside editing mode:** hold-to-open (`onPress`) is unchanged, except that it opens the chosen complication.
- **Old menu:** the Venu's old settings menu goes away. `getSettingsView` returns null on the Venu. So do `resources-round/settings/settings.xml` (phone settings, never shown for sideloaded apps) and the `resources-round/settings/properties.xml` override.
- **Manifest:** `minApiLevel` rises from 4.2.0 to 5.1.0. Both watches run API 6.0, so nothing is lost.
- **If the watch doesn't offer the editor for a sideloaded face:** a follow-up gives the Venu the Instinct's list menu (section 3), which is shared code. No editor-specific code needs to stay for that.

### 3. Instinct: a list for each slot

- **Main menu:** the settings menu keeps its main list: Slot 1 (top left) … Slot 6 (bottom right), then Background.
- **Picking a slot:** this opens a `CheckboxMenu` titled with the slot's name.
  - It lists every available widget in `Slots.ORDER`, with Empty last.
  - Only the current one is ticked, and the list opens on it.
  - Picking an item saves it, ticks only that item, closes the list and shows the new choice under the slot's name.
  - Back leaves the slot unchanged.
- **Tap-to-cycle** (`Slots.next`) goes away.
- **Order:** the lists follow `Slots.ORDER`, which is grouped by kind (heart and energy, activity, health, place and weather, sun, other), with Empty last.
- **Icons:** each new type gets a 13×13 hand-drawn glyph in the Icons font (`tools/make_assets.py`, then regenerate `icons.png`/`icons.fnt`). SUN shows the sunrise or sunset glyph of the next event.
- **Slot 3:** the round window fills its arc for any gauge type, so the new gauges work there unchanged.
- **Width:** a new value too wide for its slot falls back through the existing chain: SMALL, then XTINY, then no icon, then clamp. Layout tests get each new type's widest value.
  - In the round window only, a value too wide in the smallest font drops its unit suffix ("12.3km" → "12.3"); times and strings never do.
- **Phone settings:** `resources-instinct/settings/settings.xml` (the phone-settings mirror) lists the new types.

### 4. Venu icons and colours

- Each new type gets a 34 px Material Design icon via `tools/build-icons.mjs`, plus a colour in `RingData.COLORS`.
  - Stress: head-flash. Floors: stairs. Intensity: run-fast. Temperature: thermometer. High/low: thermometer-lines. Pulse ox: water-percent. Respiration: lungs. Sleep: sleep. Pressure: gauge. Recovery: timer-sand. VO2 max: heart-pulse. Next event: calendar. Weekly run: run. SUN reuses the sunrise and sunset icons.
- The icon and colour arrays stay indexed by type. A test checks they cover every type.

### 5. Diagnostics: what each watch really publishes

- On its first draw, each face writes one line per complication the watch publishes: type number and the watch's own label. It goes to the face's log file, next to the existing "face mem" line.
- The user copies the log back once. It shows whether the real watches publish a combined sunrise/sunset, or other types the simulator doesn't know.
- Steps, for the user's report:
  1. The file `GARMIN/APPS/LOGS/HEBREWFACE.TXT` must exist on the watch; create it empty if it's missing.
  2. Wake the face once.
  3. Copy the file back into the repo's `logs/` folder.

## Testing

- **Unit tests (both watches):**
  - every type has a name, an icon and a colour or glyph;
  - the complication type ↔ widget type mapping goes both ways;
  - the new value formats work from raw readings: °C→°F, Pa→hPa, minutes→hours, metres→km/mi, missing → `--`;
  - the new gauges' progress, including clamping and missing goals;
  - every type renders in every place without crashing.
- **Venu:**
  - editor settings map to slot types, including Sunrise or Sunset in spot 5 becoming SUN, and missing or unknown settings falling back to the defaults;
  - a tap on each place selects that spot, and the centre selects nothing;
  - the highlight drawable's box covers its subdial;
  - the edited spot is left out of the face;
  - a gauge in place 5 gets a ring;
  - the `<watchface-config>` defaults match `FaceSlots.DEFAULTS`.
- **Instinct:**
  - the slot list holds every available type and Empty, with only the current one ticked;
  - picking saves and moves the tick;
  - each new type's widest value fits its slot (layout tests).
- **Simulator:** screenshots of both faces with the new widgets, and the "face mem" line on the Instinct (64 KB limit) before and after.
- **On the watch (user):** on the Venu, Watch Face → Hebrew Face → Data, editing each spot, including spot 5; on the Instinct, Customize → each slot's list; then send the log.

## Non-goals

- Data colour, accent colour and styles in the Venu editor.
- Other apps' widgets (allowAny).
- Weather condition, training status, race predictions.
- Hebrew labels in the Instinct menu (the app's settings strings stay English). The Venu editor's labels come from the watch.
- Any change to the glance.
