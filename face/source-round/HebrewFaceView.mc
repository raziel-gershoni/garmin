import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Venu face: analog dial, the full Hebrew date along the top rim, the parasha (or holiday) along
// the bottom rim, the Gregorian date in Hebrew under 12 and six ring subdials. Always-on draws the
// same layout thin and dim, shifted a few pixels each minute against burn-in.
class HebrewFaceView extends WatchUi.WatchFace {

    const GREGORIAN_DY = -107;   // under 12, relative to the centre at 390 px

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
        drawGregorian(dc, t, cx, cy + GREGORIAN_DY * w / 390, w, low);
        drawRings(dc, sun, w, off, low);
        Dial.drawHands(dc, cx, cy, r, t.hour as Number, t.min as Number, low ? null : t.sec as Number, low);

        if (!_loggedMemory) {
            var stats = System.getSystemStats();
            Parasha.log("face mem " + stats.usedMemory + "/" + stats.totalMemory + " sun " + sun);
            _loggedMemory = true;
        }
    }

    // Always-on: the display mode where available (API 5), else the sleep callbacks.
    function lowPower() as Boolean {
        if (_forcedLow != null) {
            return _forcedLow as Boolean;
        }
        if (System has :getDisplayMode) {
            return System.getDisplayMode() == System.DISPLAY_MODE_LOW_POWER;
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

    // "ב׳ 19.10": Hebrew weekday letter, day.month in Roboto.
    function drawGregorian(dc as Dc, t as Gregorian.Info, cx as Number, y as Number, w as Number, low as Boolean) as Void {
        dc.setColor(low ? 0x7A7A7A : 0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        RoundText.drawPair(dc, cx, y,
            HebrewFormat.weekday(t.day_of_week as Number), RoundText.font(RoundText.REGULAR, 28, w),
            t.day + "." + t.month, RoundText.font(low ? "RobotoRegular" : "RobotoCondensedBold", 30, w),
            8 * w / 390);
    }

    function drawRings(dc as Dc, sun as Array<Number>?, w as Number, off as Array<Number>, low as Boolean) as Void {
        for (var slot = 1; slot <= Slots.SLOT_COUNT; slot++) {
            var type = Slots.typeOf(slot);
            var iconId = RingData.icon(type);
            if (type == Slots.NONE || iconId == null) {
                continue;
            }
            Rings.draw(dc, slot, w, off,
                [bitmap(iconId as ResourceId), RingData.color(type), RingData.value(type, sun), RingData.progress(type)], low);
        }
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
        _asleep = System.getDeviceSettings().requiresBurnInProtection;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _asleep = false;
        WatchUi.requestUpdate();
    }
}
