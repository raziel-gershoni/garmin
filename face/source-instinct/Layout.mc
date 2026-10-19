import Toybox.Graphics;
import Toybox.Lang;

// Where everything goes on the 176x176 Instinct screen, top to bottom:
// - the column left of the subscreen: the Gregorian date (DateBand.drawGregorian), slots 1-2 side
//   by side, and slot 4 under them;
// - the subscreen: slot 3 as a gauge (Window.mc);
// - the grey band (DateBand.BAND_TOP, BAND_HEIGHT rows) with the time and seconds in
//   seven-segment digits (Rez.Fonts.Time), outlined like the band's text elsewhere;
// - the full Hebrew date and the parasha or holiday, on the background below the band;
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

    // The band (shorter than the glance's) and the time on it, outlined, with a grey row above and
    // below the outline. The time's ink starts TIME_INK_DY rows below y (measured in the
    // simulator). It is laid out as TIME_TEMPLATE (every digit has the same advance), so a
    // one-digit hour leaves its first digit blank and nothing moves.
    const BAND_HEIGHT = 35;
    const TIME_Y = 77;
    const TIME_INK_DY = 1;
    const TIME_TEMPLATE = "00:00:00";

    // The Hebrew date and the parasha under the band, centred, in SMALL or XTINY (Hebrew is no
    // smaller in XTINY on this watch, only narrower; MEDIUM is too tall). y per font [MEDIUM
    // (unused), SMALL, XTINY] puts the ink on the same rows. Both lines' limits keep them inside
    // the bottom corners on every row they can reach (the date's when it is moved down too).
    // Without a parasha the date moves down by ALONE_SHIFT, to the middle of the two lines' space.
    const LINE_FONTS = [Graphics.FONT_SMALL, Graphics.FONT_XTINY];
    const HEBREW_Y = [106, 106, 107];
    const PARASHA_Y = [126, 126, 127];
    const HEBREW_MAX_W = 166;
    const PARASHA_MAX_W = 152;
    const ALONE_SHIFT = 10;

    // Slots 5-6: the left one ends BOTTOM_GAP / 2 before the centre line and the right one starts
    // as far after it. The visible x range covers the rows their glyphs reach (154-167), where
    // the bottom corners narrow it.
    const BOTTOM_Y = 148;
    const BOTTOM_GAP = 4;
    const BOTTOM_MIN_X = 30;
    const BOTTOM_MAX_X = 146;

    function itemWidth(dc as Dc, text as String, font as FontType) as Number {
        return ICON_W + dc.getTextWidthInPixels(text, font);
    }

    // An item's width with or without its icon.
    function valueWidth(dc as Dc, text as String, font as FontType, icon as Boolean) as Number {
        return icon ? itemWidth(dc, text, font) : dc.getTextWidthInPixels(text, font);
    }

    // Places for a column line (y is PAIR_Y or SLOT4_Y) as [left, right], each [x, y, font, iconY]
    // or null where the slot's text is null (empty slot); iconY is null when the icons are left
    // out. A lone item ends at DateBand.RIGHT. The line takes the first of SMALL, XTINY, then XTINY
    // without icons that fits, so wide pairs (five-digit steps, sunrise beside sunset) stay whole;
    // a pair too wide even then (a four-digit or negative altitude beside steps, a time or another
    // wide value) starts at the visible edge and its gap closes.
    function line(dc as Dc, y as Number, left as String?, right as String?) as Array {
        var f = 0;
        var icons = true;
        while (lineWidth(dc, left, right, FONTS[f], icons) > DateBand.maxWidth(y + f, true) && icons) {
            if (f < FONTS.size() - 1) {
                f++;
            } else {
                icons = false;
            }
        }
        var font = FONTS[f];
        var rightX = DateBand.RIGHT - (right == null ? 0 : valueWidth(dc, right, font, icons));
        var leftX = (right == null ? DateBand.RIGHT : rightX - PAIR_GAP) - (left == null ? 0 : valueWidth(dc, left, font, icons));
        var minX = DateBand.RIGHT - DateBand.maxWidth(y + f, true);
        var iconY = icons ? y + ICON_DY : null;
        return [left == null ? null : [leftX < minX ? minX : leftX, y + f, font, iconY],
                right == null ? null : [rightX, y + f, font, iconY]];
    }

    function lineWidth(dc as Dc, left as String?, right as String?, font as FontType, icons as Boolean) as Number {
        var w = (left == null ? 0 : valueWidth(dc, left, font, icons)) + (right == null ? 0 : valueWidth(dc, right, font, icons));
        return left != null && right != null ? w + PAIR_GAP : w;
    }

    // [text, font, y] for the Hebrew date and for the parasha line, centred at CENTER_X.
    function hebrewDate(dc as Dc, hdate as Array<Number>) as Array {
        return DateBand.fit(dc, DateBand.dateOptions(hdate, LINE_FONTS), HEBREW_Y, HEBREW_MAX_W);
    }

    function parasha(dc as Dc, title as String) as Array {
        return DateBand.fit(dc, DateBand.parashaOptions(title, LINE_FONTS), PARASHA_Y, PARASHA_MAX_W);
    }

    // Right edge of the time, which is centred as TIME_TEMPLATE.
    function timeRight(dc as Dc, font as FontType) as Number {
        return CENTER_X + dc.getTextWidthInPixels(TIME_TEMPLATE, font) / 2;
    }

    // [x, y, width, height] that onPartialUpdate redraws: the seconds' two digits with their
    // outline, from one row above y to one below the ink's last row, so it holds them with or
    // without the ink offset. It stops short of the colon's outline.
    function secondsBox(dc as Dc, font as FontType) as Array<Number> {
        var w = dc.getTextWidthInPixels("00", font);
        return [timeRight(dc, font) - w - 1, TIME_Y - 1, w + 1, dc.getFontHeight(font) + TIME_INK_DY + 2];
    }

    // Places for slots 5 and 6 as [left, right], each [x, y, font, iconY] or null for an empty
    // slot; iconY is null when the icons are left out. Both take the first of SMALL, XTINY, then
    // XTINY without icons in which they fit their side of the row, so wide values stay whole; a
    // value too wide even then keeps to the visible edge and the gap closes.
    function bottomRow(dc as Dc, left as String?, right as String?) as Array {
        var f = 0;
        var icons = true;
        while (!bottomFits(dc, left, right, FONTS[f], icons) && icons) {
            if (f < FONTS.size() - 1) {
                f++;
            } else {
                icons = false;
            }
        }
        var font = FONTS[f];
        var iconY = icons ? BOTTOM_Y + ICON_DY : null;
        var l = null;
        var r = null;
        if (left != null) {
            var x = CENTER_X - BOTTOM_GAP / 2 - valueWidth(dc, left, font, icons);
            l = [x < BOTTOM_MIN_X ? BOTTOM_MIN_X : x, BOTTOM_Y + f, font, iconY];
        }
        if (right != null) {
            var w = valueWidth(dc, right, font, icons);
            var x = CENTER_X + BOTTOM_GAP / 2;
            r = [x + w > BOTTOM_MAX_X ? BOTTOM_MAX_X - w : x, BOTTOM_Y + f, font, iconY];
        }
        return [l, r];
    }

    function bottomFits(dc as Dc, left as String?, right as String?, font as FontType, icons as Boolean) as Boolean {
        return (left == null || CENTER_X - BOTTOM_GAP / 2 - valueWidth(dc, left, font, icons) >= BOTTOM_MIN_X)
            && (right == null || CENTER_X + BOTTOM_GAP / 2 + valueWidth(dc, right, font, icons) <= BOTTOM_MAX_X);
    }
}
