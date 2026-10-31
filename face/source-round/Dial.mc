import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// The analog dial on the round screen: ticks (the current second's lit orange) and hands, awake
// and always-on.
// Lengths are for a 195 px radius (Venu 4 41 mm) and scale with r.
module Dial {

    const ACCENT = 0xFFAA00;
    // Hands: a short thick hour capsule and a long thin minute capsule, neither reaching the
    // centre, in see-through white (alpha HANDS_ALPHA, HANDS_ALPHA_LOW always-on) so the rings and
    // dates stay readable under them. [start, end] of the centre line as fractions of r (the
    // round ends reach half the width past them), then the width in px at r = 195. Each hand is
    // a thick line: the watch draws lines smooth with round ends, where filled polygons came out
    // fuzzy with faceted ends.
    const HOUR_HAND = [0.10, 0.56, 13.0];
    const MINUTE_HAND = [0.06, 0.90, 7.0];
    const HANDS_ALPHA = 0x70;
    const HANDS_ALPHA_LOW = 0x60;
    // The other season's hand (drawPhantom): the hour hand's shape filled in a barely visible grey
    // (the user's call), darker always-on.
    const PHANTOM_GREY = 0x20;
    const PHANTOM_GREY_LOW = 0x1A;
    // How far in from the edge the 5-second marks reach, round end included (lines get round
    // ends half the pen past their endpoints, measured in the simulator).
    const HOUR_MARK_IN = 18;
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

    // See-through white hands, dimmer always-on; the minute hand is drawn last, on top.
    function drawHands(dc as Dc, cx as Number, cy as Number, r as Number, hour as Number, min as Number,
                       low as Boolean) as Void {
        var ma = (min * Math.PI / 30).toFloat();
        drawCapsules(dc, cx, cy, handCapsules(r, hourAngle(hour, min), ma, handsColor(low)));
    }

    // The other season's hour hand, `shift` seconds on from the clock (summer time in winter) or
    // back (winter time in summer, shift negative; SummerTime): the hour hand's shape in a barely
    // visible grey, a ghost of the real one. The face draws it before the data, which stays on top
    // of it.
    function drawPhantom(dc as Dc, cx as Number, cy as Number, r as Number, hour as Number, min as Number,
                         shift as Number, low as Boolean) as Void {
        drawCapsules(dc, cx, cy, phantomCapsules(r, hour, min, shift, low));
    }

    // The other season's hand's capsule, as handCapsules: the hour hand's capsule in phantomColor;
    // none while shift is 0.
    function phantomCapsules(r as Number, hour as Number, min as Number, shift as Number, low as Boolean) as Array<Array> {
        if (shift == 0) {
            return [];
        }
        var s = r / 195.0;
        var a = hourAngle(hour, min + shift / 60);
        return [[a, HOUR_HAND[0] * r, HOUR_HAND[1] * r, HOUR_HAND[2] * s, phantomColor(low)]];
    }

    // The other season's hand's grey as 0xAARRGGBB, darker always-on.
    function phantomColor(low as Boolean) as Number {
        var v = low ? PHANTOM_GREY_LOW : PHANTOM_GREY;
        return Graphics.createColor(0xFF, v, v, v);
    }

    // The hour hand's clock angle (0 to 2 pi) at hour:min; min may run past 60 or below 0 (a later
    // or an earlier hour).
    function hourAngle(hour as Number, min as Number) as Float {
        return (((((hour % 12) * 60 + min) % 720 + 720) % 720) * Math.PI / 360).toFloat();
    }

    function drawCapsules(dc as Dc, cx as Number, cy as Number, parts as Array<Array>) as Void {
        for (var i = 0; i < parts.size(); i++) {
            var c = parts[i] as Array;
            capsule(dc, cx, cy, c[0], c[1], c[2], c[3], c[4]);
        }
    }

    // The hands' see-through white as 0xAARRGGBB: alpha HANDS_ALPHA awake, HANDS_ALPHA_LOW always-on.
    function handsColor(low as Boolean) as Number {
        return Graphics.createColor(low ? HANDS_ALPHA_LOW : HANDS_ALPHA, 255, 255, 255);
    }

    // The capsules to draw, in order, as [angle, from, to, width, color]: the hour hand, then the
    // minute hand. color is 0xAARRGGBB.
    function handCapsules(r as Number, ha as Float, ma as Float, color as Number) as Array<Array> {
        var s = r / 195.0;
        return [
            [ha, HOUR_HAND[0] * r, HOUR_HAND[1] * r, HOUR_HAND[2] * s, color],
            [ma, MINUTE_HAND[0] * r, MINUTE_HAND[1] * r, MINUTE_HAND[2] * s, color]
        ];
    }

    // A capsule along a clock angle (0 = 12 o'clock, clockwise): a line `width` px thick between
    // `from` and `to` px out from the centre, whose round ends reach half the width past them.
    // color is 0xAARRGGBB: setStroke blends it (setColor would ignore the alpha), and the next
    // setColor takes over again (checked in the simulator).
    function capsule(dc as Dc, cx as Number, cy as Number, angle as Float, from as Float, to as Float,
                     width as Float, color as Number) as Void {
        var ends = capsuleEnds(cx, cy, angle, from, to);
        dc.setColor(color & 0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        if (dc has :setStroke) {
            dc.setStroke(color);
        }
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
