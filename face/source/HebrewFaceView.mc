import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Layout A: Gregorian date / Hebrew day+month / Hebrew year at top left, analog clock in the
// round subscreen, a parasha (or holiday) line, then a 2x3 grid of swappable slots.
// Positions and font choices live in Layout.mc.
class HebrewFaceView extends WatchUi.WatchFace {

    var _iconFont as FontResource?;
    var _clockX = 144;
    var _clockY = 31;
    var _clockR = 31;

    var _hebrewRd = -1;
    var _dayMonth = "";
    var _year = "";
    var _parashaRd = -1;
    var _parasha = null as String?;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _iconFont = WatchUi.loadResource(Rez.Fonts.Icons) as FontResource;
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

        var now = Time.now();
        var t = Gregorian.info(now, Time.FORMAT_SHORT);
        var civilRd = HebrewCalendar.fixedFromGregorian(t.year as Number, t.month as Number, t.day as Number);
        var sun = SunTimes.today(civilRd, sunFromWatch());
        var secs = (t.hour as Number) * 3600 + (t.min as Number) * 60 + (t.sec as Number);
        var hebrewRd = civilRd + ((sun != null && secs >= sun[1]) ? 1 : 0);
        if (hebrewRd != _hebrewRd) {
            if (_hebrewRd == -1) {
                var stats = System.getSystemStats();
                System.println("face mem " + stats.usedMemory + "/" + stats.totalMemory + " sun " + sun);
            }
            var h = HebrewCalendar.fromFixed(hebrewRd);
            _dayMonth = HebrewFormat.dayMonth(h);
            _year = HebrewFormat.year(h);
            _hebrewRd = hebrewRd;
        }

        drawDates(dc, now);
        drawParasha(dc, hebrewRd);
        drawSlots(dc, sun);
        drawClock(dc, fg, bg, t.hour as Number, t.min as Number);
    }

    function drawDates(dc as Dc, now as Time.Moment) as Void {
        var m = Gregorian.info(now, Time.FORMAT_MEDIUM);
        var gregorian = m.day_of_week + " " + m.day + " " + m.month;
        dc.drawText(Layout.TEXT_RIGHT, Layout.gregorianY(dc, gregorian), Graphics.FONT_XTINY, gregorian, Graphics.TEXT_JUSTIFY_RIGHT);
        var dm = Layout.dayMonth(dc, _dayMonth);
        dc.drawText(Layout.TEXT_RIGHT, dm[1], dm[0], _dayMonth, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(Layout.TEXT_RIGHT, Layout.YEAR_Y, Graphics.FONT_XTINY, _year, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    function drawParasha(dc as Dc, hebrewRd as Number) as Void {
        dc.setPenWidth(1);
        dc.drawLine(4, Layout.RULE_1_Y, 172, Layout.RULE_1_Y);
        dc.drawLine(4, Layout.RULE_2_Y, 172, Layout.RULE_2_Y);
        if (hebrewRd != _parashaRd || Parasha.changed) {
            _parasha = Parasha.titleFor(hebrewRd);
            _parashaRd = hebrewRd;
            Parasha.changed = false;
        }
        var title = _parasha;
        if (title != null) {
            var p = Layout.parasha(dc, title);
            dc.drawText(Layout.CENTER_X, p[2], p[1], p[0], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawSlots(dc as Dc, sun as Array<Number>?) as Void {
        for (var slot = 1; slot <= Slots.SLOT_COUNT; slot++) {
            var type = Slots.typeOf(slot);
            if (type == Slots.NONE) {
                continue;
            }
            var text = Slots.value(type, sun);
            var place = Layout.slot(dc, slot, text);
            var iconY = Layout.GRID_TOP + ((slot - 1) / 2) * Layout.ROW_HEIGHT + 6;
            dc.drawText(place[0], iconY, _iconFont as FontResource, Slots.ICONS[type], Graphics.TEXT_JUSTIFY_LEFT);
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

    // The watch's own sunrise/sunset (GPS-based), when it publishes them.
    function sunFromWatch() as Array? {
        if (!(Toybox has :Complications)) {
            return null;
        }
        return [complicationValue(Complications.COMPLICATION_TYPE_SUNRISE),
                complicationValue(Complications.COMPLICATION_TYPE_SUNSET)];
    }

    function complicationValue(type as Complications.Type) as Number? {
        try {
            var value = Complications.getComplication(new Complications.Id(type)).value;
            return value instanceof Number ? value : null;
        } catch (e) {
            return null;
        }
    }

    function onExitSleep() as Void {
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        WatchUi.requestUpdate();
    }
}
