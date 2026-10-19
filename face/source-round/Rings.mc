import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// Subdials at places 1-5: slots 1 and 3 on the left, 2 and 4 on the right (rows top to bottom,
// between the rim lines), and the sun place above 6 (SUN), which shows the next sunrise or
// sunset. Each has an icon on top and the value under it; gauges (RingData.isGauge) and the sun
// ring also get a ring, a track with a progress arc from 12 o'clock, since a circle means nothing
// around a heart rate or an altitude. Geometry is for 390 px and scales with the width; the icon
// and value offsets and the value sizes scale with each place's radius. Rings end inside the hour
// marks (18 px), which the seconds dot also runs along.
module Rings {

    const SUN = 5;
    const PLACES = 5;
    const ORBIT = 124;            // slot ring centre distance from the screen centre
    const ROW_ANGLES = [29, -23]; // degrees above 3 (or 9) o'clock of the top and bottom rows
    const RADIUS = 48;
    const SUN_DY = 76;            // sun ring centre below the screen centre
    const SUN_RADIUS = 42;
    const PEN = 7;
    const PEN_LOW = 3;
    const ICON_DY = -0.76;        // icon top relative to the ring centre, in radii
    const VALUE_DY = 0.36;        // value centre relative to the ring centre, in radii
    const VALUE_SIZES = [30, 27, 24, 21, 18];
    const TRACK = 0x2A2A2A;
    const TRACK_LOW = 0x262626;
    const VALUE_LOW = 0x8C8C8C;

    function centre(place as Number, width as Number) as Array<Number> {
        var c = width / 2;
        if (place == SUN) {
            return [c, c + SUN_DY * width / 390];
        }
        var left = (place - 1) % 2 == 0;
        var a = Math.toRadians(ROW_ANGLES[(place - 1) / 2]);
        var orbit = ORBIT * width / 390.0;
        var dx = orbit * Math.cos(a);
        return [(left ? c - dx : c + dx).toNumber(), (c - orbit * Math.sin(a)).toNumber()];
    }

    function radius(place as Number, width as Number) as Number {
        return (place == SUN ? SUN_RADIUS : RADIUS) * width / 390;
    }

    // Place (1-5) whose ring contains (x, y), or 0.
    function hit(x as Number, y as Number, width as Number) as Number {
        for (var place = 1; place <= PLACES; place++) {
            var p = centre(place, width);
            var r = radius(place, width);
            var dx = x - p[0];
            var dy = y - p[1];
            if (dx * dx + dy * dy <= r * r) {
                return place;
            }
        }
        return 0;
    }

    // The largest value font whose text fits inside the place at the value line's lower edge:
    // inside the ring's stroke when it has one (ringed), else inside its circle.
    function valueFont(dc as Dc, text as String, place as Number, width as Number, low as Boolean,
                       ringed as Boolean) as Graphics.VectorFont {
        var face = low ? "RobotoRegular" : "RobotoCondensedBold";
        var r = radius(place, width);
        var k = r.toFloat() / (RADIUS * width / 390);
        var dy = r * VALUE_DY + 11 * k * width / 390;
        var inner = ringed ? r - PEN * width / 390 : r;
        var chord = 2 * Math.sqrt(inner * inner - dy * dy) - 4;
        var f = RoundText.font(face, (VALUE_SIZES[0] * k).toNumber(), width);
        for (var i = 1; i < VALUE_SIZES.size() && dc.getTextWidthInPixels(text, f) > chord; i++) {
            f = RoundText.font(face, (VALUE_SIZES[i] * k).toNumber(), width);
        }
        return f;
    }

    // ring: [icon, color, value, progress, ringed]; offset: always-on burn-in shift.
    function draw(dc as Dc, place as Number, width as Number, offset as Array<Number>, ring as Array, low as Boolean) as Void {
        var p = centre(place, width);
        var x = p[0] + offset[0];
        var y = p[1] + offset[1];
        var r = radius(place, width);
        var color = low ? dimmed(ring[1] as Number, 0.45) : ring[1] as Number;
        var progress = ring[3] as Float;
        var ringed = ring[4] as Boolean;
        if (ringed) {
            dc.setPenWidth((low ? PEN_LOW : PEN) * width / 390);
            dc.setColor(low ? TRACK_LOW : TRACK, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(x, y, r);
            if (progress > 0.005) {
                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                if (isFull(progress)) {
                    dc.drawCircle(x, y, r);
                } else {
                    dc.drawArc(x, y, r, Graphics.ARC_CLOCKWISE, 90, 90 - (360 * progress).toNumber());
                }
            }
            dc.setPenWidth(1);
        }
        var icon = ring[0] as BitmapResource;
        dc.drawBitmap2(x - icon.getWidth() / 2, y + (ICON_DY * r).toNumber(), icon, {:tintColor => color});
        var text = ring[2] as String;
        dc.setColor(low ? VALUE_LOW : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + (VALUE_DY * r).toNumber(), valueFont(dc, text, place, width, low, ringed), text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // A full arc has the same start and end angle, which drawArc leaves ambiguous; draw a circle.
    function isFull(progress as Float) as Boolean {
        return progress >= 0.999;
    }

    // A colour with its RGB channels scaled by f (0..1).
    function dimmed(color as Number, f as Float) as Number {
        var r = (((color >> 16) & 0xFF) * f).toNumber();
        var g = (((color >> 8) & 0xFF) * f).toNumber();
        var b = ((color & 0xFF) * f).toNumber();
        return (r << 16) | (g << 8) | b;
    }
}
