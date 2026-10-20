import Toybox.Application;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;
import Toybox.Time;

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

// The face can list what the watch publishes into its log without failing, and both simulators
// publish some complications.
(:test)
function complicationListLogs(logger as Logger) as Boolean {
    var count = Slots.logComplications();
    logger.debug("complications logged " + count);
    return count > 0;
}
