import Toybox.Lang;
import Toybox.WatchUi;

// The face's initial view on the Instinct, with a delegate that hears about the power budget
// (no touch, so nothing else to handle).
module FaceViews {

    function initial() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new HebrewFaceView();
        return [view, new BudgetDelegate(view)] as [WatchUi.Views, WatchUi.InputDelegates];
    }
}

// Stops the once-a-second seconds in low power if the watch finds onPartialUpdate over budget.
class BudgetDelegate extends WatchUi.WatchFaceDelegate {

    var _view as HebrewFaceView;

    function initialize(view as HebrewFaceView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    function onPowerBudgetExceeded(powerInfo as WatchUi.WatchFacePowerInfo) as Void {
        Parasha.log("power budget exceeded: " + powerInfo.executionTimeAverage + " > " + powerInfo.executionTimeLimit);
        _view.partialUpdates = false;
    }
}
