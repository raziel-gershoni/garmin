import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// The analog dial on the round screen: ticks, hands and the seconds pointer, awake and always-on.
// Lengths are for a 195 px radius (Venu 4 41 mm) and scale with r.
module Dial {

    const ACCENT = 0xFFAA00;
    const HANDS_LOW = 0x7A7A7A;   // always-on hands, a step dimmer than the brighter hour marks
    // Hands after the Venu's own numbered face: a short thick solid hour capsule and a long
    // hollow minute capsule, neither reaching the centre. [start, end] as fractions of r, then the
    // width in px at r = 195; the minute hand's wall is MINUTE_WALL px. Each hand is one polygon
    // with its round ends built in (ARC_STEPS segments per end), over a black outline.
    const HOUR_HAND = [0.10, 0.56, 13.0];
    const MINUTE_HAND = [0.06, 0.90, 9.0];
    const MINUTE_WALL = 2.5;
    const OUTLINE = 2.0;
    const ARC_STEPS = 6;
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

    // White hands awake, dim grey always-on; the minute hand is drawn last, on top.
    function drawHands(dc as Dc, cx as Number, cy as Number, r as Number, hour as Number, min as Number,
                       low as Boolean) as Void {
        var s = r / 195.0;
        var color = low ? HANDS_LOW : Graphics.COLOR_WHITE;
        var o = (OUTLINE * s).toFloat();
        var ha = (((hour % 12) * 60 + min) * Math.PI / 360).toFloat();
        var ma = (min * Math.PI / 30).toFloat();
        capsule(dc, cx, cy, ha, HOUR_HAND[0] * r - o, HOUR_HAND[1] * r + o, HOUR_HAND[2] * s + 2 * o, Graphics.COLOR_BLACK);
        capsule(dc, cx, cy, ha, HOUR_HAND[0] * r, HOUR_HAND[1] * r, HOUR_HAND[2] * s, color);
        capsule(dc, cx, cy, ma, MINUTE_HAND[0] * r - o, MINUTE_HAND[1] * r + o, MINUTE_HAND[2] * s + 2 * o, Graphics.COLOR_BLACK);
        capsule(dc, cx, cy, ma, MINUTE_HAND[0] * r, MINUTE_HAND[1] * r, MINUTE_HAND[2] * s, color);
        var wall = MINUTE_WALL * s;
        capsule(dc, cx, cy, ma, MINUTE_HAND[0] * r + wall, MINUTE_HAND[1] * r - wall, MINUTE_HAND[2] * s - 2 * wall,
            Graphics.COLOR_BLACK);
    }

    // The seconds as an orange pointer running round the rim, awake only.
    function drawSecondsPointer(dc as Dc, cx as Number, cy as Number, r as Number, sec as Number) as Void {
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(secondsPointer(cx, cy, r, sec));
    }

    // A small triangle at the rim pointing in at the second's tick: [left, right, tip].
    function secondsPointer(cx as Numeric, cy as Numeric, r as Number, sec as Number) as Array<Array> {
        var s = r / 195.0;
        var a = (sec * Math.PI / 30).toFloat();
        var outer = r - 1 * s;
        var inner = r - 15 * s;
        var half = 5 * s;
        return [at(cx, cy, a, outer, -half), at(cx, cy, a, outer, half), at(cx, cy, a, inner, 0)];
    }

    function capsule(dc as Dc, cx as Number, cy as Number, angle as Float, from as Float, to as Float,
                     width as Float, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(capsulePoints(cx, cy, angle, from, to, width));
    }

    // Outline of a capsule along a clock angle (0 = 12 o'clock, clockwise), from `from` to `to`
    // pixels out from the centre, width wide: round the far end from the hand's left side to its
    // right, then round the near end back.
    function capsulePoints(cx as Numeric, cy as Numeric, angle as Float, from as Float, to as Float,
                           width as Float) as Array<Array> {
        var half = width / 2;
        var points = [];
        for (var i = 0; i <= ARC_STEPS; i++) {
            var t = Math.PI * i / ARC_STEPS;
            points.add(at(cx, cy, angle, to + half * Math.sin(t), -half * Math.cos(t)));
        }
        for (var i = 0; i <= ARC_STEPS; i++) {
            var t = Math.PI * i / ARC_STEPS;
            points.add(at(cx, cy, angle, from - half * Math.sin(t), half * Math.cos(t)));
        }
        return points;
    }

    // The point `along` pixels out from the centre along a clock angle and `across` pixels to the
    // right of that line.
    function at(cx as Numeric, cy as Numeric, angle as Float, along as Numeric, across as Numeric) as Array {
        var sn = Math.sin(angle);
        var cs = Math.cos(angle);
        return [cx + sn * along + cs * across, cy - cs * along + sn * across];
    }
}
