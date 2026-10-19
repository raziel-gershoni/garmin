import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Test;
import Toybox.Time;
import Toybox.Time.Gregorian;
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

// A hand is a line along its clock angle (12 o'clock is straight up) from `from` to `to` px out
// from the centre; the watch's round line ends make it a capsule.
(:test)
function handCapsuleFollowsTheAngle(logger as Logger) as Boolean {
    var up = Dial.capsuleEnds(100, 100, 0.0, 20.0, 50.0);
    var right = Dial.capsuleEnds(100, 100, (Math.PI / 2).toFloat(), 20.0, 50.0);
    return (up[0][0] - 100).abs() < 0.01 && (up[0][1] - 80).abs() < 0.01
        && (up[1][0] - 100).abs() < 0.01 && (up[1][1] - 50).abs() < 0.01
        && (right[0][0] - 120).abs() < 0.01 && (right[1][0] - 150).abs() < 0.01 && (right[1][1] - 100).abs() < 0.01;
}

// The hour hand is short and thick, the minute hand long and thin, and neither reaches the centre.
(:test)
function handsAreDistinct(logger as Logger) as Boolean {
    return Dial.HOUR_HAND[1] < Dial.MINUTE_HAND[1] * 0.7 && Dial.HOUR_HAND[2] > Dial.MINUTE_HAND[2] * 1.3
        && Dial.HOUR_HAND[0] > 0 && Dial.MINUTE_HAND[0] > 0
        && Dial.MINUTE_HAND[2] - 2 * Dial.MINUTE_WALL > 0;
}

// Each hand's outline, fill and (minute) hollow share one centre line and differ only in width,
// so the outline and the hollow's walls are as thick at the round ends as along the sides.
(:test)
function handWallsAreEven(logger as Logger) as Boolean {
    var parts = Dial.handCapsules(195, 0.0, 1.0, Graphics.COLOR_WHITE);
    var ok = parts.size() == 5;
    for (var i = 1; ok && i < parts.size(); i++) {
        var hand = i < 2 ? parts[0] : parts[2];
        ok = parts[i][0] == hand[0] && parts[i][1] == hand[1] && parts[i][2] == hand[2];
    }
    return ok && (parts[0][3] - parts[1][3] - 2 * Dial.OUTLINE).abs() < 0.01
        && (parts[2][3] - parts[3][3] - 2 * Dial.OUTLINE).abs() < 0.01
        && (parts[3][3] - parts[4][3] - 2 * Dial.MINUTE_WALL).abs() < 0.01
        && parts[4][4] == Graphics.COLOR_BLACK;
}

// While awake the tick at the current second is lit orange, 5-second mark or minute tick, and
// no other; always-on there are no seconds. The 5-second marks reach HOUR_MARK_IN, round end
// included.
(:test)
function secondsLightTheirTick(logger as Logger) as Boolean {
    var ok = Dial.tickColor(10, false, 10) == Dial.ACCENT && Dial.tickColor(13, false, 13) == Dial.ACCENT
        && Dial.tickColor(10, false, 11) == Graphics.COLOR_WHITE && Dial.tickColor(13, false, 10) != Dial.ACCENT
        && Dial.tickColor(10, true, null) != Dial.ACCENT;
    for (var low = 0; ok && low <= 1; low++) {
        var pen = Dial.tickPen(0, low == 1);
        var e = Dial.tickEnds(195, 195, 195, 0, low == 1);
        ok = (e[0][1] + pen / 2.0 - Dial.HOUR_MARK_IN).abs() < 0.01;
    }
    return ok;
}

// The rings stay inside the 5-second marks (their round inner end) and apart from each other
// (with their stroke); the slot rings stay clear of the rim lines' arcs, and the sun
// ring above 6 stays inside the parasha's line (its glyphs reach about 26 px in from the rim
// line's baseline).
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
        if (d + r > c - Dial.HOUR_MARK_IN * w / 390 - 1) {
            logger.error("ring " + a + " reaches the 5-second marks");
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

// The widest realistic values fit inside every place at the value line's lower edge, within the
// ring's stroke where there is one, awake and always-on.
(:test)
function widestValuesFitInsideRings(logger as Logger) as Boolean {
    var dc = FaceTestSupport.screenDc();
    var w = dc.getWidth();
    var values = ["88888", "23:59", "12:59", "100%", "3999m", "-417m", "--:--", "--"];
    for (var place = 1; place <= Rings.PLACES; place++) {
        var r = Rings.radius(place, w);
        var dy = r * Rings.VALUE_DY + 11 * r / Rings.RADIUS;
        for (var ringed = 0; ringed <= 1; ringed++) {
            var inner = ringed == 1 ? r - Rings.PEN * w / 390 : r;
            var chord = 2 * Math.sqrt(inner * inner - dy * dy) - 4;
            for (var low = 0; low <= 1; low++) {
                for (var i = 0; i < values.size(); i++) {
                    var f = Rings.valueFont(dc, values[i], place, w, low == 1, ringed == 1);
                    if (dc.getTextWidthInPixels(values[i], f) > chord) {
                        logger.error("place " + place + ": " + values[i] + " wider than " + chord);
                        return false;
                    }
                }
            }
        }
    }
    return true;
}

// The sun ring shows sunset through the day and sunrise through the night, flipping exactly at
// each, with how far each has run, also when sunset falls after midnight; without sun times it
// shows sunrise with an empty arc.
(:test)
function sunRingFlipsAtSunriseAndSunset(logger as Logger) as Boolean {
    var sun = [6 * 3600, 18 * 3600];
    var dawn = RingData.nextSun(sun, 3 * 3600);
    var rise = RingData.nextSun(sun, 6 * 3600);
    var noon = RingData.nextSun(sun, 12 * 3600);
    var set = RingData.nextSun(sun, 18 * 3600);
    var late = RingData.nextSun([20 * 3600, 2 * 3600], 23 * 3600);
    var none = RingData.nextSun(null, 0);
    return dawn[0] == Slots.SUNRISE && (dawn[1] - 0.75).abs() < 0.001
        && rise[0] == Slots.SUNSET && rise[1] == 0.0
        && noon[0] == Slots.SUNSET && (noon[1] - 0.5).abs() < 0.001
        && set[0] == Slots.SUNRISE && set[1] == 0.0
        && late[0] == Slots.SUNSET && (late[1] - 0.5).abs() < 0.001
        && none[0] == Slots.SUNRISE && none[1] == 0.0;
}

// Only gauges get a ring, and they go to the bottom row: plain values fill the top places first,
// each group in slot order.
(:test)
function gaugesGoBelowPlainValues(logger as Logger) as Boolean {
    var order = RingData.arrange([Slots.HEART_RATE, Slots.BATTERY, Slots.STEPS, Slots.ALTITUDE]);
    var gauges = RingData.arrange([Slots.BATTERY, Slots.STEPS, Slots.BODY_BATTERY, Slots.NONE]);
    return RingData.isGauge(Slots.BATTERY) && RingData.isGauge(Slots.STEPS) && RingData.isGauge(Slots.BODY_BATTERY)
        && !RingData.isGauge(Slots.HEART_RATE) && !RingData.isGauge(Slots.ALTITUDE) && !RingData.isGauge(Slots.SUNSET)
        && order.toString().equals("[1, 4, 2, 3]") && gauges.toString().equals("[4, 1, 2, 3]");
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

// Holding a place targets the complication of the slot shown there (gauges are moved to the
// bottom row), and holding the sun ring the next sunrise or sunset; an empty slot or the centre
// targets nothing.
(:test)
function holdOnRingTargetsItsComplication(logger as Logger) as Boolean {
    var w = System.getDeviceSettings().screenWidth;
    var saved = [Slots.typeOf(1), Slots.typeOf(2), Slots.typeOf(3), Slots.typeOf(4), Slots.typeOf(5)];
    Slots.setType(1, Slots.BATTERY);
    Slots.setType(2, Slots.HEART_RATE);
    Slots.setType(3, Slots.ALTITUDE);
    Slots.setType(4, Slots.STEPS);
    Slots.setType(5, Slots.HEART_RATE);
    var top = Rings.centre(1, w);
    var bottom = Rings.centre(3, w);
    var ok = RingPressDelegate.target(top[0], top[1], w) == Complications.COMPLICATION_TYPE_HEART_RATE
        && RingPressDelegate.target(bottom[0], bottom[1], w) == Complications.COMPLICATION_TYPE_BATTERY;
    Slots.setType(2, Slots.NONE);
    ok = ok && RingPressDelegate.target(top[0], top[1], w) == -1
        && RingPressDelegate.target(w / 2, w / 2, w) == -1;
    var day = Today.at(Time.now(), WatchSun.get());
    var t = day[0] as Gregorian.Info;
    var now = (t.hour as Number) * 3600 + (t.min as Number) * 60 + (t.sec as Number);
    var sun = Rings.centre(Rings.SUN, w);
    ok = ok && RingPressDelegate.target(sun[0], sun[1], w)
        == RingData.complicationType(RingData.nextSun(day[2] as Array<Number>?, now)[0] as Number);
    for (var i = 0; i < saved.size(); i++) {
        Slots.setType(i + 1, saved[i]);
    }
    return ok;
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
