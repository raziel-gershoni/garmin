import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Asleep, the face draws the seconds and onPartialUpdate redraws them. When the watch reports the
// face over its power budget, the delegate from FaceViews.initial() switches partial updates off;
// after that the time drops the seconds and onPartialUpdate draws nothing. All of it runs without
// error.
(:test)
function powerBudgetSwitchesSecondsOff(logger as Logger) as Boolean {
    var dc = FaceTestSupport.screenDc();
    var views = FaceViews.initial(null) as Array;
    var view = views[0] as HebrewFaceView;
    var delegate = views[1] as BudgetDelegate;
    view.onLayout(dc);
    view.onEnterSleep();
    view.onUpdate(dc);
    view.onPartialUpdate(dc);
    if (!view.partialUpdates) {
        return false;
    }
    delegate.onPowerBudgetExceeded(new WatchUi.WatchFacePowerInfo());
    view.onUpdate(dc);
    view.onPartialUpdate(dc);
    view.onExitSleep();
    view.onUpdate(dc);
    return !view.partialUpdates;
}
