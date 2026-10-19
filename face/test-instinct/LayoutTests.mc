import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;

(:test)
module LayoutTestSupport {
    function offscreenDc() as Dc {
        var ref = Graphics.createBufferedBitmap({:width => 176, :height => 176});
        return (ref.get() as BufferedBitmap).getDc();
    }
}

// Visible screen near the subscreen, measured from the simulator's device mask independently of
// DateBand's own table: last visible x left of the ring for rows 0..74 (the ring ends there) and
// first visible x in the cut top-left corner for rows 0..40.
(:test)
module ScreenMask {
    const RING = [-1, 113, 112, 111, 110, 109, 108, 108, 107, 106, 106, 105, 105, 104, 104, 103, 103, 103,
                  102, 102, 102, 101, 101, 101, 101, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100,
                  100, 100, 100, 101, 101, 101, 101, 102, 102, 102, 103, 103, 103, 104, 104, 105, 105, 106,
                  106, 107, 108, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 119, 120, 122, 124, 126,
                  128, 132, 136];
    const CUT = [-1, 40, 39, 38, 36, 34, 33, 31, 30, 29, 27, 26, 25, 24, 22, 21, 20, 19, 18, 17, 16, 15,
                 14, 14, 13, 12, 11, 10, 10, 9, 8, 7, 7, 6, 5, 5, 4, 3, 3, 2, 1];

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
// fits the band; only Adar I/II dates may lose the month's geresh.
(:test)
function hebrewDatesFitBand(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var failures = 0;
    var counts = {};
    var years = [5787, 5788, 5798];
    for (var y = 0; y < years.size(); y++) {
        var start = HebrewCalendar.newYear(years[y]);
        var end = HebrewCalendar.newYear(years[y] + 1);
        for (var rd = start; rd < end; rd++) {
            var h = HebrewCalendar.fromFixed(rd);
            var line = DateBand.hebrewDate(dc, h);
            var width = dc.getTextWidthInPixels(line[0], line[1]);
            var compacted = !line[0].equals(HebrewFormat.full(h));
            if (width > DateBand.BAND_MAX_W || (compacted && h[1] < HebrewCalendar.ADAR)) {
                logger.error(HebrewFormat.full(h) + " -> " + line[0] + " w=" + width);
                failures++;
            }
            var key = line[1].toString() + (compacted ? "c" : "");
            counts[key] = counts.hasKey(key) ? counts[key] + 1 : 1;
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

// Slots 1-2 (in the column beside the subscreen) fit with the widest values.
(:test)
function columnSlotsFit(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var values = ["88888", "23:59", "12:59", "100%", "3999m", "-417m", "--:--"];
    for (var slot = 1; slot <= 2; slot++) {
        for (var i = 0; i < values.size(); i++) {
            var p = Layout.slot(dc, slot, values[i]);
            if (!ScreenMask.fitsColumn(Layout.COLUMN_Y[slot - 1], p[3], true) || p[2] != Graphics.FONT_SMALL) {
                logger.error("slot " + slot + " " + values[i] + " x=" + p[0] + " w=" + p[3] + " font=" + p[2]);
                return false;
            }
        }
    }
    return true;
}

// Rows of the column, the band and the grid stack without touching (ink offsets measured in the
// simulator: tall glyphs start 6 rows below y, 7 for MEDIUM Hebrew; letters end 20-21 rows below,
// descenders 27; band text has a 1px outline). The band's fonts are [MEDIUM, SMALL, XTINY].
(:test)
function bandAndColumnStack(logger as Logger) as Boolean {
    var h = DateBand.HEBREW_Y;
    var p = DateBand.PARASHA_Y;
    var top = DateBand.BAND_TOP;
    var bottom = DateBand.BAND_TOP + DateBand.BAND_HEIGHT - 1;
    return DateBand.GREGORIAN_Y + 3 + 21 < Layout.COLUMN_Y[0] + 6
        && Layout.COLUMN_Y[0] + 21 < Layout.COLUMN_Y[1] + 6
        && Layout.COLUMN_Y[1] + 21 < top - 2
        // the band starts below the ring, and the outlined text starts inside it
        && top >= ScreenMask.RING.size()
        && h[0] + 7 - 1 > top && h[1] + 6 - 1 > top && h[2] + 6 - 1 > top
        // the date's descenders end above the parasha's tall glyphs
        && h[1] + 27 < p[0] + 7 - 1 && h[1] + 27 < p[1] + 6 - 1 && h[1] + 27 < p[2] + 6 - 1
        // the parasha's outlined descenders end inside the band; the date alone stays inside too
        && p[0] + 27 + 1 < bottom && p[1] + 27 + 1 < bottom && p[2] + 27 + 1 < bottom
        && h[0] + DateBand.ALONE_SHIFT + 27 + 1 < bottom
        && bottom + 2 < Layout.GRID_TOP + 6;
}

// Every parasha (Israel) and every holiday that replaces one on Shabbat fits the band,
// including Hebcal API spellings that differ from @hebcal/core's.
(:test)
function parashaTitlesFitBand(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var titles = TitleFixtures.TITLES.slice(0, null);
    titles.addAll(["פרשת אחרי מות־קדושים", "פרשת תזריע־מצורע", "פרשת בהר־בחוקותי"]);
    var failures = 0;
    for (var i = 0; i < titles.size(); i++) {
        var p = DateBand.parasha(dc, titles[i]);
        if (dc.getTextWidthInPixels(p[0], p[1]) > DateBand.BAND_MAX_W) {
            logger.error(titles[i] + " does not fit");
            failures++;
        }
    }
    return failures == 0;
}

// Widest realistic slot values stay inside each grid row's visible range.
(:test)
function slotValuesFitGrid(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var values = ["88888", "23:59", "12:59", "100%", "3999m", "--:--", "--"];
    var failures = 0;
    for (var slot = 3; slot <= Slots.SLOT_COUNT; slot++) {
        var row = (slot - 3) / 2;
        for (var i = 0; i < values.size(); i++) {
            var p = Layout.slot(dc, slot, values[i]);
            if (p[0] < Layout.ROW_MIN_X[row] || p[0] + p[3] > Layout.ROW_MAX_X[row]) {
                logger.error("slot " + slot + " " + values[i] + " x=" + p[0] + " w=" + p[3]);
                failures++;
            }
        }
    }
    return failures == 0;
}

// Left and right items of a grid row never touch, even with the widest pairs.
(:test)
function slotPairsDoNotOverlap(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var pairs = [["88888", "88888"], ["3999m", "23:59"], ["23:59", "3999m"], ["88888", "23:59"]];
    for (var row = 0; row < 2; row++) {
        for (var i = 0; i < pairs.size(); i++) {
            var l = Layout.slot(dc, row * 2 + 3, pairs[i][0]);
            var r = Layout.slot(dc, row * 2 + 4, pairs[i][1]);
            if (l[0] + l[3] >= r[0]) {
                logger.error("row " + row + " " + pairs[i].toString() + " overlaps");
                return false;
            }
        }
    }
    return true;
}
