import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Venu face: analog dial, the full Hebrew date along the top rim, the parasha (or holiday) along
// the bottom rim, the Gregorian date in Hebrew under 12, four ring subdials, the next sunrise or
// sunset above 6 and an orange seconds pointer on the rim while awake. Always-on draws the same
// layout thin and dim, without seconds, shifted a few pixels each minute against burn-in.
class HebrewFaceView extends WatchUi.WatchFace {

    var _asleep = false;
    var _forcedLow = null as Boolean?;
    var _icons = {} as Dictionary<ResourceId, BitmapResource>;
    var _lineRd = -1;
    var _lineLow = false;
    var _dateLine = null as Array?;
    var _parashaLine = null as Array?;
    var _loggedMemory = false;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var r = w / 2;
        var low = lowPower();
        var day = Today.at(Time.now(), WatchSun.get());
        var t = day[0] as Gregorian.Info;
        var sun = day[2] as Array<Number>?;
        var off = low ? Dial.burnInOffset(t.min as Number) : [0, 0];
        var cx = r + off[0];
        var cy = r + off[1];

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setAntiAlias(true);
        Dial.drawTicks(dc, cx, cy, r, low);
        refreshLines(dc, day[3] as Number, w);
        dc.setColor(low ? 0x9A9A9A : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        RoundText.drawRim(dc, cx, cy, w, _dateLine as Array, true);
        if (_parashaLine != null) {
            dc.setColor(low ? 0x9A7A30 : Dial.ACCENT, Graphics.COLOR_TRANSPARENT);
            RoundText.drawRim(dc, cx, cy, w, _parashaLine as Array, false);
        }
        RoundText.drawGregorian(dc, t, cx, cy, w, low);
        drawRings(dc, sun, (t.hour as Number) * 3600 + (t.min as Number) * 60 + (t.sec as Number), w, off, low);
        if (!low) {
            Dial.drawSecondsPointer(dc, cx, cy, r, t.sec as Number);
        }
        Dial.drawHands(dc, cx, cy, r, t.hour as Number, t.min as Number, low);

        if (!_loggedMemory) {
            var stats = System.getSystemStats();
            Parasha.log("face mem " + stats.usedMemory + "/" + stats.totalMemory + " sun " + sun);
            _loggedMemory = true;
        }
    }

    // Always-on: anything but high power where the display mode exists (API 5), or the sleep
    // callbacks (onEnterSleep) when the watch is asleep.
    function lowPower() as Boolean {
        if (_forcedLow != null) {
            return _forcedLow as Boolean;
        }
        if (System has :getDisplayMode) {
            return _asleep || System.getDisplayMode() != System.DISPLAY_MODE_HIGH_POWER;
        }
        return _asleep;
    }

    // Test hook: force awake (false) or always-on (true); null follows the watch.
    function setLowPower(low as Boolean?) as Void {
        _forcedLow = low;
    }

    // Fits the rim lines once per Hebrew day and display mode (the fonts differ), and again
    // when a background sync changes the parasha cache.
    function refreshLines(dc as Dc, hebrewRd as Number, width as Number) as Void {
        var low = lowPower();
        if (hebrewRd == _lineRd && low == _lineLow && !Parasha.changed) {
            return;
        }
        _dateLine = RoundText.fitRim(dc, RoundText.dateOptions(HebrewCalendar.fromFixed(hebrewRd)), width, low);
        var title = Parasha.titleFor(hebrewRd);
        _parashaLine = title == null ? null : RoundText.fitRim(dc, RoundText.titleOptions(title), width, low);
        _lineRd = hebrewRd;
        _lineLow = low;
        Parasha.changed = false;
    }

    // The slot rings, then the sun ring with the next sunrise or sunset (now: seconds after
    // midnight).
    function drawRings(dc as Dc, sun as Array<Number>?, now as Number, w as Number, off as Array<Number>, low as Boolean) as Void {
        for (var slot = 1; slot <= FaceSlots.COUNT; slot++) {
            var type = Slots.typeOf(slot);
            var iconId = RingData.icon(type);
            if (type == Slots.NONE || iconId == null) {
                continue;
            }
            Rings.draw(dc, slot, w, off,
                [bitmap(iconId as ResourceId), RingData.color(type), RingData.value(type, sun), RingData.progress(type)], low);
        }
        var next = RingData.nextSun(sun, now);
        var type = next[0] as Number;
        Rings.draw(dc, Rings.SUN, w, off,
            [bitmap(RingData.icon(type) as ResourceId), RingData.color(type), RingData.value(type, sun), next[1]], low);
    }

    function bitmap(id as ResourceId) as BitmapResource {
        var b = _icons[id];
        if (b == null) {
            b = WatchUi.loadResource(id) as BitmapResource;
            _icons[id] = b;
        }
        return b;
    }

    function onEnterSleep() as Void {
        // Only burn-in-protected (AMOLED) screens dim into always-on; MIP screens never do.
        _asleep = System.getDeviceSettings().requiresBurnInProtection;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _asleep = false;
        WatchUi.requestUpdate();
    }
}
