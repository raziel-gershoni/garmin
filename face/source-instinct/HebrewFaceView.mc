import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// The Instinct face, top to bottom: the Gregorian date, slots 1-2 and slot 4 in the column left
// of the subscreen, with slot 3 as a gauge in the subscreen; a grey band with the time and
// seconds; the full Hebrew date and the parasha (or holiday); slots 5-6. All six slots are
// swappable.
// Positions and fonts live in Layout.mc, Window.mc and common/source-instinct/DateBand.mc.
// In low power the seconds tick through onPartialUpdate until the watch reports the face over
// its power budget (BudgetDelegate); after that the time shows hours and minutes only while the
// watch is asleep.
class HebrewFaceView extends WatchUi.WatchFace {

    var partialUpdates = true;
    var _awake = true;
    var _iconFont as FontResource?;
    var _timeFont as FontResource?;
    var _band as BitmapResource?;
    var _windowX = 144;
    var _windowY = 31;
    var _windowR = 31;
    var _fg = Graphics.COLOR_WHITE;
    var _bg = Graphics.COLOR_BLACK;

    var _hebrewRd = -1;
    var _hebrewLine = null as Array?;
    var _parashaRd = -1;
    var _parashaLine = null as Array?;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _iconFont = WatchUi.loadResource(Rez.Fonts.Icons) as FontResource;
        _timeFont = WatchUi.loadResource(Rez.Fonts.Time) as FontResource;
        _band = WatchUi.loadResource(Rez.Drawables.Band) as BitmapResource;
        if (WatchUi has :getSubscreen) {
            var box = WatchUi.getSubscreen();
            if (box != null) {
                _windowR = box.width / 2;
                _windowX = box.x + _windowR;
                _windowY = box.y + box.height / 2;
            }
        }
    }

    function onUpdate(dc as Dc) as Void {
        var light = SettingsMenu.isLight();
        _fg = light ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
        _bg = light ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        dc.setColor(_fg, _bg);
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
                Slots.logComplications();
            }
            _hebrewLine = Layout.hebrewDate(dc, HebrewCalendar.fromFixed(hebrewRd));
            _hebrewRd = hebrewRd;
        }
        if (hebrewRd != _parashaRd || Parasha.changed) {
            var title = Parasha.titleFor(hebrewRd);
            _parashaLine = title == null ? null : Layout.parasha(dc, title);
            _parashaRd = hebrewRd;
            Parasha.changed = false;
        }

        DateBand.drawGregorian(dc, t);
        dc.setClip(0, DateBand.BAND_TOP, dc.getWidth(), Layout.BAND_HEIGHT);
        drawBand(dc);
        dc.clearClip();
        drawTime(dc, t.hour as Number, t.min as Number, _awake || partialUpdates ? t.sec as Number : null);
        drawDates(dc);
        drawSlots(dc, sun);
        drawWindow(dc, sun);
    }

    // Seconds only, over their own patch of the band (inside it, so the clip also cuts the band).
    function onPartialUpdate(dc as Dc) as Void {
        if (!partialUpdates) {
            return;
        }
        var box = Layout.secondsBox(dc, _timeFont as FontResource);
        dc.setClip(box[0], box[1], box[2], box[3]);
        drawBand(dc);
        drawSeconds(dc, System.getClockTime().sec);
        dc.clearClip();
    }

    // The band's grey. Its bitmap is the glance's taller band, so callers clip it to
    // Layout.BAND_HEIGHT rows or less.
    function drawBand(dc as Dc) as Void {
        if (_band != null) {
            dc.drawBitmap(0, DateBand.BAND_TOP, _band as BitmapResource);
        }
    }

    // The Hebrew date and the parasha under the band; the date drops to the middle of both lines'
    // space while no parasha is known.
    function drawDates(dc as Dc) as Void {
        var hebrew = _hebrewLine as Array;
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Layout.CENTER_X, (hebrew[2] as Number) + (_parashaLine == null ? Layout.ALONE_SHIFT : 0),
            hebrew[1], hebrew[0], Graphics.TEXT_JUSTIFY_CENTER);
        if (_parashaLine != null) {
            var p = _parashaLine as Array;
            dc.drawText(Layout.CENTER_X, p[2], p[1], p[0], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Slots 1-2 and 4 in the column and 5-6 along the bottom, with a transparent text background
    // so they never cut into their neighbours.
    function drawSlots(dc as Dc, sun as Array<Number>?) as Void {
        var types = [FaceSlots.typeOf(1), FaceSlots.typeOf(2), FaceSlots.typeOf(4), FaceSlots.typeOf(5), FaceSlots.typeOf(6)];
        var texts = [null, null, null, null, null] as Array<String?>;
        for (var i = 0; i < types.size(); i++) {
            texts[i] = types[i] == Slots.NONE ? null : Slots.value(types[i], sun);
            types[i] = Slots.resolve(types[i], sun);
        }
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        var pair = Layout.line(dc, Layout.PAIR_Y, texts[0], texts[1]);
        drawItem(dc, pair[0], types[0], texts[0]);
        drawItem(dc, pair[1], types[1], texts[1]);
        drawItem(dc, Layout.line(dc, Layout.SLOT4_Y, texts[2], null)[0], types[2], texts[2]);
        var bottom = Layout.bottomRow(dc, texts[3], texts[4]);
        drawItem(dc, bottom[0], types[3], texts[3]);
        drawItem(dc, bottom[1], types[4], texts[4]);
    }

    // Icon and value at a place from Layout ([x, y, font, iconY]; no icon when iconY is null);
    // nothing for an empty slot.
    function drawItem(dc as Dc, place as Array?, type as Number, text as String?) as Void {
        if (place == null || text == null) {
            return;
        }
        var x = place[0] as Number;
        if (place[3] != null) {
            dc.drawText(x, place[3], _iconFont as FontResource, Slots.ICONS[type], Graphics.TEXT_JUSTIFY_LEFT);
            x += Layout.ICON_W;
        }
        dc.drawText(x, place[1], place[2], text, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Outlined on the band. Hours follow the watch's 12/24-hour setting; 24-hour time keeps the
    // leading zero. Without seconds (sec null) the hours and minutes stay where they are.
    function drawTime(dc as Dc, hour as Number, min as Number, sec as Number?) as Void {
        var h24 = System.getDeviceSettings().is24Hour;
        var text = (h24 ? hour.format("%02d") : (hour % 12 == 0 ? 12 : hour % 12).toString()) + ":" + min.format("%02d");
        var font = _timeFont as FontResource;
        var right = Layout.timeRight(dc, font);
        if (sec == null) {
            right -= dc.getTextWidthInPixels(":00", font);
        } else {
            text += ":" + sec.format("%02d");
        }
        DateBand.drawOutlinedText(dc, right, Layout.TIME_Y, font, text, Graphics.TEXT_JUSTIFY_RIGHT, _fg, _bg);
    }

    function drawSeconds(dc as Dc, sec as Number) as Void {
        var font = _timeFont as FontResource;
        DateBand.drawOutlinedText(dc, Layout.timeRight(dc, font), Layout.TIME_Y, font, sec.format("%02d"),
            Graphics.TEXT_JUSTIFY_RIGHT, _fg, _bg);
    }

    // Slot 3 in the subscreen; an empty slot leaves it in the background colour.
    function drawWindow(dc as Dc, sun as Array<Number>?) as Void {
        var type = FaceSlots.typeOf(3);
        if (type != Slots.NONE) {
            Window.draw(dc, _windowX, _windowY, _windowR, Slots.resolve(type, sun), Slots.value(type, sun),
                Slots.progress(type, sun), _iconFont as FontResource, _fg, _bg);
        }
    }

    function onExitSleep() as Void {
        _awake = true;
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        _awake = false;
        WatchUi.requestUpdate();
    }
}
