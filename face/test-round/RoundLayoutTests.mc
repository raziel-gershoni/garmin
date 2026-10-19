import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Test;

(:test)
module RoundTestSupport {
    // Offscreen dc the size of the Venu screen.
    function screenDc() as Dc {
        var s = System.getDeviceSettings();
        var ref = Graphics.createBufferedBitmap({:width => s.screenWidth, :height => s.screenHeight});
        return (ref.get() as BufferedBitmap).getDc();
    }

    // Every date of a Hebrew year fits the top rim, awake and always-on; only Adar I/II dates may
    // lose the month's geresh.
    function yearFitsTopRim(logger as Logger, year as Number) as Boolean {
        var dc = screenDc();
        var w = dc.getWidth();
        var max = RoundText.rimMaxLength(w);
        var failures = 0;
        var end = HebrewCalendar.newYear(year + 1);
        for (var rd = HebrewCalendar.newYear(year); rd < end; rd++) {
            var h = HebrewCalendar.fromFixed(rd);
            for (var low = 0; low <= 1; low++) {
                var line = RoundText.fitRim(dc, RoundText.dateOptions(h), w, low == 1);
                var logical = RoundText.visual(line[0] as String);
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

(:test)
function rimTextReversesIntoVisualOrder(logger as Logger) as Boolean {
    return RoundText.visual("אבג ד״ה").equals("ה״ד גבא") && RoundText.visual("").equals("");
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
    var dc = RoundTestSupport.screenDc();
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

// A hand's tip points along its clock angle: 12 o'clock is straight up.
(:test)
function handTipFollowsTheAngle(logger as Logger) as Boolean {
    var up = Dial.points(100, 100, 0.0, 50.0, 10.0, 0.0);
    var right = Dial.points(100, 100, (Math.PI / 2).toFloat(), 50.0, 10.0, 0.0);
    return (up[2][1] - 50).abs() < 0.01 && (up[3][1] - 50).abs() < 0.01
        && (right[2][0] - 150).abs() < 0.01 && (right[3][0] - 150).abs() < 0.01;
}

// Rings stay inside the dial, apart from each other, and clear of the rim lines' arcs.
(:test)
function ringsFitBetweenRimLines(logger as Logger) as Boolean {
    var w = System.getDeviceSettings().screenWidth;
    var c = w / 2;
    var r = Rings.radius(w);
    var half = Math.toRadians(RoundText.RIM_DEGREES / 2.0);
    for (var a = 1; a <= 6; a++) {
        var p = Rings.centre(a, w);
        var d = Math.sqrt((p[0] - c) * (p[0] - c) + (p[1] - c) * (p[1] - c));
        if (d + r > c - 9 * w / 390) {
            logger.error("slot " + a + " reaches the ticks");
            return false;
        }
        for (var b = a + 1; b <= 6; b++) {
            var q = Rings.centre(b, w);
            if (Math.sqrt((p[0] - q[0]) * (p[0] - q[0]) + (p[1] - q[1]) * (p[1] - q[1])) < 2 * r + 4) {
                logger.error("slots " + a + " and " + b + " touch");
                return false;
            }
        }
        // Angle of the ring centre from 3 o'clock; distance of its nearest edge to the 12-6 axis.
        var angle = Math.atan2((c - p[1]).toFloat(), (p[0] - c).toFloat());
        var gap = ((angle.abs() - Math.PI / 2).abs() - Math.asin(r.toFloat() / d)) - half;
        if (gap < Math.toRadians(1)) {
            logger.error("slot " + a + " runs into a rim line");
            return false;
        }
    }
    return true;
}

(:test)
function ringHitTest(logger as Logger) as Boolean {
    var w = System.getDeviceSettings().screenWidth;
    for (var s = 1; s <= 6; s++) {
        var p = Rings.centre(s, w);
        if (Rings.hit(p[0], p[1], w) != s) {
            return false;
        }
    }
    return Rings.hit(w / 2, w / 2, w) == 0 && Rings.hit(0, 0, w) == 0;
}

// The widest realistic values fit inside a ring at the value line, awake and always-on.
(:test)
function widestValuesFitInsideRings(logger as Logger) as Boolean {
    var dc = RoundTestSupport.screenDc();
    var w = dc.getWidth();
    var r = Rings.radius(w) - 2;
    var dy = Rings.VALUE_DY * w / 390 + 9 * w / 390;   // lower edge of the digits
    var chord = 2 * Math.sqrt(r * r - dy * dy) - 4;
    var values = ["88888", "23:59", "12:59", "100%", "3999m", "-417m", "--:--", "--"];
    for (var low = 0; low <= 1; low++) {
        for (var i = 0; i < values.size(); i++) {
            var f = Rings.valueFont(dc, values[i], w, low == 1);
            if (dc.getTextWidthInPixels(values[i], f) > chord) {
                logger.error(values[i] + " wider than " + chord);
                return false;
            }
        }
    }
    return true;
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
    return RingData.clamp(1.7) == 1.0 && RingData.clamp(-0.2) == 0.0 && RingData.clamp(0.5) == 0.5
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
    return ok;
}
