# Hebrew Face for Garmin Instinct 3 and Venu 4

Two Connect IQ apps for the Instinct 3 (Tactical) Solar (`instinct3solar45mm`) and the Venu 4 41 mm (`venu441mm`). Unless a section says Venu, the text below describes the Instinct:

- **Hebrew Face** (`face/`): a watch face.
  ```
   ב׳ 19.10          (steps gauge) ← slot 3 in the round window
   ♥ 80  ▭ 5d        ← slots 1–2
   ▲ -17m            ← slot 4
   ░░░░░░░░░░░░░░░░░
   ░░░░ 8:05:24 ░░░░ ← grey band with the seven-segment time and seconds
   ░░░░░░░░░░░░░░░░░
     ח׳ חשון תשפ״ז    ← full Hebrew date
      פרשת לך־לך      ← or the holiday when that Shabbat has none
   ☀ 06:44  ☀ 18:03  ← slots 5–6
  ```
  - Gregorian date in Hebrew (weekday letter, day.month) beside the round window, which shows slot 3 as a gauge (steps against the daily goal, battery or Body Battery).
  - The time sits on a grey band, like the native faces' time band. It follows the watch's 12/24-hour setting and never shifts sideways; the seconds keep ticking in low power unless the watch finds that over its power budget.
  - Full Hebrew date and the week's parasha under the band; long dates and titles step down a font size, and nothing is abbreviated.
  - Six swappable data slots: heart rate, battery, steps, altitude, sunrise, sunset, Body Battery, solar, notifications, calories.
  - **Venu 4 (41 mm):** an analog dial with a different look, built from the same project.
    - The full Hebrew date curves along the top rim and the parasha or holiday along the bottom rim; the Gregorian date ("ב׳ 19.10") sits under 12.
    - Six ring subdials with Material Design icons hold the same six slots (no Solar slot, no light theme).
    - White hands with a black outline, plus an orange seconds hand while the watch is awake.
    - The always-on view is dim, with filled grey hands, and shifts a few pixels each minute against burn-in.
    - Touch-and-hold on a ring opens the matching native Garmin view (heart rate, steps, battery, sunrise/sunset and so on); checked on the watch.
- **Hebrew Date** (`glance/`): a glance with the Hebrew date and parasha, for use with any watch face. Opening it shows both dates, the parasha, sunrise and sunset, laid out like the face. On the Venu the detail view is round, with the dates on the rim, the Gregorian date under 12 and "זריחה"/"שקיעה" times in the middle.

How it works:
- **Hebrew date:** calculated on the watch, so it works offline. It changes at sunset, using the watch's own sunset when available. Otherwise it calculates sunset from the last known GPS position, or Jerusalem if there's none.
- **Parasha and holidays:** come from [Hebcal](https://www.hebcal.com) on the Israel schedule. They are fetched at most once a day through the phone and cached about six weeks ahead.

Design: `docs/superpowers/specs/2026-10-18-hebrew-face-design.md`.

## Install on the watch (sideload)

1. Build, or take the `.prg` files from a build: `face/bin/HebrewFace.prg`, `glance/bin/HebrewDate.prg` (Venu: `HebrewFace-venu.prg`, `HebrewDate-venu.prg`).
2. Instinct: on the watch, hold **MENU** › System › USB Mode › **MTP**.
3. Quit Garmin Express if it's running, then connect the watch by USB and open **OpenMTP**.
4. Copy both `.prg` files into `/GARMIN/APPS/` on the watch, then unplug.
5. Instinct: select the face with hold **MENU** › Watch Face › **Hebrew Face** › Apply.
6. Instinct: add the glance with hold **MENU** › Appearance › Glances › Add › **Hebrew Date**.
7. Instinct: settings (slots, dark/light): hold **MENU** › Watch Face, then choose Hebrew Face's settings entry.

Venu 4: copy `HebrewFace-venu.prg` and `HebrewDate-venu.prg` the same way (steps 3-4), then choose the face from the watch-face list on the watch. The exact on-watch menu paths (face, glance, settings) still need confirming on the Venu. Its settings offer the six slots only; dark/light is Instinct-only.

The parasha line fills in after the first background sync, which runs right after the face first starts with the phone connected (retries are hourly). To read logs, create an empty `/GARMIN/APPS/LOGS/HEBREWFACE.TXT` (or `HEBREWDATE.TXT`); crashes go to `/GARMIN/APPS/LOGS/CIQ_LOG.YAML`.

## Build

Requires the Connect IQ SDK 9.2+ (via the SDK Manager), JDK 17 and a developer key.

```sh
cd face   # or glance
# Instinct
monkeyc -d instinct3solar45mm -f monkey.jungle -o bin/HebrewFace.prg -y ~/.connectiq/developer_key.der -r
# Venu 4 (41 mm)
monkeyc -d venu441mm -f monkey.jungle -o bin/HebrewFace-venu.prg -y ~/.connectiq/developer_key.der -r
```

In `glance/` the outputs are `bin/HebrewDate.prg` and `bin/HebrewDate-venu.prg`. `-r` makes the small release build.

## Tests

```sh
connectiq &   # start the simulator
cd face       # or glance
DEVICE=instinct3solar45mm   # or venu441mm
monkeyc -d $DEVICE -f monkey.jungle -o bin/test-$DEVICE.prg -y ~/.connectiq/developer_key.der -t
monkeydo bin/test-$DEVICE.prg $DEVICE -t
```

Run the suite on both devices (`instinct3solar45mm` and `venu441mm`), for `face/` and `glance/`.

The test fixtures come from `@hebcal/core` (`cd tools && npm install`):

- `node hebcal-oracle.mjs` checks a line-by-line JS copy of the calendar code against Hebcal for every day from 1900 to 2100, then writes the date fixtures.
- `node sun-oracle.mjs` writes the sunrise/sunset fixtures.
- `node titles-oracle.mjs` writes the parasha/holiday title fixtures used by the layout tests.
- `python3 tools/make_assets.py` regenerates the icon font, the seven-segment time font, launcher icons and the band's dither bitmap.
- `node build-icons.mjs` (in `tools/`) regenerates the Venu icons from Material Design Icons (licence in `tools/LICENSE-mdi.txt`).
