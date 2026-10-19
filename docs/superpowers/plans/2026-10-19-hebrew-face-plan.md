# Hebrew Face — implementation plan

Spec: `docs/superpowers/specs/2026-10-18-hebrew-face-design.md`. Executed inline, without review gates (the user waived them).

1. **Oracle** (`tools/`):
   - `hebcal-oracle.mjs` checks the JS mirror of the algorithm against `@hebcal/core` for every day 1900–2100.
   - The same script generates `common/test/Fixtures.mc`.
2. **Calendar core** (`common/`):
   - `HebrewCalendar.mc`: RD↔Gregorian, RD↔Hebrew, month lengths.
   - `HebrewFormat.mc`: gematria, month names.
   - Unit tests in `common/test/` pass in the simulator.
3. **Sun** (`common/SunTimes.mc`):
   - NOAA sunrise/sunset, unit-tested against Hebcal zmanim.
   - Source chain: complication → Weather → NOAA; location cache with Jerusalem default.
4. **Hebcal sync** (`common/HebcalSync.mc`, `(:background)`):
   - The service delegate fetches and compacts, then stores the cache.
   - `ParashaStore.mc` looks up the coming Shabbat. Parsing and lookup are unit-tested.
5. **Face** (`face/`):
   - App, view (layout A, analog subscreen clock), slot rendering, icons, settings menu, properties/settings.
6. **Glance** (`glance/`): app, glance view, detail view.
7. **Verify**: simulator screenshots of both apps, memory usage, release `.prg` builds.
8. **Ship**: git init, `.gitignore`, commit, push to `raziel-gershoni/garmin`, README with sideload steps.
