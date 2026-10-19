import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Test;
import Toybox.WatchUi;

(:test)
module RoundTestSupport {
    // Every date of a Hebrew year fits the top rim, awake and always-on; only Adar I/II dates may
    // lose the month's geresh.
    function yearFitsTopRim(logger as Logger, year as Number) as Boolean {
        var dc = FaceTestSupport.screenDc();
        var w = dc.getWidth();
        var max = RoundText.rimMaxLength(w);
        var failures = 0;
        var end = HebrewCalendar.newYear(year + 1);
        for (var rd = HebrewCalendar.newYear(year); rd < end; rd++) {
            var h = HebrewCalendar.fromFixed(rd);
            for (var low = 0; low <= 1; low++) {
                var line = RoundText.fitRim(dc, RoundText.dateOptions(h), w, low == 1);
                var logical = line[0] as String;
                var compacted = !logical.equals(HebrewFormat.full(h));
                if (dc.getTextWidthInPixels(line[0] as String, line[1]) > max || (compacted && h[1] < HebrewCalendar.ADAR)) {
                    logger.error(HebrewFormat.full(h) + " -> " + logical);
                    failures++;
                }
            }
        }
        return failures == 0;
    }
}

// 5787 is a leap year (Adar I/II), 5788 a common year, 5798 a leap year with the widest year letters.
(:test)
function datesOf5787FitTopRim(logger as Logger) as Boolean {
    return RoundTestSupport.yearFitsTopRim(logger, 5787);
}

(:test)
function datesOf5788FitTopRim(logger as Logger) as Boolean {
    return RoundTestSupport.yearFitsTopRim(logger, 5788);
}

(:test)
function datesOf5798FitTopRim(logger as Logger) as Boolean {
    return RoundTestSupport.yearFitsTopRim(logger, 5798);
}

// Every parasha and holiday-Shabbat title (Israel) fits the bottom rim, awake and always-on.
(:test)
function titlesFitBottomRim(logger as Logger) as Boolean {
    var dc = FaceTestSupport.screenDc();
    var w = dc.getWidth();
    var max = RoundText.rimMaxLength(w);
    var titles = TitleFixtures.TITLES.slice(0, null);
    titles.addAll(["פרשת אחרי מות־קדושים", "פרשת תזריע־מצורע", "פרשת בהר־בחוקותי"]);
    var failures = 0;
    for (var i = 0; i < titles.size(); i++) {
        for (var low = 0; low <= 1; low++) {
            var line = RoundText.fitRim(dc, RoundText.titleOptions(titles[i]), w, low == 1);
            if (dc.getTextWidthInPixels(line[0] as String, line[1]) > max) {
                logger.error(titles[i] + " does not fit");
                failures++;
            }
        }
    }
    return failures == 0;
}

// Always-on moves the drawing every minute, never more than 3 px from centre.
(:test)
function burnInShiftMovesEveryMinuteWithinThreePixels(logger as Logger) as Boolean {
    for (var m = 0; m < 60; m++) {
        var o = Dial.burnInOffset(m);
        var n = Dial.burnInOffset((m + 1) % 60);
        if (o[0].abs() > 3 || o[1].abs() > 3 || (o[0] == n[0] && o[1] == n[1])) {
            logger.error("minute " + m + ": " + o + " then " + n);
            return false;
        }
    }
    return true;
}

// A hand is a capsule along its clock angle (12 o'clock is straight up): its far end reaches
// `to` plus half its width, its near end stops `from` minus half its width from the centre.
(:test)
function handCapsuleFollowsTheAngle(logger as Logger) as Boolean {
    var up = Dial.capsulePoints(100, 100, 0.0, 20.0, 50.0, 10.0);
    var right = Dial.capsulePoints(100, 100, (Math.PI / 2).toFloat(), 20.0, 50.0, 10.0);
    var tip = Dial.ARC_STEPS / 2;
    var back = Dial.ARC_STEPS + 1 + Dial.ARC_STEPS / 2;
    return up.size() == 2 * Dial.ARC_STEPS + 2
        && (up[tip][0] - 100).abs() < 0.01 && (up[tip][1] - 45).abs() < 0.01
        && (up[back][1] - 85).abs() < 0.01 && (up[0][0] - 95).abs() < 0.01 && (up[Dial.ARC_STEPS][0] - 105).abs() < 0.01
        && (right[tip][0] - 155).abs() < 0.01 && (right[tip][1] - 100).abs() < 0.01;
}

// The hour hand is short and thick, the minute hand long and thin, and neither reaches the centre.
(:test)
function handsAreDistinct(logger as Logger) as Boolean {
    return Dial.HOUR_HAND[1] < Dial.MINUTE_HAND[1] * 0.7 && Dial.HOUR_HAND[2] > Dial.MINUTE_HAND[2] * 1.3
        && Dial.HOUR_HAND[0] > 0 && Dial.MINUTE_HAND[0] > 0
        && Dial.MINUTE_HAND[2] - 2 * Dial.MINUTE_WALL > 0;
}

// The seconds pointer sits on the rim and points in at the second: 0 at 12, 15 at 3.
(:test)
function secondsPointerPointsAtTheSecond(logger as Logger) as Boolean {
    var top = Dial.secondsPointer(195, 195, 195, 0);
    var right = Dial.secondsPointer(195, 195, 195, 15);
    return (top[2][0] - 195).abs() < 0.01 && (top[2][1] - 15).abs() < 0.01 && (top[0][1] - 1).abs() < 0.01
        && (right[2][0] - 375).abs() < 0.01 && (right[2][1] - 195).abs() < 0.01;
}

// Rings stay inside the dial, apart from each other, and clear of the rim lines' arcs.
// The rings stay inside the ticks and apart from each other (with their stroke); the slot rings
// stay clear of the rim lines' arcs, and the sun ring above 6 stays inside the parasha's line
// (its glyphs reach about 26 px in from the rim line's baseline).
(:test)
function ringsFitBetweenRimLines(logger as Logger) as Boolean {
    var w = System.getDeviceSettings().screenWidth;
    var c = w / 2;
    var pen = Rings.PEN * w / 390;
    var half = Math.toRadians(RoundText.RIM_DEGREES / 2.0);
    for (var a = 1; a <= Rings.PLACES; a++) {
        var p = Rings.centre(a, w);
        var r = Rings.radius(a, w) + pen / 2;
        var d = Math.sqrt((p[0] - c) * (p[0] - c) + (p[1] - c) * (p[1] - c));
        if (d + r > c - 9 * w / 390) {
            logger.error("ring " + a + " reaches the ticks");
            return false;
        }
        for (var b = a + 1; b <= Rings.PLACES; b++) {
            var q = Rings.centre(b, w);
            var gap = Math.sqrt((p[0] - q[0]) * (p[0] - q[0]) + (p[1] - q[1]) * (p[1] - q[1])) - r - Rings.radius(b, w) - pen / 2;
            if (gap < 4) {
                logger.error("rings " + a + " and " + b + " touch");
                return false;
            }
        }
        if (a == Rings.SUN) {
            if (d + r > RoundText.rimRadius(w) - 26 * w / 390) {
                logger.error("the sun ring reaches the parasha");
                return false;
            }
            continue;
        }
        // Angle of the ring centre from 3 o'clock; distance of its nearest edge to the 12-6 axis.
        var angle = Math.atan2((c - p[1]).toFloat(), (p[0] - c).toFloat());
        var gap = ((angle.abs() - Math.PI / 2).abs() - Math.asin(r.toFloat() / d)) - half;
        if (gap < Math.toRadians(1)) {
            logger.error("ring " + a + " runs into a rim line");
            return false;
        }
    }
    return true;
}

(:test)
function ringHitTest(logger as Logger) as Boolean {
    var w = System.getDeviceSettings().screenWidth;
    for (var s = 1; s <= Rings.PLACES; s++) {
        var p = Rings.centre(s, w);
        if (Rings.hit(p[0], p[1], w) != s) {
            return false;
        }
    }
    return Rings.hit(w / 2, w / 2, w) == 0 && Rings.hit(0, 0, w) == 0;
}

// The widest realistic values fit inside every ring, within its stroke at the value line's lower
// edge, awake and always-on.
(:test)
function widestValuesFitInsideRings(logger as Logger) as Boolean {
    var dc = FaceTestSupport.screenDc();
    var w = dc.getWidth();
    var values = ["88888", "23:59", "12:59", "100%", "3999m", "-417m", "--:--", "--"];
    for (var place = 1; place <= Rings.PLACES; place++) {
        var r = Rings.radius(place, w);
        var inner = r - Rings.PEN * w / 390;
        var dy = r * Rings.VALUE_DY + 11 * r / Rings.RADIUS;
        var chord = 2 * Math.sqrt(inner * inner - dy * dy) - 4;
        for (var low = 0; low <= 1; low++) {
            for (var i = 0; i < values.size(); i++) {
                var f = Rings.valueFont(dc, values[i], place, w, low == 1);
                if (dc.getTextWidthInPixels(values[i], f) > chord) {
                    logger.error("ring " + place + ": " + values[i] + " wider than " + chord);
                    return false;
                }
            }
        }
    }
    return true;
}

// The sun ring shows sunset through the day and sunrise through the night, with how far each has
// run, also when sunset falls after midnight; without sun times it shows sunrise and no gauge.
(:test)
function sunRingFlipsAtSunriseAndSunset(logger as Logger) as Boolean {
    var sun = [6 * 3600, 18 * 3600];
    var dawn = RingData.nextSun(sun, 3 * 3600);
    var noon = RingData.nextSun(sun, 12 * 3600);
    var evening = RingData.nextSun(sun, 21 * 3600);
    var late = RingData.nextSun([20 * 3600, 2 * 3600], 23 * 3600);
    var none = RingData.nextSun(null, 0);
    return dawn[0] == Slots.SUNRISE && (dawn[1] - 0.75).abs() < 0.001
        && noon[0] == Slots.SUNSET && (noon[1] - 0.5).abs() < 0.001
        && evening[0] == Slots.SUNRISE && (evening[1] - 0.25).abs() < 0.001
        && late[0] == Slots.SUNSET && (late[1] - 0.5).abs() < 0.001
        && none[0] == Slots.SUNRISE && none[1] == -1.0;
}

// Review focus: a missing reading shows text ("--"), never crashes, for every type.
(:test)
function ringDataGivesTextForEveryType(logger as Logger) as Boolean {
    for (var type = 1; type < Slots.TYPE_COUNT; type++) {
        var v = RingData.value(type, null);
        if (!(v instanceof String) || v.length() == 0) {
            logger.error("type " + type);
            return false;
        }
    }
    return true;
}

// Review focus: the battery icon follows the level and turns red when low.
(:test)
function batteryIconAndColorFollowLevel(logger as Logger) as Boolean {
    return RingData.batteryIcon(100.0) == Rez.Drawables.IconBattery
        && RingData.batteryIcon(70.0) == Rez.Drawables.IconBattery80
        && RingData.batteryIcon(40.0) == Rez.Drawables.IconBattery50
        && RingData.batteryIcon(10.0) == Rez.Drawables.IconBattery20
        && RingData.batteryColor(15.0) == RingData.LOW_COLOR
        && RingData.batteryColor(50.0) == RingData.COLORS[Slots.BATTERY];
}

// Review focus: steps above the goal fill the ring and no more.
(:test)
function progressIsClamped(logger as Logger) as Boolean {
    var p = RingData.progress(Slots.STEPS);
    return Slots.clamp(1.7) == 1.0 && Slots.clamp(-0.2) == 0.0 && Slots.clamp(0.5) == 0.5
        && (p == -1.0 || (p >= 0.0 && p <= 1.0))
        && RingData.progress(Slots.HEART_RATE) == -1.0;
}

// A full gauge is drawn as a circle, because a 360 degree arc is ambiguous.
(:test)
function fullProgressDrawsACircle(logger as Logger) as Boolean {
    return !Rings.isFull(0.0) && !Rings.isFull(0.5) && !Rings.isFull(0.99)
        && Rings.isFull(0.999) && Rings.isFull(1.0);
}

// Holding a ring targets its complication; an empty slot or the centre targets nothing.
(:test)
function holdOnRingTargetsItsComplication(logger as Logger) as Boolean {
    var w = System.getDeviceSettings().screenWidth;
    var before = Slots.typeOf(1);
    var p = Rings.centre(1, w);
    Slots.setType(1, Slots.HEART_RATE);
    var ok = RingPressDelegate.target(p[0], p[1], w) == Complications.COMPLICATION_TYPE_HEART_RATE;
    Slots.setType(1, Slots.NONE);
    ok = ok && RingPressDelegate.target(p[0], p[1], w) == -1;
    ok = ok && RingPressDelegate.target(w / 2, w / 2, w) == -1;
    Slots.setType(1, before);
    var sun = Rings.centre(Rings.SUN, w);
    var t = RingPressDelegate.target(sun[0], sun[1], w);
    return ok && (t == Complications.COMPLICATION_TYPE_SUNRISE || t == Complications.COMPLICATION_TYPE_SUNSET);
}

// The Venu's settings list its four ring slots.
(:test)
function settingsListTheRingSlots(logger as Logger) as Boolean {
    var menu = SettingsMenu.build()[0] as WatchUi.Menu2;
    return FaceSlots.COUNT == 4 && menu.findItemById(4) != -1 && menu.findItemById(5) == -1;
}


// The battery ring shows the same days-left text as the Instinct slot.
(:test)
function batteryRingShowsDays(logger as Logger) as Boolean {
    return RingData.value(Slots.BATTERY, null).equals(Slots.value(Slots.BATTERY, null));
}
