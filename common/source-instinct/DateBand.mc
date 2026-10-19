import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Shared by the watch face and the glance's detail view on the Instinct 3: the Gregorian date in
// the column left of the subscreen, and a dithered grey band below the subscreen (like the native
// faces' time band) with the full Hebrew date and the parasha, outlined so they stay sharp on it.
// The column is right-aligned at RIGHT, clear of the ring around the subscreen (it hides x > 100 on
// rows 25-38 and reaches down to row 74). The top-left corner is cut diagonally, so a line's usable
// width there depends on how high its leftmost glyph reaches: digits, icons, geresh, gershayim and
// lamed start ~6 rows below y, other Hebrew letters ~10. Geometry is from the simulator's device
// mask; face/test/LayoutTests.mc checks every date and title against it.
module DateBand {

    const RIGHT = 99;
    const GREGORIAN_Y = 2;
    // The band covers rows 75-123, just below the ring's last row (74); its bitmap is Rez.Drawables.Band.
    const BAND_TOP = 75;
    const BAND_HEIGHT = 49;
    // y per font [MEDIUM, SMALL, XTINY]: the outlined tall glyphs start inside the band, the date's
    // descenders end above the parasha's tall glyphs, and the parasha's outline ends inside the band.
    const HEBREW_Y = [70, 71, 71];
    const PARASHA_Y = [94, 94, 94];
    const ALONE_SHIFT = 12; // centres the date in the band while no parasha is known
    const CENTER_X = 88;
    const BAND_MAX_W = 168;
    const BAND_FONTS = [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_XTINY];
    const WORD_GAP = 4;
    const HIGH_INK = 6;
    const LOW_INK = 10;
    // First visible x of rows 0..40 in the cut top-left corner; lower rows start at x=1.
    const CUT = [40, 40, 39, 38, 36, 34, 33, 31, 30, 29, 27, 26, 25, 24, 22, 21, 20, 19, 18, 17,
                 16, 15, 14, 14, 13, 12, 11, 10, 10, 9, 8, 7, 7, 6, 5, 5, 4, 3, 3, 2, 1];

    // Widest right-aligned column text drawn at y, given whether its leftmost glyph reaches high.
    function maxWidth(y as Number, high as Boolean) as Number {
        var top = y + (high ? HIGH_INK : LOW_INK);
        return RIGHT - 1 - (top < CUT.size() ? CUT[top] : 1);
    }

    // y for the Gregorian line of the given width: wide dates move down where the cut corner
    // leaves more room.
    function gregorianY(width as Number) as Number {
        var y = GREGORIAN_Y;
        while (y < GREGORIAN_Y + 6 && width > maxWidth(y, true)) {
            y++;
        }
        return y;
    }

    // Weekday letter and day.month ("ב׳ 19.10"), right-aligned in the column. Drawn as two pieces
    // so the order does not depend on the firmware's handling of numbers inside Hebrew text.
    // info must be Time.FORMAT_SHORT (numeric weekday and month).
    function drawGregorian(dc as Dc, info as Gregorian.Info) as Void {
        var font = Graphics.FONT_XTINY;
        var weekday = HebrewFormat.weekday(info.day_of_week as Number);
        var date = info.day + "." + info.month;
        var weekdayWidth = dc.getTextWidthInPixels(weekday, font);
        var y = gregorianY(weekdayWidth + WORD_GAP + dc.getTextWidthInPixels(date, font));
        dc.drawText(RIGHT, y, font, weekday, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(RIGHT - weekdayWidth - WORD_GAP, y, font, date, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // [text, font, y] for the full Hebrew date ("ח׳ חשון תשפ״ז"): the largest font that fits the
    // band. Leap-year Adar dates drop the month's geresh only if nothing else fits.
    function hebrewDate(dc as Dc, hdate as Array<Number>) as Array {
        return fit(dc, dateOptions(hdate, BAND_FONTS), HEBREW_Y, BAND_MAX_W);
    }

    // [text, font, y] for the parasha line; long double portions drop the "פרשת " prefix.
    function parasha(dc as Dc, title as String) as Array {
        return fit(dc, parashaOptions(title, BAND_FONTS), PARASHA_Y, BAND_MAX_W);
    }

    // [text, font] to try for the full Hebrew date, in fonts (largest first); without the month's
    // geresh (leap-year Adar I/II) last.
    function dateOptions(hdate as Array<Number>, fonts as Array) as Array<Array> {
        var dayMonth = HebrewFormat.dayMonth(hdate);
        var year = HebrewFormat.year(hdate);
        return fullThenCompact(dayMonth + " " + year,
            dayMonth.substring(0, dayMonth.length() - 1) + " " + year,
            dayMonth.substring(dayMonth.length() - 1, dayMonth.length()).equals(HebrewFormat.GERESH), fonts);
    }

    // [text, font] to try for a parasha or holiday title, in fonts; without "פרשת " last. Nothing
    // is abbreviated.
    function parashaOptions(title as String, fonts as Array) as Array<Array> {
        var prefixed = title.find("פרשת ") == 0;
        return fullThenCompact(title, prefixed ? title.substring(5, title.length()) : "", prefixed, fonts);
    }

    // The full text in every font, then (if there is one) the compact text in every font but MEDIUM.
    function fullThenCompact(full as String, compact as String, hasCompact as Boolean, fonts as Array) as Array<Array> {
        var options = [];
        for (var i = 0; i < fonts.size(); i++) {
            options.add([full, fonts[i]]);
        }
        for (var i = 0; hasCompact && i < fonts.size(); i++) {
            if (fonts[i] != Graphics.FONT_MEDIUM) {
                options.add([compact, fonts[i]]);
            }
        }
        return options;
    }

    // First option at most maxWidth wide, as [text, font, y]; otherwise the last one.
    // ys holds the line's y for [MEDIUM, SMALL, XTINY].
    function fit(dc as Dc, options as Array<Array>, ys as Array<Number>, maxWidth as Number) as Array {
        var o = options[options.size() - 1];
        for (var i = 0; i < options.size(); i++) {
            if (dc.getTextWidthInPixels(options[i][0], options[i][1]) <= maxWidth) {
                o = options[i];
                break;
            }
        }
        var font = o[1];
        return [o[0], font, ys[font == Graphics.FONT_MEDIUM ? 0 : font == Graphics.FONT_SMALL ? 1 : 2]];
    }

    // The band: grey background, Hebrew date, parasha (if known). Lines are [text, font, y] from
    // hebrewDate() and parasha(); fg/bg are the face's text and background colours.
    function drawBand(dc as Dc, band as BitmapResource?, hebrew as Array, parashaLine as Array?,
                      fg as Number, bg as Number) as Void {
        if (band != null) {
            dc.drawBitmap(0, BAND_TOP, band);
        }
        drawOutlined(dc, (hebrew[2] as Number) + (parashaLine == null ? ALONE_SHIFT : 0), hebrew, fg, bg);
        if (parashaLine != null) {
            drawOutlined(dc, parashaLine[2] as Number, parashaLine, fg, bg);
        }
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
    }

    // Centred text with a 1px outline in the background colour, so thin strokes read on the dither.
    function drawOutlined(dc as Dc, y as Number, line as Array, fg as Number, bg as Number) as Void {
        drawOutlinedText(dc, CENTER_X, y, line[1], line[0], Graphics.TEXT_JUSTIFY_CENTER, fg, bg);
    }

    function drawOutlinedText(dc as Dc, x as Number, y as Number, font as FontType, text as String,
                              justify as Number, fg as Number, bg as Number) as Void {
        dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
        for (var dx = -1; dx <= 1; dx++) {
            for (var dy = -1; dy <= 1; dy++) {
                if (dx != 0 || dy != 0) {
                    dc.drawText(x + dx, y + dy, font, text, justify);
                }
            }
        }
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, justify);
    }
}
