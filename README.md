# Hebrew Face for Garmin Instinct 3

Two Connect IQ apps for the Instinct 3 (Tactical) Solar (`instinct3solar45mm`):

- **Hebrew Face** (`face/`): a watch face.
  - Gregorian date, Hebrew date (ז׳ חשון / תשפ״ז) and the analog clock in the round window.
  - The week's parasha, or the holiday when that Shabbat has none.
  - Six swappable data slots: heart rate, battery, steps, altitude, sunrise, sunset, Body Battery, solar, notifications, calories.
- **Hebrew Date** (`glance/`): a glance with the Hebrew date and parasha, for use with any watch face. Opening it shows both dates, the parasha, sunrise and sunset.

How it works:
- **Hebrew date:** calculated on the watch, so it works offline. It changes at sunset, using the watch's own sunset when available. Otherwise it calculates sunset from the last known GPS position, or Jerusalem if there's none.
- **Parasha and holidays:** come from [Hebcal](https://www.hebcal.com) on the Israel schedule. They are fetched at most once a day through the phone and cached about six weeks ahead.

Design: `docs/superpowers/specs/2026-10-18-hebrew-face-design.md`.

## Install on the watch (sideload)

1. Build, or take the `.prg` files from a build: `face/bin/HebrewFace.prg`, `glance/bin/HebrewDate.prg`.
2. On the watch: hold **MENU** › System › USB Mode › **MTP**.
3. Quit Garmin Express if it's running, then connect the watch by USB and open **OpenMTP**.
4. Copy both `.prg` files into `/GARMIN/APPS/` on the watch, then unplug.
5. Select the face: hold **MENU** › Watch Face › **Hebrew Face** › Apply.
6. Add the glance: hold **MENU** › Appearance › Glances › Add › **Hebrew Date**.
7. Settings (slots, dark/light): hold **MENU** › Watch Face, then choose Hebrew Face's settings entry.

The parasha line fills in after the first background sync, about 5 minutes after the face starts with the phone connected. To read logs, create an empty `/GARMIN/APPS/LOGS/HEBREWFACE.TXT` (or `HEBREWDATE.TXT`); crashes go to `/GARMIN/APPS/LOGS/CIQ_LOG.YAML`.

## Build

Requires the Connect IQ SDK 9.2+ (via the SDK Manager), JDK 17 and a developer key.

```sh
cd face   # or glance
monkeyc -d instinct3solar45mm -f monkey.jungle -o bin/HebrewFace.prg -y ~/.connectiq/developer_key.der
```

## Tests

```sh
connectiq &   # start the simulator
cd face
monkeyc -d instinct3solar45mm -f monkey.jungle -o bin/test.prg -y ~/.connectiq/developer_key.der -t
monkeydo bin/test.prg instinct3solar45mm -t
```

The test fixtures come from `@hebcal/core` (`cd tools && npm install`):

- `node hebcal-oracle.mjs` checks a line-by-line JS copy of the calendar code against Hebcal for every day from 1900 to 2100, then writes the date fixtures.
- `node sun-oracle.mjs` writes the sunrise/sunset fixtures.
- `node titles-oracle.mjs` writes the parasha/holiday title fixtures used by the layout tests.
- `python3 tools/make_assets.py` regenerates the icon font and launcher icons.
