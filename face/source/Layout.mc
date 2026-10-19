import Toybox.Graphics;
import Toybox.Lang;

// Where text goes on the 176x176 Instinct screen and which font fits.
// Limits were measured against the simulator's fonts and the semi-octagon outline
// (the top-left and bottom corners are cut; the subscreen circle starts at x=113).
// face/test/LayoutTests.mc checks every Hebrew date and title against them.
module Layout {

    const TEXT_RIGHT = 111;
    const GREGORIAN_Y = 9;
    const GREGORIAN_MAX_W = 85;
    const DAY_MONTH_Y = 29;
    const YEAR_Y = 50;
    const RULE_1_Y = 71;
    const PARASHA_Y = 71;
    const PARASHA_MAX_W = 168;
    const RULE_2_Y = 96;
    const GRID_TOP = 97;
    const ROW_HEIGHT = 23;
    const CENTER_X = 88;
    const COLUMN_GAP = 6;
    const ICON_W = 15;
    // Visible x range per grid row; the last row sits in the rounded bottom corners.
    const ROW_MIN_X = [3, 3, 24];
    const ROW_MAX_X = [173, 173, 152];

    // y for the Gregorian line: the cut corner widens by ~1.25 px per row, so wide dates
    // ("Mon 10 May") move down a little.
    function gregorianY(dc as Dc, text as String) as Number {
        var extra = dc.getTextWidthInPixels(text, Graphics.FONT_XTINY) - GREGORIAN_MAX_W;
        return extra <= 0 ? GREGORIAN_Y : GREGORIAN_Y + (extra * 4 + 4) / 5;
    }

    // [font, maxWidth] tried in order for the Hebrew day and month.
    function dayMonthFonts() as Array<Array> {
        return [[Graphics.FONT_MEDIUM, 103], [Graphics.FONT_SMALL, 107], [Graphics.FONT_XTINY, 107]];
    }

    // [font, y] for the Hebrew day and month; leap-year Adar names step down a size.
    function dayMonth(dc as Dc, text as String) as Array {
        var fonts = dayMonthFonts();
        var i = 0;
        while (i < fonts.size() - 1 && dc.getTextWidthInPixels(text, fonts[i][0]) > fonts[i][1]) {
            i++;
        }
        return [fonts[i][0], DAY_MONTH_Y + 2 * i];
    }

    // [text, font, y] for the parasha line: the largest font that fits; long double portions
    // drop the "פרשת " prefix.
    function parasha(dc as Dc, title as String) as Array {
        var candidates = [title];
        if (title.find("פרשת ") == 0) {
            candidates.add(title.substring(5, title.length()));
        }
        var fonts = [Graphics.FONT_SMALL, Graphics.FONT_XTINY];
        for (var c = 0; c < candidates.size(); c++) {
            for (var f = 0; f < fonts.size(); f++) {
                if (dc.getTextWidthInPixels(candidates[c], fonts[f]) <= PARASHA_MAX_W) {
                    return [candidates[c], fonts[f], PARASHA_Y + 2 * f];
                }
            }
        }
        return [candidates[candidates.size() - 1], Graphics.FONT_XTINY, PARASHA_Y + 2];
    }

    // [x, y, font, width] for a slot's icon+value. Left-column items end at the centre line and
    // right-column items start there, so the bottom row clears the rounded corners.
    function slot(dc as Dc, slot as Number, text as String) as Array {
        var row = (slot - 1) / 2;
        var left = (slot - 1) % 2 == 0;
        var y = GRID_TOP + row * ROW_HEIGHT;
        var fonts = [Graphics.FONT_SMALL, Graphics.FONT_XTINY];
        var x = 0;
        var width = 0;
        for (var f = 0; f < fonts.size(); f++) {
            width = ICON_W + dc.getTextWidthInPixels(text, fonts[f]);
            x = left ? CENTER_X - COLUMN_GAP / 2 - width : CENTER_X + COLUMN_GAP / 2;
            if (x >= ROW_MIN_X[row] && x + width <= ROW_MAX_X[row]) {
                return [x, f == 0 ? y : y + 1, fonts[f], width];
            }
        }
        // Still too wide for the rounded bottom row: pull it inward, toward the centre gap.
        if (x < ROW_MIN_X[row]) {
            x = ROW_MIN_X[row];
        } else if (x + width > ROW_MAX_X[row]) {
            x = ROW_MAX_X[row] - width;
        }
        return [x, y + 1, Graphics.FONT_XTINY, width];
    }
}
