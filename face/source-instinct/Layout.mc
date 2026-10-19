import Toybox.Graphics;
import Toybox.Lang;

// Where everything goes on the 176x176 Instinct screen, top to bottom:
// - the column left of the subscreen: the Gregorian date (DateBand.drawGregorian), slots 1-2 side
//   by side, and slot 4 under them;
// - the subscreen: slot 3 as a gauge (Window.mc);
// - the grey band with the full Hebrew date and the parasha or holiday (DateBand.drawBand);
// - the time with seconds, in seven-segment digits (Rez.Fonts.Time);
// - slots 5-6 along the bottom.
// Limits were measured against the simulator's fonts and the semi-octagon outline (the corners
// are cut); face/test-instinct/LayoutTests.mc checks the widest values against them.
module Layout {

    const CENTER_X = 88;
    const ICON_W = 15;
    const ICON_DY = 6;
    const FONTS = [Graphics.FONT_SMALL, Graphics.FONT_XTINY];

    // Column lines under the Gregorian date, ending at DateBand.RIGHT: slots 1-2 side by side,
    // then slot 4. In XTINY a line sits one row lower, so its digits line up with the icons.
    const PAIR_Y = 26;
    const SLOT4_Y = 48;
    const PAIR_GAP = 6;

    // The time line, 3 rows under the band and 3 above slots 5-6: its ink starts TIME_INK_DY rows
    // below y (measured in the simulator). It is laid out as TIME_TEMPLATE (every digit has the
    // same advance), so a one-digit hour leaves its first digit blank and nothing moves.
    const TIME_Y = 126;
    const TIME_INK_DY = 1;
    const TIME_TEMPLATE = "00:00:00";

    // Slots 5-6: the left one ends at the centre line and the right one starts there. The visible
    // x range covers the rows their glyphs reach (151-164), where the bottom corners narrow it.
    const BOTTOM_Y = 145;
    const BOTTOM_GAP = 6;
    const BOTTOM_MIN_X = 26;
    const BOTTOM_MAX_X = 150;

    function itemWidth(dc as Dc, text as String, font as FontType) as Number {
        return ICON_W + dc.getTextWidthInPixels(text, font);
    }

    // Places for a column line (y is PAIR_Y or SLOT4_Y) as [left, right], each [x, y, font, iconY]
    // or null where the slot's text is null (empty slot). Both use the largest font in which the
    // line fits; a lone item ends at DateBand.RIGHT.
    function line(dc as Dc, y as Number, left as String?, right as String?) as Array {
        var f = 0;
        while (f < FONTS.size() - 1 && lineWidth(dc, left, right, FONTS[f]) > DateBand.maxWidth(y + f, true)) {
            f++;
        }
        var font = FONTS[f];
        var rightX = DateBand.RIGHT - (right == null ? 0 : itemWidth(dc, right, font));
        var leftX = (right == null ? DateBand.RIGHT : rightX - PAIR_GAP) - (left == null ? 0 : itemWidth(dc, left, font));
        return [left == null ? null : [leftX, y + f, font, y + ICON_DY],
                right == null ? null : [rightX, y + f, font, y + ICON_DY]];
    }

    function lineWidth(dc as Dc, left as String?, right as String?, font as FontType) as Number {
        var w = (left == null ? 0 : itemWidth(dc, left, font)) + (right == null ? 0 : itemWidth(dc, right, font));
        return left != null && right != null ? w + PAIR_GAP : w;
    }

    // Right edge of the time line, which is centred as TIME_TEMPLATE.
    function timeRight(dc as Dc, font as FontType) as Number {
        return CENTER_X + dc.getTextWidthInPixels(TIME_TEMPLATE, font) / 2;
    }

    // [x, y, width, height] of the seconds' two digits, which onPartialUpdate redraws: from y down
    // to the ink's last row, so it holds them with or without the ink offset.
    function secondsBox(dc as Dc, font as FontType) as Array<Number> {
        var w = dc.getTextWidthInPixels("00", font);
        return [timeRight(dc, font) - w, TIME_Y, w, dc.getFontHeight(font) + TIME_INK_DY];
    }

    // [x, y, font, iconY] for slot 5 (left) or 6 (right): the largest font that fits.
    function bottomSlot(dc as Dc, left as Boolean, text as String) as Array {
        var x = 0;
        var width = 0;
        for (var f = 0; f < FONTS.size(); f++) {
            width = itemWidth(dc, text, FONTS[f]);
            x = left ? CENTER_X - BOTTOM_GAP / 2 - width : CENTER_X + BOTTOM_GAP / 2;
            if (x >= BOTTOM_MIN_X && x + width <= BOTTOM_MAX_X) {
                return [x, BOTTOM_Y + f, FONTS[f], BOTTOM_Y + ICON_DY];
            }
        }
        // Still too wide for the narrowing bottom: pull it inward, toward the centre gap.
        x = left ? BOTTOM_MIN_X : BOTTOM_MAX_X - width;
        return [x, BOTTOM_Y + 1, Graphics.FONT_XTINY, BOTTOM_Y + ICON_DY];
    }
}
