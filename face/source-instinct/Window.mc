import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Slot 3 in the round subscreen, as a gauge drawn in the background colour on a disk of the
// foreground colour: a thin 270° track open at the bottom, a thick progress arc over it for gauge
// types (Slots.progress), the value in the middle and the icon of the type in the track's gap
// (the type to show, from Slots.resolve). A value too wide even in the smallest font drops its
// unit letters (unitless) as a last resort; the number is never cut.
module Window {

    const ARC_R = 26;
    const ARC_W = 4;
    // drawArc degrees (0 = 3 o'clock, counter-clockwise): the track runs clockwise from 7:30 to 4:30.
    const START = 225;
    const SWEEP = 270;
    const VALUE_FONTS = [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_XTINY];
    // Value y relative to the centre per font, so its digits are centred on it.
    const VALUE_DY = [-14, -13, -12];
    const VALUE_MAX_W = 46;
    const ICON_DY = 13;

    function draw(dc as Dc, cx as Number, cy as Number, r as Number, type as Number, text as String,
                  progress as Float, iconFont as FontResource, fg as Number, bg as Number) as Void {
        dc.setColor(fg, bg);
        dc.fillCircle(cx, cy, r);
        dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawArc(cx, cy, ARC_R, Graphics.ARC_CLOCKWISE, START, START - SWEEP + 360);
        var end = (START - SWEEP * progress).toNumber();
        if (progress > 0.0 && end != START) {
            dc.setPenWidth(ARC_W);
            dc.drawArc(cx, cy, ARC_R, Graphics.ARC_CLOCKWISE, START, end < 0 ? end + 360 : end);
            dc.setPenWidth(1);
        }
        var f = 0;
        while (f < VALUE_FONTS.size() - 1 && dc.getTextWidthInPixels(text, VALUE_FONTS[f]) > VALUE_MAX_W) {
            f++;
        }
        var shown = dc.getTextWidthInPixels(text, VALUE_FONTS[f]) > VALUE_MAX_W ? unitless(text) : text;
        dc.drawText(cx, cy + VALUE_DY[f], VALUE_FONTS[f], shown, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, cy + ICON_DY, iconFont, Slots.ICONS[type], Graphics.TEXT_JUSTIFY_CENTER);
    }

    // text without its trailing ASCII letters (the unit): "12.3km" is "12.3"; "%", "°" and digits stay.
    function unitless(text as String) as String {
        var chars = text.toCharArray();
        var n = chars.size();
        while (n > 0) {
            var c = chars[n - 1].toNumber();
            if (!((c >= 65 && c <= 90) || (c >= 97 && c <= 122))) {
                break;
            }
            n--;
        }
        return text.substring(0, n) as String;
    }
}
