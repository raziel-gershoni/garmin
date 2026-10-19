import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Venu detail view (stub until the round layout lands).
class DetailView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
    }
}
