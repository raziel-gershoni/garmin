import Toybox.Graphics;
import Toybox.Lang;

// Where the slots go on the 176x176 Instinct screen and which font fits; the dates and the parasha
// are in common/source/DateBand.mc. Slots 1-2 sit in the column left of the subscreen, under the
// Gregorian date; slots 3-6 form a 2x2 grid under the band. Limits were measured against the
// simulator's fonts and the semi-octagon outline (the bottom corners are cut).
// face/test/LayoutTests.mc checks the widest values against them.
module Layout {

    const COLUMN_Y = [24, 46];
    const GRID_TOP = 121;
    const ROW_HEIGHT = 23;
    const CENTER_X = 88;
    const COLUMN_GAP = 6;
    const ICON_W = 15;
    const ICON_DY = 6;
    // Visible x range per grid row (x + width <= max), from the device mask over the rows each
    // row's glyphs cover (127-140 and 150-163); the bottom corners narrow both.
    const ROW_MIN_X = [6, 25];
    const ROW_MAX_X = [170, 151];

    // [x, y, font, width, iconY] for a slot's icon+value: the largest font that fits.
    function slot(dc as Dc, slot as Number, text as String) as Array {
        var fonts = [Graphics.FONT_SMALL, Graphics.FONT_XTINY];
        if (slot <= COLUMN_Y.size()) {
            var top = COLUMN_Y[slot - 1];
            var max = DateBand.maxWidth(top, true);
            var f = 0;
            while (f < fonts.size() - 1 && ICON_W + dc.getTextWidthInPixels(text, fonts[f]) > max) {
                f++;
            }
            var w = ICON_W + dc.getTextWidthInPixels(text, fonts[f]);
            return [DateBand.RIGHT - w, top + f, fonts[f], w, top + ICON_DY];
        }
        return gridSlot(dc, slot - COLUMN_Y.size() - 1, text, fonts);
    }

    // Grid items: left-column items end at the centre line and right-column items start there,
    // so the bottom row clears the rounded corners.
    function gridSlot(dc as Dc, index as Number, text as String, fonts as Array) as Array {
        var row = index / 2;
        var left = index % 2 == 0;
        var y = GRID_TOP + row * ROW_HEIGHT;
        var x = 0;
        var width = 0;
        for (var f = 0; f < fonts.size(); f++) {
            width = ICON_W + dc.getTextWidthInPixels(text, fonts[f]);
            x = left ? CENTER_X - COLUMN_GAP / 2 - width : CENTER_X + COLUMN_GAP / 2;
            if (x >= ROW_MIN_X[row] && x + width <= ROW_MAX_X[row]) {
                return [x, y + f, fonts[f], width, y + ICON_DY];
            }
        }
        // Still too wide for the rounded bottom row: pull it inward, toward the centre gap.
        if (x < ROW_MIN_X[row]) {
            x = ROW_MIN_X[row];
        } else if (x + width > ROW_MAX_X[row]) {
            x = ROW_MAX_X[row] - width;
        }
        return [x, y + 1, Graphics.FONT_XTINY, width, y + ICON_DY];
    }
}
