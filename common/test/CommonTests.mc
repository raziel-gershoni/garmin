import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

(:test)
function hebrewDatesMatchHebcal(logger as Logger) as Boolean {
    var failures = 0;
    for (var i = 0; i < Fixtures.DATES.size(); i++) {
        var f = Fixtures.DATES[i] as Array<Number>;
        var rd = HebrewCalendar.fixedFromGregorian(f[0], f[1], f[2]);
        var h = HebrewCalendar.fromFixed(rd);
        if (h[0] != f[3] || h[1] != f[4] || h[2] != f[5] || HebrewCalendar.toFixed(h[0], h[1], h[2]) != rd) {
            logger.error(f.toString() + " -> " + h.toString());
            failures++;
        }
    }
    logger.debug(Fixtures.DATES.size() + " dates checked");
    return failures == 0;
}

(:test)
function hebrewTextMatchesHebcal(logger as Logger) as Boolean {
    var failures = 0;
    for (var i = 0; i < Fixtures.STRINGS.size(); i++) {
        var f = Fixtures.STRINGS[i] as Array;
        var h = HebrewCalendar.fromFixed(HebrewCalendar.fixedFromGregorian(f[0], f[1], f[2]));
        var text = HebrewFormat.full(h);
        if (!text.equals(f[3])) {
            logger.error(f[0] + "-" + f[1] + "-" + f[2] + ": " + text + " != " + f[3]);
            failures++;
        }
    }
    return failures == 0;
}

(:test)
function gematriaSpecialCases(logger as Logger) as Boolean {
    var cases = [[1, "א׳"], [15, "ט״ו"], [16, "ט״ז"], [30, "ל׳"], [780, "תש״פ"], [787, "תשפ״ז"], [715, "תשט״ו"]];
    for (var i = 0; i < cases.size(); i++) {
        var got = HebrewFormat.gematria(cases[i][0] as Number);
        if (!got.equals(cases[i][1])) {
            logger.error(cases[i][0] + ": " + got);
            return false;
        }
    }
    return true;
}

(:test)
function shabbatAndWeekday(logger as Logger) as Boolean {
    var sunday = HebrewCalendar.fixedFromGregorian(2026, 10, 18);
    var shabbat = HebrewCalendar.fixedFromGregorian(2026, 10, 24);
    return HebrewCalendar.dayOfWeek(sunday) == 0
        && HebrewCalendar.shabbatOnOrAfter(sunday) == shabbat
        && HebrewCalendar.shabbatOnOrAfter(shabbat) == shabbat;
}

(:test)
function noaaSunTimesWithinTwoMinutes(logger as Logger) as Boolean {
    var failures = 0;
    for (var i = 0; i < SunFixtures.ROWS.size(); i++) {
        var r = SunFixtures.ROWS[i] as Array;
        var got = SunTimes.noaa(r[0] as Number, r[1] as Double, r[2] as Double, r[3] as Number);
        if (got == null || (got[0] - r[4]).abs() > 120 || (got[1] - r[5]).abs() > 120) {
            logger.error(r.toString() + " -> " + got);
            failures++;
        }
    }
    return failures == 0;
}

(:test)
function parashaLookupPrefersParashaThenHoliday(logger as Logger) as Boolean {
    var sample = {
        "items" => [
            {"date" => "2026-09-11", "category" => "holiday", "hebrew" => "ערב ראש השנה"},
            {"date" => "2026-09-12", "category" => "holiday", "hebrew" => "ראש השנה 5787"},
            {"date" => "2026-10-01", "category" => "holiday", "hebrew" => "סוכות ו׳ (חוה״מ)"},
            {"date" => "2026-10-03", "category" => "holiday", "hebrew" => "שמיני עצרת"},
            {"date" => "2026-10-24", "category" => "parashat", "hebrew" => "פרשת לך־לך"},
            {"date" => "2026-10-24", "category" => "roshchodesh", "hebrew" => "ignored"}
        ]
    };
    var items = Parasha.compact(sample);
    var saved = TestCache.save();
    Application.Storage.setValue(Parasha.ITEMS_KEY, items);
    var ok = items.size() == 5
        && "סוכות ו׳ חוה״מ".equals(items[2][1])
        && "פרשת לך־לך".equals(Parasha.titleFor(HebrewCalendar.fixedFromGregorian(2026, 10, 19)))
        && "שמיני עצרת".equals(Parasha.titleFor(HebrewCalendar.fixedFromGregorian(2026, 9, 27)))
        && "ראש השנה".equals(Parasha.titleFor(HebrewCalendar.fixedFromGregorian(2026, 9, 12)))
        && Parasha.titleFor(HebrewCalendar.fixedFromGregorian(2026, 10, 25)) == null;
    TestCache.restore(saved);
    return ok;
}

(:test)
function weekdayLetters(logger as Logger) as Boolean {
    return HebrewFormat.weekday(1).equals("א׳") && HebrewFormat.weekday(6).equals("ו׳") && HebrewFormat.weekday(7).equals("ש׳");
}

// After sunset the Hebrew date is the next day's; without sun times it never rolls over.
(:test)
function todayRollsOverAtSunset(logger as Logger) as Boolean {
    var sun = [6 * 3600, 17 * 3600];
    return Today.hebrewRd(1000, 12 * 3600, sun) == 1000
        && Today.hebrewRd(1000, 17 * 3600, sun) == 1001
        && Today.hebrewRd(1000, 23 * 3600, null) == 1000;
}
