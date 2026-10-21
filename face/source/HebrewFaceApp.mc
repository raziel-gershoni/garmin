import Toybox.Application;
import Toybox.Application.WatchFaceConfig;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

(:background)
class HebrewFaceApp extends Application.AppBase {

    // The face settings the watch launched the face with (onStart's :configId; the Venu's editor
    // passes one), or null for the active ones.
    var _configId as WatchFaceConfig.Id? = null;

    function initialize() {
        AppBase.initialize();
    }

    // Keeps the settings the watch asks the face to launch with, for the initial view.
    function onStart(state as Dictionary?) as Void {
        _configId = state == null ? null : state[:configId] as WatchFaceConfig.Id?;
        if (state != null && state[:launchedFromWatchFaceSettingsEditor] == true) {
            Parasha.log("face launched by the editor");
        }
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        Parasha.scheduleSync(true);
        return FaceViews.initial(_configId);
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
