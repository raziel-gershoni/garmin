import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

(:background)
class HebrewFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        Parasha.scheduleSync(true);
        return FaceViews.initial();
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new ParashaService()];
    }

    // The service writes the cache itself; this only refreshes the schedule and the screen.
    function onBackgroundData(data as Application.PersistableType) as Void {
        Parasha.changed = true;
        Parasha.scheduleSync(false);
        WatchUi.requestUpdate();
    }

    function getSettingsView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] or Null {
        return FaceViews.settings();
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}
