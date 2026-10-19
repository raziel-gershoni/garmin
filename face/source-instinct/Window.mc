import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Slot 3 in the round subscreen, as a gauge drawn in the background colour on a disk of the
// foreground colour: a thin 270° track open at the bottom, a thick progress arc over it for gauge
// types (Slots.progress: steps to the daily goal, battery, Body Battery), the value in the middle
// and the slot's icon in the track's gap.
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
        dc.drawText(cx, cy + VALUE_DY[f], VALUE_FONTS[f], text, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, cy + ICON_DY, iconFont, Slots.ICONS[type], Graphics.TEXT_JUSTIFY_CENTER);
    }
}
