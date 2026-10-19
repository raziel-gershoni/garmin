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

// Every day of a leap year and a common year fits beside the cut corner and the subscreen.
(:test)
function hebrewDatesFitTopBlock(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var fonts = Layout.dayMonthFonts();
    var failures = 0;
    var years = [5787, 5788]; // 5787 is a leap year (Adar I/II)
    for (var y = 0; y < years.size(); y++) {
        var start = HebrewCalendar.newYear(years[y]);
        var end = HebrewCalendar.newYear(years[y] + 1);
        for (var rd = start; rd < end; rd++) {
            var h = HebrewCalendar.fromFixed(rd);
            var text = HebrewFormat.dayMonth(h);
            var font = Layout.dayMonth(dc, text)[0];
            var max = 0;
            for (var i = 0; i < fonts.size(); i++) {
                if (fonts[i][0] == font) {
                    max = fonts[i][1];
                }
            }
            if (dc.getTextWidthInPixels(text, font) > max) {
                logger.error(text + " is too wide");
                failures++;
            }
            if (dc.getTextWidthInPixels(HebrewFormat.year(h), Graphics.FONT_XTINY) > 107) {
                failures++;
            }
        }
    }
    // Bitmap-font widths add up, so the widest parts give the widest date.
    var parts = [["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
                 [" 10 ", " 11 ", " 20 ", " 22 ", " 28 ", " 30 ", " 31 "],
                 ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]];
    var widest = "";
    for (var p = 0; p < parts.size(); p++) {
        var best = parts[p][0];
        for (var i = 1; i < parts[p].size(); i++) {
            if (dc.getTextWidthInPixels(parts[p][i], Graphics.FONT_XTINY) > dc.getTextWidthInPixels(best, Graphics.FONT_XTINY)) {
                best = parts[p][i];
            }
        }
        widest += best;
    }
    // Moving down by d rows gains ~1.25*d px at the corner; never more than 4 rows.
    var w = dc.getTextWidthInPixels(widest, Graphics.FONT_XTINY);
    var shift = Layout.gregorianY(dc, widest) - Layout.GREGORIAN_Y;
    logger.debug("widest gregorian '" + widest + "' w=" + w + " shift=" + shift);
    if (shift > 4 || w > Layout.GREGORIAN_MAX_W + shift * 5 / 4) {
        failures++;
    }
    return failures == 0;
}

// Every parasha (Israel) and every holiday that replaces one on Shabbat fits the line,
// including Hebcal API spellings that differ from @hebcal/core's.
(:test)
function parashaTitlesFitLine(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var titles = TitleFixtures.TITLES.slice(0, null);
    titles.addAll(["פרשת אחרי מות־קדושים", "פרשת תזריע־מצורע", "פרשת בהר־בחוקותי"]);
    var failures = 0;
    for (var i = 0; i < titles.size(); i++) {
        var p = Layout.parasha(dc, titles[i]);
        if (dc.getTextWidthInPixels(p[0], p[1]) > Layout.PARASHA_MAX_W) {
            logger.error(titles[i] + " does not fit");
            failures++;
        }
    }
    return failures == 0;
}

// Widest realistic slot values stay inside each row's visible range.
(:test)
function slotValuesFitGrid(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var values = ["88888", "23:59", "12:59", "100%", "3999m", "--:--", "--"];
    var failures = 0;
    for (var slot = 1; slot <= Slots.SLOT_COUNT; slot++) {
        var row = (slot - 1) / 2;
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

// Left and right items of a row never touch, even with the widest pairs.
(:test)
function slotPairsDoNotOverlap(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var pairs = [["88888", "88888"], ["3999m", "23:59"], ["23:59", "3999m"], ["88888", "23:59"]];
    for (var row = 0; row < 3; row++) {
        for (var i = 0; i < pairs.size(); i++) {
            var l = Layout.slot(dc, row * 2 + 1, pairs[i][0]);
            var r = Layout.slot(dc, row * 2 + 2, pairs[i][1]);
            if (l[0] + l[3] >= r[0]) {
                logger.error("row " + row + " " + pairs[i].toString() + " overlaps");
                return false;
            }
        }
    }
    return true;
}
