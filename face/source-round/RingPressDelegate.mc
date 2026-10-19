import Toybox.Complications;
import Toybox.Lang;
import Toybox.System;
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

    // Complication to open for a press at (x, y), or -1.
    static function target(x as Number, y as Number, width as Number) as Number {
        var slot = Rings.hit(x, y, width);
        return slot == 0 ? -1 : RingData.complicationType(Slots.typeOf(slot));
    }
}
