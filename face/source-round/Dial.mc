import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// The analog dial on the round screen: ticks (the current second's lit orange) and hands, awake
// and always-on.
// Lengths are for a 195 px radius (Venu 4 41 mm) and scale with r.
module Dial {

    const ACCENT = 0xFFAA00;
    const HANDS_LOW = 0x7A7A7A;   // always-on hands, a step dimmer than the brighter hour marks
    // Hands after the Venu's own numbered face: a short thick solid hour capsule and a long
    // hollow minute capsule, neither reaching the centre. [start, end] of the centre line as
    // fractions of r (the round ends reach half the width past them), then the width in px at
    // r = 195; the minute hand's wall is MINUTE_WALL px. Each hand is a thick line over a wider
    // black one: the watch draws lines smooth with round ends, where filled polygons came out
    // fuzzy with faceted ends.
    const HOUR_HAND = [0.10, 0.56, 13.0];
    const MINUTE_HAND = [0.06, 0.90, 9.0];
    const MINUTE_WALL = 2.5;
    // How far in from the edge the 5-second marks reach, round end included (lines get round
    // ends half the pen past their endpoints, measured in the simulator).
    const HOUR_MARK_IN = 18;
    const OUTLINE = 2.0;
    // Always-on burn-in shift, one step per minute, at most 2 px from centre.
    const SHIFTS = [[0, 0], [2, 0], [2, 2], [0, 2], [-2, 2], [-2, 0], [-2, -2], [0, -2], [2, -2]];

    function burnInOffset(minute as Number) as Array<Number> {
        return SHIFTS[minute % SHIFTS.size()] as Array<Number>;
    }

    // Awake: 60 grey minute ticks and 12 white hour marks, the tick at the current second (sec)
    // lit orange, so the seconds run round the dial on the ticks themselves. Always-on: dim hour
    // marks only, the quarters a little brighter, no seconds.
    function drawTicks(dc as Dc, cx as Number, cy as Number, r as Number, low as Boolean, sec as Number?) as Void {
        for (var i = 0; i < 60; i += (low ? 5 : 1)) {
            dc.setColor(tickColor(i, low, sec), Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(tickPen(i, low));
            var ends = tickEnds(cx, cy, r, i, low);
            dc.drawLine(ends[0][0], ends[0][1], ends[1][0], ends[1][1]);
        }
        dc.setPenWidth(1);
    }

    function tickColor(i as Number, low as Boolean, sec as Number?) as Number {
        if (low) {
            return i % 15 == 0 ? 0x8A8A8A : 0x5A5A5A;
        }
        if (i == sec) {
            return ACCENT;
        }
        return i % 5 == 0 ? Graphics.COLOR_WHITE : 0x666666;
    }

    function tickPen(i as Number, low as Boolean) as Number {
        if (low) {
            return i % 15 == 0 ? 3 : 2;
        }
        return i % 5 == 0 ? 4 : 2;
    }

    // [inner end, outer end] of the line for the tick at second i: minute ticks 9 to 3 px in from
    // the edge, 5-second marks from HOUR_MARK_IN (round end included) to 3 px.
    function tickEnds(cx as Numeric, cy as Numeric, r as Number, i as Number, low as Boolean) as Array<Array> {
        var s = r / 195.0;
        var a = (i * Math.PI / 30).toFloat();
        var inner = i % 5 == 0 ? r - HOUR_MARK_IN * s + tickPen(i, low) / 2.0 : r - 9 * s;
        return [at(cx, cy, a, inner, 0), at(cx, cy, a, r - 3 * s, 0)];
    }

    // White hands awake, dim grey always-on; the minute hand is drawn last, on top.
    function drawHands(dc as Dc, cx as Number, cy as Number, r as Number, hour as Number, min as Number,
                       low as Boolean) as Void {
        var ha = (((hour % 12) * 60 + min) * Math.PI / 360).toFloat();
        var ma = (min * Math.PI / 30).toFloat();
        var parts = handCapsules(r, ha, ma, low ? HANDS_LOW : Graphics.COLOR_WHITE);
        for (var i = 0; i < parts.size(); i++) {
            var c = parts[i] as Array;
            capsule(dc, cx, cy, c[0], c[1], c[2], c[3], c[4]);
        }
    }

    // The capsules to draw, in order, as [angle, from, to, width, color]: each hand's outline,
    // then the hand, then the minute hand's hollow. They share each hand's centre line and differ
    // only in width, so the outline and the walls are even all the way round.
    function handCapsules(r as Number, ha as Float, ma as Float, color as Number) as Array<Array> {
        var s = r / 195.0;
        var o = OUTLINE * s;
        var hFrom = HOUR_HAND[0] * r;
        var hTo = HOUR_HAND[1] * r;
        var mFrom = MINUTE_HAND[0] * r;
        var mTo = MINUTE_HAND[1] * r;
        return [
            [ha, hFrom, hTo, HOUR_HAND[2] * s + 2 * o, Graphics.COLOR_BLACK],
            [ha, hFrom, hTo, HOUR_HAND[2] * s, color],
            [ma, mFrom, mTo, MINUTE_HAND[2] * s + 2 * o, Graphics.COLOR_BLACK],
            [ma, mFrom, mTo, MINUTE_HAND[2] * s, color],
            [ma, mFrom, mTo, (MINUTE_HAND[2] - 2 * MINUTE_WALL) * s, Graphics.COLOR_BLACK]
        ];
    }

    // A capsule along a clock angle (0 = 12 o'clock, clockwise): a line `width` px thick between
    // `from` and `to` px out from the centre, whose round ends reach half the width past them.
    function capsule(dc as Dc, cx as Number, cy as Number, angle as Float, from as Float, to as Float,
                     width as Float, color as Number) as Void {
        var ends = capsuleEnds(cx, cy, angle, from, to);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(Math.round(width).toNumber());
        dc.drawLine(ends[0][0], ends[0][1], ends[1][0], ends[1][1]);
        dc.setPenWidth(1);
    }

    function capsuleEnds(cx as Numeric, cy as Numeric, angle as Float, from as Float, to as Float) as Array<Array> {
        return [at(cx, cy, angle, from, 0), at(cx, cy, angle, to, 0)];
    }

    // The point `along` pixels out from the centre along a clock angle and `across` pixels to the
    // right of that line.
    function at(cx as Numeric, cy as Numeric, angle as Float, along as Numeric, across as Numeric) as Array {
        var sn = Math.sin(angle);
        var cs = Math.cos(angle);
        return [cx + sn * along + cs * across, cy - cs * along + sn * across];
    }
}
