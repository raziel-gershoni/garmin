import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;
import Toybox.WatchUi;

(:test)
module LayoutTestSupport {
    function offscreenDc() as Dc {
        var ref = Graphics.createBufferedBitmap({:width => 176, :height => 176});
        return (ref.get() as BufferedBitmap).getDc();
    }

    // 1 (and the reason logged) when a column line does not end at DateBand.RIGHT clear of the
    // ring and the cut corner, or is not in SMALL when small is set; 0 otherwise.
    function columnLineFails(dc as Dc, logger as Logger, y as Number, left as String, right as String?,
                             small as Boolean) as Number {
        var places = Layout.line(dc, y, left, right);
        var font = (places[0] as Array)[2];
        var width = Layout.lineWidth(dc, left, right, font, (places[0] as Array)[3] != null);
        if ((small && font != Graphics.FONT_SMALL) || !ScreenMask.fitsColumn(y, width, true)
                || (places[0] as Array)[0] + width != DateBand.RIGHT) {
            logger.error("line y=" + y + " " + left + "/" + right + " w=" + width + " font=" + font);
            return 1;
        }
        return 0;
    }
}

// Visible screen, measured from the simulator's device mask independently of DateBand's own
// table: last visible x left of the ring for rows 0..74 (the ring ends there), first visible x in
// the cut top-left corner for rows 0..40, and first visible x for rows 136..174, where the bottom
// corners narrow the screen symmetrically (rows 75..135 are visible from 1 to 174).
(:test)
module ScreenMask {
    const RING = [-1, 113, 112, 111, 110, 109, 108, 108, 107, 106, 106, 105, 105, 104, 104, 103, 103, 103,
                  102, 102, 102, 101, 101, 101, 101, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100,
                  100, 100, 100, 101, 101, 101, 101, 102, 102, 102, 103, 103, 103, 104, 104, 105, 105, 106,
                  106, 107, 108, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 119, 120, 122, 124, 126,
                  128, 132, 136];
    const CUT = [-1, 40, 39, 38, 36, 34, 33, 31, 30, 29, 27, 26, 25, 24, 22, 21, 20, 19, 18, 17, 16, 15,
                 14, 14, 13, 12, 11, 10, 10, 9, 8, 7, 7, 6, 5, 5, 4, 3, 3, 2, 1];
    const BOTTOM = [2, 3, 3, 4, 5, 5, 6, 7, 7, 8, 9, 10, 10, 11, 12, 13, 14, 14, 15, 16, 17, 18, 19, 20,
                    21, 22, 24, 25, 26, 27, 29, 30, 31, 33, 34, 36, 38, 39, 40];

    function firstX(row as Number) as Number {
        return row < 136 ? 1 : BOTTOM[row - 136];
    }

    function lastX(row as Number) as Number {
        return 175 - firstX(row);
    }

    // A line right-aligned in the column, of the given width and drawn at y, stays visible:
    // clear of the ring on every row its glyphs can cover and right of the corner at its top row.
    function fitsColumn(y as Number, width as Number, high as Boolean) as Boolean {
        for (var row = y + 6; row <= y + 21 && row < RING.size(); row++) {
            if (DateBand.RIGHT >= RING[row]) {
                return false;
            }
        }
        var top = y + (high ? 6 : 10);
        return DateBand.RIGHT - width > (top < CUT.size() ? CUT[top] : 1);
    }
}

// Every day of two leap years (5787, and 5798 with the widest year letters) and a common year
// fits the glance's band (DateBand) and the face's line under its band (Layout); only Adar I/II
// dates may lose the month's geresh.
(:test)
function hebrewDatesFit(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var failures = 0;
    var counts = {};
    var years = [5787, 5788, 5798];
    for (var y = 0; y < years.size(); y++) {
        var start = HebrewCalendar.newYear(years[y]);
        var end = HebrewCalendar.newYear(years[y] + 1);
        for (var rd = start; rd < end; rd++) {
            var h = HebrewCalendar.fromFixed(rd);
            var lines = [DateBand.hebrewDate(dc, h), Layout.hebrewDate(dc, h)];
            var limits = [DateBand.BAND_MAX_W, Layout.HEBREW_MAX_W];
            for (var i = 0; i < 2; i++) {
                var line = lines[i] as Array;
                var width = dc.getTextWidthInPixels(line[0], line[1]);
                var compacted = !line[0].equals(HebrewFormat.full(h));
                if (width > limits[i] || (compacted && h[1] < HebrewCalendar.ADAR)) {
                    logger.error((i == 0 ? "band " : "face ") + HebrewFormat.full(h) + " -> " + line[0] + " w=" + width);
                    failures++;
                }
                var key = (i == 0 ? "band " : "face ") + line[1].toString() + (compacted ? "c" : "");
                counts[key] = counts.hasKey(key) ? counts[key] + 1 : 1;
            }
        }
    }
    logger.debug("Hebrew date fonts (c = without geresh): " + counts);
    return failures == 0;
}

// The widest weekday letter with the widest day.month fits the column, moving down at most 3 rows.
(:test)
function gregorianLineFitsColumn(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var font = Graphics.FONT_XTINY;
    var weekday = 0;
    for (var d = 1; d <= 7; d++) {
        var w = dc.getTextWidthInPixels(HebrewFormat.weekday(d), font);
        weekday = w > weekday ? w : weekday;
    }
    var date = 0;
    for (var m = 1; m <= 12; m++) {
        for (var d = 1; d <= 31; d++) {
            var w = dc.getTextWidthInPixels(d + "." + m, font);
            date = w > date ? w : date;
        }
    }
    var width = weekday + DateBand.WORD_GAP + date;
    var y = DateBand.gregorianY(width);
    logger.debug("widest gregorian w=" + width + " y=" + y);
    return y - DateBand.GREGORIAN_Y <= 3 && ScreenMask.fitsColumn(y, width, true);
}

// Slots 1-2 share their line in SMALL with a two-digit heart rate beside battery days (the
// Instinct reports battery in days), and still fit with their icons, in XTINY if need be, with a
// three-digit heart rate beside 99 days or a Body Battery of 100. Any single value fits a column
// line in SMALL.
(:test)
function columnLinesFit(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var small = [["99", "24d"], ["80", "5d"], ["--", "--"]];
    var fitting = [["199", "99d"], ["199", "100"], ["199", "24d"]];
    var singles = ["88888", "23:59", "12:59", "100%", "8848m", "-430m", "--:--", "9999"];
    var failures = 0;
    for (var i = 0; i < small.size(); i++) {
        failures += LayoutTestSupport.columnLineFails(dc, logger, Layout.PAIR_Y, small[i][0], small[i][1], true);
    }
    for (var i = 0; i < fitting.size(); i++) {
        failures += LayoutTestSupport.columnLineFails(dc, logger, Layout.PAIR_Y, fitting[i][0], fitting[i][1], false);
    }
    for (var i = 0; i < singles.size(); i++) {
        failures += LayoutTestSupport.columnLineFails(dc, logger, Layout.PAIR_Y, singles[i], null, true);
        failures += LayoutTestSupport.columnLineFails(dc, logger, Layout.SLOT4_Y, singles[i], null, true);
    }
    return failures == 0;
}

// Any two of the widest values of each slot type share the line of slots 1-2: never past the
// visible edge, and a full gap apart unless their bare text and the gap are wider than the line
// (a four-digit or negative altitude beside steps, a time or another wide value, and five-digit
// steps side by side: their gap closes).
(:test)
function anyPairStaysOnScreen(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var values = ["199", "24d", "100%", "88888", "8848m", "-430m", "23:59", "--:--", "100", "99", "9999", "--"];
    var failures = 0;
    var bare = 0;
    var closed = [];
    for (var i = 0; i < values.size(); i++) {
        for (var j = 0; j < values.size(); j++) {
            var places = Layout.line(dc, Layout.PAIR_Y, values[i], values[j]);
            var l = places[0] as Array;
            var r = places[1] as Array;
            var icons = l[3] != null;
            var f = l[2] == Graphics.FONT_SMALL ? 0 : 1;
            var max = DateBand.maxWidth(Layout.PAIR_Y + f, true);
            var lw = Layout.valueWidth(dc, values[i], l[2], icons);
            var rw = Layout.valueWidth(dc, values[j], r[2], icons);
            var text = dc.getTextWidthInPixels(values[i], l[2]) + dc.getTextWidthInPixels(values[j], r[2]);
            var gapped = l[0] + lw + Layout.PAIR_GAP == r[0];
            if (!gapped) {
                closed.add(values[i] + "/" + values[j]);
            }
            if (!ScreenMask.fitsColumn(Layout.PAIR_Y + f, DateBand.RIGHT - l[0], true)
                    || r[0] + rw != DateBand.RIGHT || (!gapped && text + Layout.PAIR_GAP <= max)) {
                logger.error(values[i] + "/" + values[j] + " x=" + l[0] + "," + r[0] + " w=" + lw + "," + rw);
                failures++;
            }
            bare += icons ? 0 : 1;
        }
    }
    logger.debug("pairs without icons: " + bare + " of " + values.size() * values.size() + "; gap closed: " + closed);
    return failures == 0;
}

// The glance's band (DateBand) stacks its two lines inside it (ink offsets measured in the
// simulator: tall glyphs start 6 rows below y, 7 for MEDIUM Hebrew; descenders end 27 below; band
// text has a 1px outline). Its fonts are [MEDIUM, SMALL, XTINY].
(:test)
function glanceBandStacks(logger as Logger) as Boolean {
    var h = DateBand.HEBREW_Y;
    var p = DateBand.PARASHA_Y;
    var top = DateBand.BAND_TOP;
    var bottom = DateBand.BAND_TOP + DateBand.BAND_HEIGHT - 1;
    return top >= ScreenMask.RING.size()
        && h[0] + 7 - 1 > top && h[1] + 6 - 1 > top && h[2] + 6 - 1 > top
        // the date's descenders end above the parasha's tall glyphs
        && h[1] + 27 < p[0] + 7 - 1 && h[1] + 27 < p[1] + 6 - 1 && h[1] + 27 < p[2] + 6 - 1
        // the parasha's outlined descenders end inside the band; the date alone stays inside too
        && p[0] + 27 + 1 < bottom && p[1] + 27 + 1 < bottom && p[2] + 27 + 1 < bottom
        && h[0] + DateBand.ALONE_SHIFT + 27 + 1 < bottom;
}

// The face, top to bottom, stacks without touching (ink measured in the simulator: digits and
// icons from 6 rows below y, the icon and time fonts' ink one row lower than their y; SMALL Hebrew
// from 7 to 24 rows below y, XTINY from 6 to 23; outlined text gains a row on each side): the
// column lines, the band below the ring with a grey row above and below the outlined time, then
// three clear rows under the band, two between the Hebrew lines (descenders above top marks) and
// three above the bottom row's SMALL digits (four above its icons).
(:test)
function faceStacks(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var height = dc.getFontHeight(WatchUi.loadResource(Rez.Fonts.Time) as FontResource);
    var h = Layout.HEBREW_Y;
    var p = Layout.PARASHA_Y;
    var bandBottom = DateBand.BAND_TOP + Layout.BAND_HEIGHT - 1;
    var timeTop = Layout.TIME_Y + Layout.TIME_INK_DY;
    var icons = Layout.BOTTOM_Y + Layout.ICON_DY + 1;
    return DateBand.GREGORIAN_Y + 3 + 21 < Layout.PAIR_Y + 6
        && Layout.PAIR_Y + 21 < Layout.SLOT4_Y + 6
        && Layout.SLOT4_Y + 21 < DateBand.BAND_TOP - 2
        && DateBand.BAND_TOP >= ScreenMask.RING.size()
        && timeTop - 2 >= DateBand.BAND_TOP && timeTop + height + 1 <= bandBottom
        && h[1] + 7 == h[2] + 6 && p[1] + 7 == p[2] + 6
        && h[1] + 7 - bandBottom - 1 >= 3
        && p[1] + 7 - (h[1] + 24) - 1 >= 2
        && icons - (p[1] + 24) - 1 >= 4 && Layout.BOTTOM_Y + 6 - (p[1] + 24) - 1 >= 3
        // without a parasha the date sits lower, still clear of the bottom row
        && h[1] + Layout.ALONE_SHIFT + 24 < icons - 3;
}

// Every parasha (Israel) and every holiday that replaces one on Shabbat fits the glance's band and
// the face's parasha line, including Hebcal API spellings that differ from @hebcal/core's; the
// face's limit fits the screen on every row the line's ink reaches, where the corners narrow it.
(:test)
function parashaTitlesFit(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var titles = TitleFixtures.TITLES.slice(0, null);
    titles.addAll(["פרשת אחרי מות־קדושים", "פרשת תזריע־מצורע", "פרשת בהר־בחוקותי"]);
    var failures = 0;
    for (var i = 0; i < titles.size(); i++) {
        var band = DateBand.parasha(dc, titles[i]);
        var face = Layout.parasha(dc, titles[i]);
        var bandW = dc.getTextWidthInPixels(band[0], band[1]);
        var faceW = dc.getTextWidthInPixels(face[0], face[1]);
        if (bandW > DateBand.BAND_MAX_W || faceW > Layout.PARASHA_MAX_W) {
            logger.error(titles[i] + " does not fit: band " + band[0] + " w=" + bandW + ", face " + face[0] + " w=" + faceW
                + " (SMALL " + dc.getTextWidthInPixels(face[0], Graphics.FONT_SMALL) + ")");
            failures++;
        }
    }
    var lines = [[Layout.HEBREW_Y[1], Layout.HEBREW_MAX_W], [Layout.HEBREW_Y[1] + Layout.ALONE_SHIFT, Layout.HEBREW_MAX_W],
                 [Layout.PARASHA_Y[1], Layout.PARASHA_MAX_W]];
    for (var i = 0; i < lines.size(); i++) {
        var w = lines[i][1];
        for (var row = lines[i][0] + 7; row <= lines[i][0] + 24; row++) {
            if (Layout.CENTER_X - w / 2 < ScreenMask.firstX(row) || Layout.CENTER_X + w / 2 - 1 > ScreenMask.lastX(row)) {
                logger.error("line " + i + " off screen at row " + row);
                failures++;
            }
        }
    }
    return failures == 0;
}

// The time is centred as its template and every time with a two-digit hour is exactly as wide,
// so nothing moves (a one-digit hour is one digit narrower and leaves that digit blank).
(:test)
function timeKeepsItsPlace(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var font = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
    var width = dc.getTextWidthInPixels(Layout.TIME_TEMPLATE, font);
    var times = ["00:00:00", "23:59:59", "12:59:59", "11:11:11", "08:08:08"];
    for (var i = 0; i < times.size(); i++) {
        if (dc.getTextWidthInPixels(times[i], font) != width) {
            logger.error(times[i] + " is not as wide as the template");
            return false;
        }
    }
    var right = Layout.timeRight(dc, font);
    return dc.getTextWidthInPixels("1:00:00", font) == width - dc.getTextWidthInPixels("0", font)
        && right - width - 1 >= 1 && right + 1 <= 174;
}

// The low-power redraw covers the seconds' two digits and their outline, from one column before
// them to the line's end and from a row above the ink to a row below it (with or without the ink
// offset), clear of the colon's outline and inside the band.
(:test)
function secondsBoxCoversSecondsOnly(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var font = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
    var right = Layout.timeRight(dc, font);
    var left = right - dc.getTextWidthInPixels(Layout.TIME_TEMPLATE, font);
    var box = Layout.secondsBox(dc, font);
    var height = dc.getFontHeight(font);
    logger.debug("seconds box " + box);
    return box[0] == left + dc.getTextWidthInPixels("00:00:", font) - 1 && box[0] + box[2] == right
        && box[1] == Layout.TIME_Y - 1 && box[1] + box[3] == Layout.TIME_Y + Layout.TIME_INK_DY + height + 1
        && box[1] >= DateBand.BAND_TOP && box[1] + box[3] <= DateBand.BAND_TOP + Layout.BAND_HEIGHT;
}

// Slots 5-6: the row's visible range fits the screen on every row its icons and digits cover, and
// any two of the widest values (or one beside an empty slot) stay inside it, in one font and icon
// setting for both, a full gap apart unless their bare text and the gap are wider than the row.
// Narrow values keep SMALL and their icons; 24-hour times drop to XTINY, still with icons.
(:test)
function bottomRowFits(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    for (var row = Layout.BOTTOM_Y + Layout.ICON_DY; row <= Layout.BOTTOM_Y + 1 + 18; row++) {
        if (Layout.BOTTOM_MIN_X < ScreenMask.firstX(row) || Layout.BOTTOM_MAX_X - 1 > ScreenMask.lastX(row)) {
            logger.error("bottom range off screen at row " + row);
            return false;
        }
    }
    var values = [null, "88888", "23:59", "12:59", "06:44", "100%", "8848m", "-430m", "--:--", "--", "199"];
    var failures = 0;
    var bare = 0;
    for (var i = 0; i < values.size(); i++) {
        for (var j = 0; j < values.size(); j++) {
            var places = Layout.bottomRow(dc, values[i], values[j]);
            var l = places[0] as Array?;
            var r = places[1] as Array?;
            var lw = l == null ? 0 : Layout.valueWidth(dc, values[i] as String, l[2], l[3] != null);
            var rw = r == null ? 0 : Layout.valueWidth(dc, values[j] as String, r[2], r[3] != null);
            var ok = (l == null || l[0] >= Layout.BOTTOM_MIN_X) && (r == null || r[0] + rw <= Layout.BOTTOM_MAX_X);
            if (l != null && r != null) {
                var text = dc.getTextWidthInPixels(values[i] as String, l[2]) + dc.getTextWidthInPixels(values[j] as String, r[2]);
                var room = Layout.BOTTOM_MAX_X - Layout.BOTTOM_MIN_X;
                ok = ok && (l[0] + lw + Layout.BOTTOM_GAP <= r[0] || text + Layout.BOTTOM_GAP > room)
                    && l[2] == r[2] && (l[3] == null) == (r[3] == null);
                bare += l[3] == null ? 1 : 0;
            }
            if (!ok) {
                logger.error(values[i] + "/" + values[j] + " l=" + l + " r=" + r);
                failures++;
            }
        }
    }
    logger.debug("bottom pairs without icons: " + bare);
    var narrow = Layout.bottomRow(dc, "80", "5d");
    var lone = Layout.bottomRow(dc, null, "5d");
    var times = Layout.bottomRow(dc, "06:44", "18:03");
    return failures == 0
        && (narrow[0] as Array)[2] == Graphics.FONT_SMALL && (narrow[0] as Array)[3] != null
        && (lone[1] as Array)[2] == Graphics.FONT_SMALL && (lone[1] as Array)[3] != null
        && (times[0] as Array)[2] == Graphics.FONT_XTINY && (times[0] as Array)[3] != null;
}

// The widest gauge values fit the window's smallest font, and that width fits inside the arc's
// inner edge on the rows the digits cover (XTINY digits reach 6 rows either side of the centre).
(:test)
function windowValuesFit(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var fonts = Window.VALUE_FONTS;
    var values = ["88888", "12345", "100%", "100", "--"];
    for (var i = 0; i < values.size(); i++) {
        if (dc.getTextWidthInPixels(values[i], fonts[fonts.size() - 1]) > Window.VALUE_MAX_W) {
            logger.error(values[i] + " does not fit the window");
            return false;
        }
    }
    var inner = Window.ARC_R - Window.ARC_W / 2;
    return Window.VALUE_MAX_W <= 2 * Math.sqrt(inner * inner - 6 * 6);
}

// Review focus: the Instinct's saved choices (Slots.Type numbers 0-10 from before this change)
// keep their meaning, and a saved value out of range or of the wrong kind falls back to the default.
(:test)
function savedSlotNumbersKeepTheirMeaning(logger as Logger) as Boolean {
    var saved = TestSlots.save();
    Properties.setValue("Slot1", 7);
    var bodyBattery = FaceSlots.typeOf(1) == Slots.BODY_BATTERY;
    Properties.setValue("Slot1", 99);
    var high = FaceSlots.typeOf(1) == FaceSlots.DEFAULTS[0];
    Properties.setValue("Slot1", -1);
    var low = FaceSlots.typeOf(1) == FaceSlots.DEFAULTS[0];
    Properties.setValue("Slot1", "7");
    var text = FaceSlots.typeOf(1) == FaceSlots.DEFAULTS[0];
    TestSlots.restore(saved);
    return bodyBattery && high && low && text && Slots.CALORIES == 10 && Slots.SUN == 24;
}
