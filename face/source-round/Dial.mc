import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// The analog dial on the round screen: ticks, hands and hub, awake and always-on.
// Lengths are for a 195 px radius (Venu 4 41 mm) and scale with r.
module Dial {

    const ACCENT = 0xFFAA00;
    const HANDS_LOW = 0xC8C8C8;
    // Always-on burn-in shift, one step per minute, at most 2 px from centre.
    const SHIFTS = [[0, 0], [2, 0], [2, 2], [0, 2], [-2, 2], [-2, 0], [-2, -2], [0, -2], [2, -2]];

    function burnInOffset(minute as Number) as Array<Number> {
        return SHIFTS[minute % SHIFTS.size()] as Array<Number>;
    }

    // Awake: 60 grey minute ticks and 12 white hour marks. Always-on: dim hour marks only, the
    // quarters a little brighter.
    function drawTicks(dc as Dc, cx as Number, cy as Number, r as Number, low as Boolean) as Void {
        var s = r / 195.0;
        for (var i = 0; i < 60; i += (low ? 5 : 1)) {
            var hour = i % 5 == 0;
            if (low) {
                dc.setColor(i % 15 == 0 ? 0x8A8A8A : 0x5A5A5A, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(i % 15 == 0 ? 3 : 2);
            } else {
                dc.setColor(hour ? Graphics.COLOR_WHITE : 0x666666, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(hour ? 4 : 2);
            }
            var a = i * Math.PI / 30;
            var r0 = r - (hour ? 18 : 9) * s;
            var r1 = r - 3 * s;
            dc.drawLine((cx + Math.sin(a) * r0).toNumber(), (cy - Math.cos(a) * r0).toNumber(),
                        (cx + Math.sin(a) * r1).toNumber(), (cy - Math.cos(a) * r1).toNumber());
        }
        dc.setPenWidth(1);
    }

    // Awake: white hands over a black outline, an orange seconds hand (sec != null) and an orange
    // hub. Always-on: hollow light-grey hands over black, a ring for the hub, no seconds.
    function drawHands(dc as Dc, cx as Number, cy as Number, r as Number, hour as Number, min as Number,
                       sec as Number?, low as Boolean) as Void {
        var s = r / 195.0;
        var ha = (((hour % 12) * 60 + min) * Math.PI / 360).toFloat();
        var ma = (min * Math.PI / 30).toFloat();
        var hl = r * 0.52;
        var ml = r * 0.80;
        fill(dc, cx, cy, ha, hl + 3, 18 * s, 18 * s, Graphics.COLOR_BLACK);
        fill(dc, cx, cy, ma, ml + 3, 14 * s, 18 * s, Graphics.COLOR_BLACK);
        if (low) {
            outline(dc, cx, cy, ha, hl, 12 * s, 18 * s);
            outline(dc, cx, cy, ma, ml, 9 * s, 18 * s);
            dc.setColor(HANDS_LOW, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawCircle(cx, cy, (6 * s).toNumber());
            dc.setPenWidth(1);
            return;
        }
        fill(dc, cx, cy, ha, hl, 12 * s, 18 * s, Graphics.COLOR_WHITE);
        fill(dc, cx, cy, ma, ml, 8 * s, 18 * s, Graphics.COLOR_WHITE);
        if (sec != null) {
            fill(dc, cx, cy, (sec * Math.PI / 30).toFloat(), r * 0.86, 3 * s, 24 * s, ACCENT);
        }
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (9 * s).toNumber());
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (3 * s).toNumber());
    }

    // Tapered hand from tail to tip along a clock angle (0 = 12 o'clock, clockwise): the
    // corners [tail left, tail right, tip right, tip left].
    function points(cx as Numeric, cy as Numeric, angle as Float, length as Float, width as Float, tail as Float) as Array<Array> {
        var sn = Math.sin(angle);
        var cs = Math.cos(angle);
        return [
            [cx - cs * width / 2 - sn * tail, cy - sn * width / 2 + cs * tail],
            [cx + cs * width / 2 - sn * tail, cy + sn * width / 2 + cs * tail],
            [cx + cs * width / 4 + sn * length, cy + sn * width / 4 - cs * length],
            [cx - cs * width / 4 + sn * length, cy - sn * width / 4 - cs * length]
        ];
    }

    function fill(dc as Dc, cx as Number, cy as Number, angle as Float, length as Float, width as Float,
                  tail as Float, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(points(cx, cy, angle, length, width, tail));
    }

    function outline(dc as Dc, cx as Number, cy as Number, angle as Float, length as Float, width as Float,
                     tail as Float) as Void {
        var p = points(cx, cy, angle, length, width, tail);
        dc.setColor(HANDS_LOW, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var i = 0; i < 4; i++) {
            var a = p[i];
            var b = p[(i + 1) % 4];
            dc.drawLine((a[0] as Float).toNumber(), (a[1] as Float).toNumber(), (b[0] as Float).toNumber(), (b[1] as Float).toNumber());
        }
        dc.setPenWidth(1);
    }
}
