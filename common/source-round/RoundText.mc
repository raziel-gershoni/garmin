import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.StringUtil;

// Text on the round Venu screen, shared by the face and the glance's detail view.
// - Rim lines: drawRadialText lays characters out in typing order with no right-to-left
//   reordering (checked in the Venu 4 simulator), so rim strings are reversed into visual order.
//   They are pure Hebrew: no digits or brackets that would need their own direction.
// - Pairs: a Hebrew word with digits beside it ("ב׳ 19.10", "זריחה 06:44"), drawn as two
//   pieces because Noto Sans Hebrew has no digits.
// Sizes are for the 390 px Venu 4 41 mm and scale with the screen width.
module RoundText {

    const BOLD = "NotoSansHebrewBold";
    const REGULAR = "NotoSansHebrewRegular";
    const RIM_INSET = 44;     // baseline radius = screen radius - inset
    const RIM_DEGREES = 64;   // arc a rim line may cover, centred on 12 or 6 o'clock (clear of the rings)
    const SIZES = [32, 28, 26, 24, 22];

    var _fonts = {} as Dictionary<String, Graphics.VectorFont>;

    // A vector font by face (with Roboto as the fallback face) at a 390 px size; cached.
    function font(face as String, size as Number, width as Number) as Graphics.VectorFont {
        var px = size * width / 390;
        var key = face + px;
        var f = _fonts[key];
        if (f == null) {
            f = Graphics.getVectorFont({:face => [face, "RobotoRegular"], :size => px}) as Graphics.VectorFont;
            _fonts[key] = f;
        }
        return f;
    }

    // Pure Hebrew in visual (left-to-right) order, for drawRadialText.
    function visual(text as String) as String {
        var chars = text.toCharArray();
        var n = chars.size();
        for (var i = 0; i < n / 2; i++) {
            var t = chars[i];
            chars[i] = chars[n - 1 - i];
            chars[n - 1 - i] = t;
        }
        return StringUtil.charArrayToString(chars);
    }

    function rimRadius(width as Number) as Number {
        return width / 2 - RIM_INSET * width / 390;
    }

    // Longest text (px) a rim line may have.
    function rimMaxLength(width as Number) as Number {
        return (rimRadius(width) * RIM_DEGREES * Math.PI / 180).toNumber();
    }

    // [text, size] options for the full Hebrew date: the full text at every size, then, for
    // leap-year Adar, without the month's geresh.
    function dateOptions(hdate as Array<Number>) as Array<Array> {
        var dayMonth = HebrewFormat.dayMonth(hdate);
        var year = HebrewFormat.year(hdate);
        var options = sized(dayMonth + " " + year, SIZES);
        if (dayMonth.substring(dayMonth.length() - 1, dayMonth.length()).equals(HebrewFormat.GERESH)) {
            options.addAll(sized(dayMonth.substring(0, dayMonth.length() - 1) + " " + year, [24, 22]));
        }
        return options;
    }

    // [text, size] options for a parasha or holiday: the full title at full size, then (as the
    // spec says) without "פרשת " before the font steps down.
    function titleOptions(title as String) as Array<Array> {
        if (title.find("פרשת ") != 0) {
            return sized(title, SIZES);
        }
        var options = sized(title, [SIZES[0]]);
        options.addAll(sized(title.substring(5, title.length()), SIZES));
        return options;
    }

    function sized(text as String, sizes as Array<Number>) as Array<Array> {
        var out = [] as Array<Array>;
        for (var i = 0; i < sizes.size(); i++) {
            out.add([text, sizes[i]]);
        }
        return out;
    }

    // [visualText, font] for the first option that fits the rim arc; the last option otherwise.
    // low: always-on, which uses the thinner face.
    function fitRim(dc as Dc, options as Array<Array>, width as Number, low as Boolean) as Array {
        var max = rimMaxLength(width);
        var face = low ? REGULAR : BOLD;
        var chosen = options[options.size() - 1];
        for (var i = 0; i < options.size(); i++) {
            var text = visual(options[i][0] as String);
            if (dc.getTextWidthInPixels(text, font(face, options[i][1] as Number, width)) <= max) {
                chosen = options[i];
                break;
            }
        }
        return [visual(chosen[0] as String), font(face, chosen[1] as Number, width)];
    }

    // A rim line centred on 12 o'clock (top) or 6 o'clock, upright either way.
    function drawRim(dc as Dc, cx as Number, cy as Number, width as Number, line as Array, top as Boolean) as Void {
        dc.drawRadialText(cx, cy, line[1] as Graphics.VectorFont, line[0] as String, Graphics.TEXT_JUSTIFY_CENTER,
            top ? 90 : 270, rimRadius(width),
            top ? Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE : Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);
    }

    // A Hebrew word with Latin/digit text to its left, centred on cx: "ב׳ 19.10". Two pieces, so
    // the order never depends on the firmware's handling of mixed text.
    function drawPair(dc as Dc, cx as Number, y as Number, hebrew as String, hebrewFont as Graphics.FontType,
                      other as String, otherFont as Graphics.FontType, gap as Number) as Void {
        var hw = dc.getTextWidthInPixels(hebrew, hebrewFont);
        var right = cx + (hw + gap + dc.getTextWidthInPixels(other, otherFont)) / 2;
        dc.drawText(right, y, hebrewFont, hebrew, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(right - hw - gap, y, otherFont, other, Graphics.TEXT_JUSTIFY_RIGHT);
    }
}
