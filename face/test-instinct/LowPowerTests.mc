import Toybox.Lang;
import Toybox.Test;

// Asleep, the face draws the seconds and onPartialUpdate redraws them; once the watch reports the
// face over its power budget, the time drops the seconds and onPartialUpdate draws nothing. Both
// paths run without error, and the delegate is what switches them off.
(:test)
function faceDrawsAsleepWithAndWithoutSeconds(logger as Logger) as Boolean {
    var dc = FaceTestSupport.screenDc();
    var view = new HebrewFaceView();
    view.onLayout(dc);
    view.onEnterSleep();
    view.onUpdate(dc);
    view.onPartialUpdate(dc);
    view.partialUpdates = false;
    view.onUpdate(dc);
    view.onPartialUpdate(dc);
    view.onExitSleep();
    view.onUpdate(dc);
    return !view.partialUpdates;
}
