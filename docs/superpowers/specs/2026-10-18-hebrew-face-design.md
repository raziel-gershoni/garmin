# Hebrew Face — design

Date: 2026-10-18 · Target: Garmin Instinct 3 Tactical Solar (`instinct3solar45mm`, 176×176, 1-bit MIP, round subscreen 62×62 at x=113,y=0). Venu 4 later.

## Goal
Show the Hebrew date (with sunset rollover) and the weekly parasha on the Instinct, offline-first, with battery use close to a native face.

Native Garmin faces cannot display third-party data (verified), so this is our own Connect IQ watch face plus a separate glance app.

## Deliverables
1. **Watch face** (`face/`). Revised 2026-10-19 after the first simulator screenshot: the ring around the subscreen hides x > 100 on the upper rows, so the original top-left date block (Gregorian / Hebrew day+month / year) did not fit. The dates moved to a full-width band and two short slots moved beside the clock:
   ```
   ב׳ 19.10            ( analog )
   [1] HR              ( clock  )
   [2] battery %
   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  grey (dithered) band, like
   ░░░░░░ ח׳ חשון תשפ״ז ░░░░░░░░░░  the native faces' time band;
   ░░░░░░░ פרשת לך־לך ░░░░░░░░░░░░  outlined text (or holiday)
   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
   [3] steps    [4] altitude m
   [5] sunrise  [6] sunset
   ```
   Revised again 2026-10-19 (digital time). The subscreen became a gauge for slot 3, slot 4 moved into the column, and the time moved under the band as a seven-segment line with seconds:
   ```
   ב׳ 19.10            ( steps  )
   [1] HR  [2] battery ( gauge  )
   [4] altitude m
   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
   ░░░░░░ ח׳ חשון תשפ״ז ░░░░░░░░░░
   ░░░░░░░ פרשת לך־לך ░░░░░░░░░░░░
   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
             6:54:55
   [5] sunrise  [6] sunset
   ```
   - The Gregorian date is in Hebrew: weekday letter (א׳ … ו׳, ש׳) and day.month.
   - The full Hebrew date takes the largest font that fits the band; only some leap-year Adar dates drop the month's geresh (אדר א) when nothing else fits. The parasha steps down a font, then drops "פרשת"; nothing is abbreviated.
   - Time: hours, minutes and seconds in a seven-segment font drawn by `tools/make_assets.py` (21 px, solid strokes, every digit one width). The hour follows the watch's 12/24-hour setting; the line is laid out as `00:00:00`, so a one-digit hour leaves its first digit blank and nothing moves.
   - Slot 3 fills the round subscreen as a gauge: a 270° track with a progress arc for steps (against the daily goal), battery or Body Battery, the value in the middle and the icon in the gap.
   - Slots 1–2 share a line and slot 4 has the line under them. The pair takes SMALL, then XTINY, then XTINY without the icons when it is still too wide; values are never abbreviated. A pair too wide even then (a four-digit or negative altitude beside steps, a time or another wide value, or five-digit steps side by side) starts at the visible edge and its gap closes.
   - Slots 1–6 can each show: heart rate, battery (days left where the watch estimates them, else %), steps, altitude (m), sunrise, sunset, Body Battery, solar intensity, notifications, calories, or nothing.
   - Settings are on the watch (`getSettingsView` → Menu2): slot choices and a light/dark background. They are also declared as properties/settings so phone settings work if the app is later published as a beta.
2. **Glance app** (`glance/`) — a watch-app with `getGlanceView()`. The glance shows the Hebrew date and parasha/holiday. Opening it shows a detail view laid out like the face: both dates, parasha, sunrise (זריחה) and sunset (שקיעה).

## Data
- **Hebrew date**: computed on the watch with the Reingold–Dershowitz arithmetic (Int32-safe), in `common/HebrewCalendar.mc`. After today's sunset it shows the next day's date.
- **Sunrise/sunset**:
  1. The watch's own values (`Complications` SUNRISE/SUNSET), on the face only.
  2. Fallback: local NOAA calculation for the last-known position.
  3. If no position is known: Jerusalem (31.778N, 35.235E).
  `Weather.getSunrise/getSunset` was dropped: it adds nothing over the local calculation and depends on phone-synced data.
  The position comes from `Position.getInfo()` / `Activity.getActivityInfo().currentLocation`, cached in Storage. The face never starts GPS.
- **Parasha / holiday**:
  - A background service runs hourly, and right away when an app starts with an empty cache (at most every 5 minutes). It fetches only when the cache is missing, older than 20 h or covers less than 2 weeks ahead.
  - Request: Hebcal `https://www.hebcal.com/hebcal?v=1&cfg=json&s=on&maj=on&i=on&leyning=off&start=…&end=…` (Israel schedule, about 6 weeks ahead).
  - The service compacts the response to `[rd, hebrewTitle, isParasha]` (rd = fixed day number) and stores it.
  - Display: the coming Shabbat's parasha, counted from the sunset-adjusted date. If that Shabbat has no parasha, show the holiday on that date.
  - If the cache is empty, the line is blank and the Hebrew date sits centred in the band.

## Formatting
Hebrew letters, no niqqud. Gematria uses geresh/gershayim (ט״ו/ט״ז). The year has no thousands digit (תשפ״ז). Leap-year months are אדר א׳ / אדר ב׳. Month spellings follow Hebcal (חשון).

## Battery
- `onUpdate` once a minute. In low power, `onPartialUpdate` redraws only the seconds' two digits each second; if the watch reports the face over its power budget (`WatchFaceDelegate.onPowerBudgetExceeded`), partial updates stop and the time shows hours and minutes while the watch is asleep.
- At most one Hebcal request a day, plus hourly wake-ups that end immediately.
- No GPS start; location reads are throttled to every 15 min.

## Testing
- **Exhaustive check:** a JS mirror of the calendar algorithm is compared with `@hebcal/core` for every day 1900–2100.
- **Monkey C unit tests** (`(:test)`, `monkeydo -t`) against fixture dates generated from Hebcal: leap years, Adar I/II, long/short Cheshvan and Kislev, year boundaries.
- **Also tested:** gematria formatting, parasha lookup and the NOAA sunset calculation (against Hebcal zmanim for Jerusalem).
- **Layout:** every date, title and widest slot value is checked against the visible area measured from the simulator's device mask (ring around the subscreen, cut corners); simulator screenshots for the look. Memory is checked against the limits (face 64 KB, glance/background 32 KB).
- **On the watch (user):** Hebrew glyph order, sunrise/sunset source, settings menu location, battery.

## Out of scope (for now)
Zmanim beyond sunrise/sunset, holidays on non-Shabbat days, phone-app settings. The Venu 4 face has its own design (`2026-10-19-venu-face-design.md`).
