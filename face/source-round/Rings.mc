import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// Six ring subdials, three per side between the rim lines: slots 1, 3, 5 on the left, 2, 4, 6 on
// the right, rows top to bottom (the Instinct's row pairs). Each ring has an icon on top, the value
// under it, a thin track and, for gauge slots, a progress arc from 12 o'clock.
// Geometry is for 390 px and scales with the width.
module Rings {

    const ORBIT = 134;     // ring centre distance from the screen centre
    const RADIUS = 38;
    const SPREAD = 37;     // degrees between rows
    const ICON_DY = -30;   // icon top relative to the ring centre
    const VALUE_DY = 15;   // value centre relative to the ring centre
    const VALUE_SIZES = [24, 21, 18, 16];
    const TRACK = 0x2A2A2A;
    const TRACK_LOW = 0x262626;
    const VALUE_LOW = 0x8C8C8C;

    function centre(slot as Number, width as Number) as Array<Number> {
        var row = (slot - 1) / 2;
        var left = (slot - 1) % 2 == 0;
        var a = Math.toRadians((row - 1) * SPREAD);
        var c = width / 2;
        var orbit = ORBIT * width / 390.0;
        var dx = orbit * Math.cos(a);
        return [(left ? c - dx : c + dx).toNumber(), (c + orbit * Math.sin(a)).toNumber()];
    }

    function radius(width as Number) as Number {
        return RADIUS * width / 390;
    }

    // Slot (1-6) whose ring contains (x, y), or 0.
    function hit(x as Number, y as Number, width as Number) as Number {
        var r = radius(width);
        for (var slot = 1; slot <= 6; slot++) {
            var p = centre(slot, width);
            var dx = x - p[0];
            var dy = y - p[1];
            if (dx * dx + dy * dy <= r * r) {
                return slot;
            }
        }
        return 0;
    }

    // The largest value font whose text fits inside the ring.
    function valueFont(dc as Dc, text as String, width as Number, low as Boolean) as Graphics.VectorFont {
        var face = low ? "RobotoRegular" : "RobotoCondensedBold";
        var r = radius(width) - 2;
        var dy = (VALUE_DY + 9) * width / 390;
        var chord = 2 * Math.sqrt(r * r - dy * dy) - 4;
        var f = RoundText.font(face, VALUE_SIZES[0], width);
        for (var i = 1; i < VALUE_SIZES.size() && dc.getTextWidthInPixels(text, f) > chord; i++) {
            f = RoundText.font(face, VALUE_SIZES[i], width);
        }
        return f;
    }

    // ring: [icon, color, value, progress]; offset: always-on burn-in shift.
    function draw(dc as Dc, slot as Number, width as Number, offset as Array<Number>, ring as Array, low as Boolean) as Void {
        var p = centre(slot, width);
        var x = p[0] + offset[0];
        var y = p[1] + offset[1];
        var r = radius(width);
        var color = low ? dimmed(ring[1] as Number, 0.45) : ring[1] as Number;
        var progress = ring[3] as Float;
        dc.setPenWidth(low ? 2 : 4);
        dc.setColor(low ? TRACK_LOW : TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, r);
        if (progress > 0.005) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(x, y, r, Graphics.ARC_CLOCKWISE, 90, 90 - (360 * progress).toNumber());
        }
        dc.setPenWidth(1);
        var icon = ring[0] as BitmapResource;
        dc.drawBitmap2(x - icon.getWidth() / 2, y + ICON_DY * width / 390, icon, {:tintColor => color});
        var text = ring[2] as String;
        dc.setColor(low ? VALUE_LOW : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + VALUE_DY * width / 390, valueFont(dc, text, width, low), text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // A colour with its RGB channels scaled by f (0..1).
    function dimmed(color as Number, f as Float) as Number {
        var r = (((color >> 16) & 0xFF) * f).toNumber();
        var g = (((color >> 8) & 0xFF) * f).toNumber();
        var b = ((color & 0xFF) * f).toNumber();
        return (r << 16) | (g << 8) | b;
    }
}
