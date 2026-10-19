import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
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

    // AMOLED watches (the Venu) have no solar charging, so Solar is not offered there.
    function available(type as Number) as Boolean {
        return type != SOLAR || !System.getDeviceSettings().requiresBurnInProtection;
    }

    // The next type offered after type, wrapping round to Empty.
    function next(type as Number) as Number {
        var n = (type + 1) % TYPE_COUNT;
        while (!available(n)) {
            n = (n + 1) % TYPE_COUNT;
        }
        return n;
    }

    // Text for a slot type; "--" when the watch has no reading.
    function value(type as Number, sun as Array<Number>?) as String {
        var v = null;
        switch (type) {
            case HEART_RATE:
                v = heartRate();
                break;
            case BATTERY:
                return battery();
            case STEPS:
                v = ActivityMonitor.getInfo().steps;
                break;
            case ALTITUDE:
                v = altitude();
                return v == null ? "--" : whole(v) + "m";
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
        return v == null ? "--" : whole(v);
    }

    // A reading as a whole number, rounded to the nearest like the watch's own screens (format("%d")
    // would cut 2.8 days down to 2).
    function whole(v as Numeric) as String {
        return (v instanceof Float || v instanceof Double ? Math.round(v) : v).toNumber().format("%d");
    }

    // 0..1 for gauge types (battery, Body Battery, steps against the daily goal); -1 otherwise
    // or without a reading. bodyBattery overrides the sensor history's reading when not null.
    function progress(type as Number, bodyBattery as Numeric?) as Float {
        if (type == BATTERY) {
            return clamp(System.getSystemStats().battery / 100.0);
        }
        if (type == BODY_BATTERY) {
            var v = bodyBattery != null ? bodyBattery : latestSample(:getBodyBatteryHistory);
            return v == null ? -1.0 : clamp(v.toFloat() / 100.0);
        }
        if (type == STEPS) {
            var info = ActivityMonitor.getInfo();
            var goal = info.stepGoal;
            return (info.steps == null || goal == null || goal <= 0) ? -1.0 : clamp((info.steps as Number).toFloat() / goal);
        }
        return -1.0;
    }

    function clamp(p as Float) as Float {
        return p < 0.0 ? 0.0 : (p > 1.0 ? 1.0 : p);
    }

    // Battery as days left where the watch estimates them (like the native faces), else percent.
    function battery() as String {
        var stats = System.getSystemStats();
        if ((stats has :batteryInDays) && stats.batteryInDays != null) {
            return whole(stats.batteryInDays) + "d";
        }
        return whole(stats.battery) + "%";
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
