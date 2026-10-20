import Toybox.Lang;
import Toybox.WatchUi;

// The face's initial view on the Instinct, with a delegate that hears about the power budget
// (no touch, so nothing else to handle).
module FaceViews {

    // The face and its delegate; configId (the Venu's editor settings) means nothing here.
    function initial(configId) as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new HebrewFaceView();
        return [view, new BudgetDelegate(view)] as [WatchUi.Views, WatchUi.InputDelegates];
    }

    // The on-watch settings: a list of widgets for each slot, and the background.
    function settings() as [WatchUi.Views, WatchUi.InputDelegates] or Null {
        return SettingsMenu.build();
    }
}

// Stops the once-a-second seconds in low power if the watch finds onPartialUpdate over budget, and
// asks for a full redraw so the last seconds drawn do not stay on screen (the watch may hold that
// redraw until the next minute).
class BudgetDelegate extends WatchUi.WatchFaceDelegate {

    var _view as HebrewFaceView;

    function initialize(view as HebrewFaceView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    function onPowerBudgetExceeded(powerInfo as WatchUi.WatchFacePowerInfo) as Void {
        Parasha.log("power budget exceeded: " + powerInfo.executionTimeAverage + " > " + powerInfo.executionTimeLimit);
        _view.partialUpdates = false;
        WatchUi.requestUpdate();
    }
}
