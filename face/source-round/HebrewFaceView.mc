import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Venu face (stub until the round layout lands).
class HebrewFaceView extends WatchUi.WatchFace {

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
    }
}
