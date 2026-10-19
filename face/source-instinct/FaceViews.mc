import Toybox.Lang;
import Toybox.WatchUi;

// The face's initial view on the Instinct (no touch, so no delegate).
module FaceViews {

    function initial() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new HebrewFaceView()];
    }
}
