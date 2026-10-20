import Toybox.Complications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Touch-and-hold on a ring opens the matching native view (faces get no plain taps).
class RingPressDelegate extends WatchUi.WatchFaceDelegate {

    function initialize() {
        WatchFaceDelegate.initialize();
    }

    function onPress(event as WatchUi.ClickEvent) as Boolean {
        var xy = event.getCoordinates();
        var ct = target(xy[0], xy[1], System.getDeviceSettings().screenWidth);
        if (ct < 0) {
            return false;
        }
        try {
            Complications.exitTo(new Complications.Id(ct as Complications.Type));
            return true;
        } catch (e) {
            return false;
        }
    }

    // Complication to open for a press at (x, y), or -1: the slot shown at that place (slot N at
    // place N), or on the sun ring the next sunrise or sunset.
    static function target(x as Number, y as Number, width as Number) as Number {
        var place = Rings.hit(x, y, width);
        if (place == Rings.SUN) {
            var day = Today.at(Time.now(), WatchSun.get());
            var t = day[0] as Gregorian.Info;
            var now = (t.hour as Number) * 3600 + (t.min as Number) * 60 + (t.sec as Number);
            return RingData.complicationType(RingData.nextSun(day[2] as Array<Number>?, now)[0] as Number);
        }
        if (place == 0) {
            return -1;
        }
        return RingData.complicationType(Slots.typeOf(place));
    }
}
