import Toybox.Lang;
import Toybox.WatchUi;

// The face's initial view on the Venu, with touch-and-hold on a ring opening its native view and,
// in the watch's own face editor, taps selecting a spot and the edited spot pulsing.
module FaceViews {

    function initial() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new HebrewFaceView();
        return [view, new RingPressDelegate(view)] as [WatchUi.Views, WatchUi.InputDelegates];
    }

    // None: the Venu's widgets are picked in the watch's own face editor (FaceSlots).
    function settings() as [WatchUi.Views, WatchUi.InputDelegates] or Null {
        return null;
    }
}
