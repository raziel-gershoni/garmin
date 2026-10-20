import Toybox.Application.WatchFaceConfig;
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
        && Dial.HOUR_HAND[0] > 0 && Dial.MINUTE_HAND[0] > 0;
}

// The hands are see-through: two capsules (hour, then minute on top), nothing opaque around them
// that would hide the data, more transparent than not, awake and always-on.
(:test)
function handsAreSeeThrough(logger as Logger) as Boolean {
    var parts = Dial.handCapsules(195, 0.0, 1.0, Graphics.createColor(Dial.HANDS_ALPHA, 255, 255, 255));
    return parts.size() == 2 && parts[0][0] == 0.0 && parts[1][0] == 1.0
        && (((parts[0][4] as Number) >> 24) & 0xFF) == Dial.HANDS_ALPHA
        && Dial.HANDS_ALPHA < 0x80 && Dial.HANDS_ALPHA_LOW < 0x80 && Dial.HANDS_ALPHA_LOW > 0;
}

// While awake the tick at the current second is lit orange, 5-second mark or minute tick, and
// no other; always-on there are no seconds. The 5-second marks reach HOUR_MARK_IN, round end
// included.
(:test)
function secondsLightTheirTick(logger as Logger) as Boolean {
    var ok = Dial.tickColor(10, false, 10) == Dial.ACCENT && Dial.tickColor(13, false, 13) == Dial.ACCENT
        && Dial.tickColor(10, false, 11) == Graphics.COLOR_WHITE && Dial.tickColor(13, false, 10) != Dial.ACCENT
        && Dial.tickColor(10, true, 10) != Dial.ACCENT && Dial.tickColor(15, true, 15) != Dial.ACCENT;
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

// Each slot keeps its own place, and only gauges in the bottom row (places 3-4) get a ring: a
// gauge in the top row shows icon and value only, like a plain value.
(:test)
function onlyBottomRowGaugesGetRings(logger as Logger) as Boolean {
    return RingData.ringed(Slots.BATTERY, 3) && RingData.ringed(Slots.STEPS, 4) && RingData.ringed(Slots.BODY_BATTERY, 4)
        && !RingData.ringed(Slots.BATTERY, 1) && !RingData.ringed(Slots.BODY_BATTERY, 2)
        && !RingData.ringed(Slots.HEART_RATE, 3) && !RingData.ringed(Slots.ALTITUDE, 4) && !RingData.ringed(Slots.SUNSET, 3);
}

// The defaults keep the plain values on top and the gauges, with their rings, below.
(:test)
function defaultsPutGaugesInTheBottomRow(logger as Logger) as Boolean {
    var d = FaceSlots.DEFAULTS;
    return d[0] == Slots.HEART_RATE && d[1] == Slots.ALTITUDE && d[2] == Slots.BATTERY && d[3] == Slots.STEPS
        && d[4] == Slots.SUN;
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
    var p = Slots.progress(Slots.STEPS, null);
    return Slots.clamp(1.7) == 1.0 && Slots.clamp(-0.2) == 0.0 && Slots.clamp(0.5) == 0.5
        && (p == -1.0 || (p >= 0.0 && p <= 1.0))
        && Slots.progress(Slots.HEART_RATE, null) == -1.0;
}

// A full gauge is drawn as a circle, because a 360 degree arc is ambiguous.
(:test)
function fullProgressDrawsACircle(logger as Logger) as Boolean {
    return !Rings.isFull(0.0) && !Rings.isFull(0.5) && !Rings.isFull(0.99)
        && Rings.isFull(0.999) && Rings.isFull(1.0);
}

// Holding a spot targets the complication of the widget shown there (slot N at place N), SUN in
// spot 5 the next sunrise or sunset; an empty slot or the centre targets nothing.
(:test)
function holdOnRingTargetsItsComplication(logger as Logger) as Boolean {
    var w = System.getDeviceSettings().screenWidth;
    var saved = TestSlots.save();
    TestSlots.set(1, Slots.BATTERY);
    TestSlots.set(2, Slots.HEART_RATE);
    TestSlots.set(3, Slots.ALTITUDE);
    TestSlots.set(4, Slots.STEPS);
    var top = Rings.centre(1, w);
    var bottom = Rings.centre(3, w);
    var ok = RingPressDelegate.target(top[0], top[1], w) == Complications.COMPLICATION_TYPE_BATTERY
        && RingPressDelegate.target(bottom[0], bottom[1], w) == Complications.COMPLICATION_TYPE_ALTITUDE;
    TestSlots.set(1, Slots.NONE);
    ok = ok && RingPressDelegate.target(top[0], top[1], w) == -1
        && RingPressDelegate.target(w / 2, w / 2, w) == -1;
    TestSlots.set(5, Slots.SUN);
    var day = Today.at(Time.now(), WatchSun.get())[2] as Array<Number>?;
    var sun = Rings.centre(Rings.SUN, w);
    ok = ok && RingPressDelegate.target(sun[0], sun[1], w) == Slots.complicationType(Slots.resolve(Slots.SUN, day));
    TestSlots.set(5, Slots.STEPS);
    ok = ok && RingPressDelegate.target(sun[0], sun[1], w) == Complications.COMPLICATION_TYPE_STEPS;
    TestSlots.restore(saved);
    return ok;
}

// The Venu has no settings menu: its widgets are picked in the watch's own face editor.
(:test)
function venuHasNoSettingsMenu(logger as Logger) as Boolean {
    return FaceViews.settings() == null;
}

// Every type has a Venu ring colour.
(:test)
function everyTypeHasAColour(logger as Logger) as Boolean {
    return RingData.COLORS.size() == Slots.TYPE_COUNT;
}

// The editor's choices fill the five spots; a missing spot, an unknown or missing type, or a spot
// outside 1-5 keeps the default; Sunrise or Sunset in spot 5 is the flipping sun, elsewhere just
// that time.
// Review focus: odd editor settings never crash and never leave a spot unset.
(:test)
function editorChoicesMapToSpots(logger as Logger) as Boolean {
    var d = FaceSlots.DEFAULTS;
    var none = FaceSlots.fromPairs([]);
    var some = FaceSlots.fromPairs([[1, Complications.COMPLICATION_TYPE_STRESS],
                                    [3, Complications.COMPLICATION_TYPE_SLEEP_SCORE]]);
    var sunset5 = FaceSlots.fromPairs([[5, Complications.COMPLICATION_TYPE_SUNSET]]);
    var sunrise5 = FaceSlots.fromPairs([[5, Complications.COMPLICATION_TYPE_SUNRISE]]);
    var steps5 = FaceSlots.fromPairs([[5, Complications.COMPLICATION_TYPE_STEPS]]);
    var sunset2 = FaceSlots.fromPairs([[2, Complications.COMPLICATION_TYPE_SUNSET]]);
    var odd = FaceSlots.fromPairs([[1, Complications.COMPLICATION_TYPE_DATE], [9, Complications.COMPLICATION_TYPE_STEPS],
                                   [null, Complications.COMPLICATION_TYPE_STEPS], [2, null]]);
    return none.toString().equals(d.toString())
        && some[0] == Slots.STRESS && some[2] == Slots.SLEEP_SCORE && some[1] == d[1] && some[4] == d[4]
        && sunset5[4] == Slots.SUN && sunrise5[4] == Slots.SUN && steps5[4] == Slots.STEPS
        && sunset2[1] == Slots.SUNSET && odd.toString().equals(d.toString())
        && d.size() == FaceSlots.COUNT && d[4] == Slots.SUN;
}

// The editor's highlight box holds its subdial with the stroke, inside the screen.
(:test)
function highlightBoxCoversItsSubdial(logger as Logger) as Boolean {
    var w = System.getDeviceSettings().screenWidth;
    for (var place = 1; place <= FaceSlots.COUNT; place++) {
        var p = Rings.centre(place, w);
        var reach = Rings.radius(place, w) + Rings.PEN * w / 390 / 2;
        var b = Rings.box(place, w);
        if (b[0] > p[0] - reach || b[1] > p[1] - reach || b[0] + b[2] < p[0] + reach || b[1] + b[3] < p[1] + reach
                || b[0] < 0 || b[1] < 0 || b[0] + b[2] > w || b[1] + b[3] > w) {
            logger.error("box " + place + " " + b);
            return false;
        }
    }
    return true;
}

// While a spot is being edited the face leaves it out, so only the editor's pulsing copy shows.
(:test)
function editedSpotIsLeftOut(logger as Logger) as Boolean {
    var view = new HebrewFaceView();
    var all = view.places().toString();
    view.editing = 3;
    var three = view.places().toString();
    view.editing = 0;
    return all.equals("[1, 2, 3, 4, 5]") && three.equals("[1, 2, 4, 5]");
}

// Spot 5 counts as the bottom row: gauges and the sun get a ring there, plain values do not.
(:test)
function spotFiveRingsItsGauges(logger as Logger) as Boolean {
    return RingData.ringed(Slots.STEPS, 5) && RingData.ringed(Slots.SUN, 5) && !RingData.ringed(Slots.HEART_RATE, 5);
}

// Every widget the editor offers has a Venu icon (Solar is not offered; SUN shows the sunrise or
// sunset icon).
(:test)
function everyOfferedTypeHasAnIcon(logger as Logger) as Boolean {
    for (var t = 1; t < Slots.TYPE_COUNT; t++) {
        if (t != Slots.SOLAR && t != Slots.SUN && RingData.icon(t) == null) {
            logger.error("no icon for " + t);
            return false;
        }
    }
    return true;
}

// Where the simulator has editor settings, its defaults (resources-round/configs/watchface.xml)
// match FaceSlots.DEFAULTS. The simulator saves the settings on the face's first run and keeps
// them across installs, so a changed default shows here only once its saved config is deleted.
(:test)
function editorDefaultsMatchTheFace(logger as Logger) as Boolean {
    var settings = WatchFaceConfig.getSettings(null);
    if (settings == null || settings.complicationSettings == null) {
        logger.debug("simulator has no editor settings");
        return true;
    }
    var saved = FaceSlots.forced;
    FaceSlots.forced = null;
    FaceSlots.load(null);
    var ok = true;
    for (var spot = 1; spot <= FaceSlots.COUNT; spot++) {
        ok = ok && FaceSlots.typeOf(spot) == FaceSlots.DEFAULTS[spot - 1];
    }
    FaceSlots.forced = saved;
    return ok;
}
