import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Gregorian date and two slots left of the round subscreen (analog clock), then a grey band with
// the full Hebrew date and the parasha (or holiday), then a 2x2 grid of slots. All six slots are
// swappable. Positions and font choices live in Layout.mc and common/source/DateBand.mc.
class HebrewFaceView extends WatchUi.WatchFace {

    var _iconFont as FontResource?;
    var _band as BitmapResource?;
    var _clockX = 144;
    var _clockY = 31;
    var _clockR = 31;

    var _hebrewRd = -1;
    var _hebrewLine = null as Array?;
    var _parashaRd = -1;
    var _parashaLine = null as Array?;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _iconFont = WatchUi.loadResource(Rez.Fonts.Icons) as FontResource;
        _band = WatchUi.loadResource(Rez.Drawables.Band) as BitmapResource;
        if (WatchUi has :getSubscreen) {
            var box = WatchUi.getSubscreen();
            if (box != null) {
                _clockR = box.width / 2;
                _clockX = box.x + _clockR;
                _clockY = box.y + box.height / 2;
            }
        }
    }

    function onUpdate(dc as Dc) as Void {
        var light = SettingsMenu.isLight();
        var fg = light ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
        var bg = light ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        dc.setColor(fg, bg);
        dc.clear();

        var day = Today.at(Time.now(), WatchSun.get());
        var t = day[0] as Gregorian.Info;
        var sun = day[2] as Array<Number>?;
        var hebrewRd = day[3] as Number;
        if (hebrewRd != _hebrewRd) {
            if (_hebrewRd == -1) {
                var stats = System.getSystemStats();
                Parasha.log("face mem " + stats.usedMemory + "/" + stats.totalMemory + " sun " + sun + " phone "
                    + System.getDeviceSettings().phoneConnected + " cached " + (Storage.getValue(Parasha.ITEMS_KEY) != null));
            }
            _hebrewLine = DateBand.hebrewDate(dc, HebrewCalendar.fromFixed(hebrewRd));
            _hebrewRd = hebrewRd;
        }
        if (hebrewRd != _parashaRd || Parasha.changed) {
            var title = Parasha.titleFor(hebrewRd);
            _parashaLine = title == null ? null : DateBand.parasha(dc, title);
            _parashaRd = hebrewRd;
            Parasha.changed = false;
        }

        DateBand.drawGregorian(dc, t);
        DateBand.drawBand(dc, _band, _hebrewLine as Array, _parashaLine, fg, bg);
        drawSlots(dc, fg, sun);
        drawClock(dc, fg, bg, t.hour as Number, t.min as Number);
    }

    // Transparent text background: a filled one would cut into the band above the grid.
    function drawSlots(dc as Dc, fg as Number, sun as Array<Number>?) as Void {
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        for (var slot = 1; slot <= Slots.SLOT_COUNT; slot++) {
            var type = Slots.typeOf(slot);
            if (type == Slots.NONE) {
                continue;
            }
            var text = Slots.value(type, sun);
            var place = Layout.slot(dc, slot, text);
            dc.drawText(place[0], place[4], _iconFont as FontResource, Slots.ICONS[type], Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(place[0] + Layout.ICON_W, place[1], place[2], text, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // Filled disk in the foreground colour with the dial drawn in the background colour.
    function drawClock(dc as Dc, fg as Number, bg as Number, hour as Number, min as Number) as Void {
        dc.setColor(fg, bg);
        dc.fillCircle(_clockX, _clockY, _clockR);
        dc.setColor(bg, fg);
        for (var i = 0; i < 12; i++) {
            var quarter = i % 3 == 0;
            dc.setPenWidth(quarter ? 3 : 1);
            drawRadial(dc, i * Math.PI / 6, _clockR - (quarter ? 9 : 6), _clockR - 2);
        }
        dc.setPenWidth(5);
        drawRadial(dc, ((hour % 12) * 60 + min) * Math.PI / 360, 0, _clockR * 50 / 100);
        dc.setPenWidth(3);
        drawRadial(dc, min * Math.PI / 30, 0, _clockR * 80 / 100);
        dc.fillCircle(_clockX, _clockY, 4);
        dc.setColor(fg, bg);
        dc.fillCircle(_clockX, _clockY, 1);
        dc.setPenWidth(1);
    }

    // Line along a clock angle (0 = 12 o'clock, clockwise) between two radii.
    function drawRadial(dc as Dc, angle as Numeric, r0 as Number, r1 as Number) as Void {
        var s = Math.sin(angle);
        var c = Math.cos(angle);
        dc.drawLine(_clockX + (s * r0).toNumber(), _clockY - (c * r0).toNumber(),
                    _clockX + (s * r1).toNumber(), _clockY - (c * r1).toNumber());
    }

    function onExitSleep() as Void {
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        WatchUi.requestUpdate();
    }
}
