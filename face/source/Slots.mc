import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.WatchUi;

// The six swappable data slots: what each can show, the user's choice, and the current value.
module Slots {

    enum Type {
        NONE, HEART_RATE, BATTERY, STEPS, ALTITUDE, SUNRISE, SUNSET,
        BODY_BATTERY, SOLAR, NOTIFICATIONS, CALORIES
    }
    const TYPE_COUNT = 11;
    const SLOT_COUNT = 6;
    const DEFAULTS = [HEART_RATE, BATTERY, STEPS, ALTITUDE, SUNRISE, SUNSET];

    // Glyphs in the Icons font (tools/make_assets.py), indexed by Type.
    const ICONS = ["", "H", "B", "S", "A", "R", "T", "Y", "O", "N", "C"];

    function names() as Array<ResourceId> {
        return [Rez.Strings.SlotNone, Rez.Strings.SlotHeartRate, Rez.Strings.SlotBattery, Rez.Strings.SlotSteps,
                Rez.Strings.SlotAltitude, Rez.Strings.SlotSunrise, Rez.Strings.SlotSunset, Rez.Strings.SlotBodyBattery,
                Rez.Strings.SlotSolar, Rez.Strings.SlotNotifications, Rez.Strings.SlotCalories];
    }

    // slot is 1-based.
    function typeOf(slot as Number) as Number {
        var v = Properties.getValue("Slot" + slot);
        return (v instanceof Number && v >= 0 && v < TYPE_COUNT) ? v : DEFAULTS[slot - 1];
    }

    function setType(slot as Number, type as Number) as Void {
        Properties.setValue("Slot" + slot, type);
    }

    // Text for a slot type; "--" when the watch has no reading.
    function value(type as Number, sun as Array<Number>?) as String {
        var v = null;
        switch (type) {
            case HEART_RATE:
                v = heartRate();
                break;
            case BATTERY:
                return System.getSystemStats().battery.format("%d") + "%";
            case STEPS:
                v = ActivityMonitor.getInfo().steps;
                break;
            case ALTITUDE:
                v = altitude();
                return v == null ? "--" : v.format("%d") + "m";
            case SUNRISE:
                return SunTimes.format(sun == null ? null : sun[0]);
            case SUNSET:
                return SunTimes.format(sun == null ? null : sun[1]);
            case BODY_BATTERY:
                v = latestSample(:getBodyBatteryHistory);
                break;
            case SOLAR:
                v = System.getSystemStats().solarIntensity;
                return (v == null || v < 0) ? "--" : v.format("%d") + "%";
            case NOTIFICATIONS:
                v = System.getDeviceSettings().notificationCount;
                break;
            case CALORIES:
                v = ActivityMonitor.getInfo().calories;
                break;
            default:
                return "";
        }
        return v == null ? "--" : v.format("%d");
    }

    function heartRate() as Number? {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) {
            return info.currentHeartRate;
        }
        if (ActivityMonitor has :getHeartRateHistory) {
            var sample = ActivityMonitor.getHeartRateHistory(1, true).next();
            if (sample != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                return sample.heartRate;
            }
        }
        return null;
    }

    function altitude() as Numeric? {
        var info = Activity.getActivityInfo();
        if (info != null && info.altitude != null) {
            return info.altitude;
        }
        return latestSample(:getElevationHistory);
    }

    function latestSample(history as Symbol) as Numeric? {
        if (!(Toybox has :SensorHistory) || !(SensorHistory has history)) {
            return null;
        }
        var getter = new Lang.Method(SensorHistory, history);
        var sample = getter.invoke({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST}).next();
        return sample == null ? null : sample.data;
    }
}
