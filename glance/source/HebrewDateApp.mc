import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

(:background, :glance)
class HebrewDateApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        HebrewDay.scheduleSync();
        return [new DetailView()];
    }

    (:glance)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        HebrewDay.scheduleSync();
        return [new HebrewGlanceView()];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new ParashaService()];
    }

    // The service writes the cache itself; this only refreshes the schedule and the screen.
    function onBackgroundData(data as Application.PersistableType) as Void {
        Parasha.changed = true;
        HebrewDay.scheduleSync();
        WatchUi.requestUpdate();
    }
}
