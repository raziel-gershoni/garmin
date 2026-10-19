# Hebrew Face — design

Date: 2026-10-18 · Target: Garmin Instinct 3 Tactical Solar (`instinct3solar45mm`, 176×176, 1-bit MIP, round subscreen 62×62 at x=113,y=0). Venu 4 later.

## Goal
Show the Hebrew date (with sunset rollover) and the weekly parasha on the Instinct, offline-first, with battery use close to a native face.

Native Garmin faces cannot display third-party data (verified), so this is our own Connect IQ watch face plus a separate glance app.

## Deliverables
1. **Watch face** (`face/`) — layout A:
   ```
   Mon 19 Oct          ( analog )
   ח׳ חשון             ( clock  )
   תשפ״ז
   ───────────────────────────────
          פרשת לך לך   (or holiday)
   ───────────────────────────────
   [1] HR       [2] battery %
   [3] steps    [4] altitude m
   [5] sunrise  [6] sunset
   ```
   - The analog clock in the subscreen is the only time display (hour + minute hands, no seconds).
   - Slots 1–6 can each show: heart rate, battery %, steps, altitude (m), sunrise, sunset, Body Battery, solar intensity, notifications, calories, or nothing.
   - Settings are on the watch (`getSettingsView` → Menu2): slot choices and a light/dark background. They are also declared as properties/settings so phone settings work if the app is later published as a beta.
2. **Glance app** (`glance/`) — a watch-app with `getGlanceView()`. The glance shows the Hebrew date and parasha/holiday. Opening it shows a detail view with both dates, parasha, sunrise and sunset.

## Data
- **Hebrew date**: computed on the watch with the Reingold–Dershowitz arithmetic (Int32-safe), in `common/HebrewCalendar.mc`. After today's sunset it shows the next day's date.
- **Sunrise/sunset**:
  1. The watch's own values (`Complications` SUNRISE/SUNSET), on the face only.
  2. Fallback: local NOAA calculation for the last-known position.
  3. If no position is known: Jerusalem (31.778N, 35.235E).
  `Weather.getSunrise/getSunset` was dropped: it adds nothing over the local calculation and depends on phone-synced data.
  The position comes from `Position.getInfo()` / `Activity.getActivityInfo().currentLocation`, cached in Storage. The face never starts GPS.
- **Parasha / holiday**:
  - A background service runs hourly. It fetches only when the cache is older than 20 h or covers less than 2 weeks ahead.
  - Request: Hebcal `https://www.hebcal.com/hebcal?v=1&cfg=json&s=on&maj=on&i=on&leyning=off&start=…&end=…` (Israel schedule, about 6 weeks ahead).
  - The service compacts the response to `[yyyymmdd, hebrewTitle, isParasha]` and stores it.
  - Display: the coming Shabbat's parasha, counted from the sunset-adjusted date. If that Shabbat has no parasha, show the holiday on that date.
  - If the cache is empty, the line is blank.

## Formatting
Hebrew letters, no niqqud. Gematria uses geresh/gershayim (ט״ו/ט״ז). The year has no thousands digit (תשפ״ז). Leap-year months are אדר א׳ / אדר ב׳. Month spellings follow Hebcal (חשון).

## Battery
- `onUpdate` once a minute; no `onPartialUpdate`, no seconds.
- At most one Hebcal request a day, plus hourly wake-ups that end immediately.
- No GPS start; location reads are throttled to every 15 min.

## Testing
- **Exhaustive check:** a JS mirror of the calendar algorithm is compared with `@hebcal/core` for every day 1900–2100.
- **Monkey C unit tests** (`(:test)`, `monkeydo -t`) against fixture dates generated from Hebcal: leap years, Adar I/II, long/short Cheshvan and Kislev, year boundaries.
- **Also tested:** gematria formatting, parasha lookup and the NOAA sunset calculation (against Hebcal zmanim for Jerusalem).
- **Simulator:** layout screenshots; memory checked against the limits (face 64 KB, glance/background 32 KB).
- **On the watch (user):** Hebrew glyph order, sunrise/sunset source, settings menu location, battery.

## Out of scope (for now)
Venu 4 build, zmanim beyond sunrise/sunset, holidays on non-Shabbat days, phone-app settings.
