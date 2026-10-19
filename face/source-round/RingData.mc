import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// What a ring shows for each slot type on the Venu: value text, progress, icon and colour.
// Values come from the watch's own complications where they exist, else from Slots.
module RingData {

    // Indexed by Slots.Type: none, HR, battery, steps, altitude, sunrise, sunset, Body Battery,
    // solar, notifications, calories.
    const COLORS = [0x000000, 0xFF4D5E, 0x4CD964, 0x3FA9F5, 0xB8C2CC, 0xFFC83D, 0xFF8A3D, 0x4FD8FF,
                    0xFFD000, 0xC79BFF, 0xFF7A45];
    const LOW_BATTERY = 20;
    const LOW_COLOR = 0xFF3B30;

    // The native complication behind a slot type, or -1. Also what a press on the ring opens.
    function complicationType(type as Number) as Number {
        switch (type) {
            case Slots.HEART_RATE: return Complications.COMPLICATION_TYPE_HEART_RATE as Number;
            case Slots.BATTERY: return Complications.COMPLICATION_TYPE_BATTERY as Number;
            case Slots.STEPS: return Complications.COMPLICATION_TYPE_STEPS as Number;
            case Slots.ALTITUDE: return Complications.COMPLICATION_TYPE_ALTITUDE as Number;
            case Slots.SUNRISE: return Complications.COMPLICATION_TYPE_SUNRISE as Number;
            case Slots.SUNSET: return Complications.COMPLICATION_TYPE_SUNSET as Number;
            case Slots.BODY_BATTERY: return Complications.COMPLICATION_TYPE_BODY_BATTERY as Number;
            case Slots.NOTIFICATIONS: return Complications.COMPLICATION_TYPE_NOTIFICATION_COUNT as Number;
            case Slots.CALORIES: return Complications.COMPLICATION_TYPE_CALORIES as Number;
        }
        return -1;
    }

    function complicationValue(type as Number) {
        var ct = complicationType(type);
        if (ct < 0 || !(Toybox has :Complications)) {
            return null;
        }
        try {
            return Complications.getComplication(new Complications.Id(ct as Complications.Type)).value;
        } catch (e) {
            return null;
        }
    }

    // Ring text; "--" when the watch has no reading. Sunrise/sunset come from the view's sun
    // times, which already prefer the watch's own.
    function value(type as Number, sun as Array<Number>?) as String {
        if (type != Slots.SUNRISE && type != Slots.SUNSET) {
            var v = complicationValue(type);
            if (v instanceof Number || v instanceof Float || v instanceof Long || v instanceof Double) {
                var n = v.toNumber();
                if (type == Slots.BATTERY) {
                    return n.format("%d") + "%";
                }
                if (type == Slots.ALTITUDE) {
                    return n.format("%d") + "m";
                }
                return n.format("%d");
            }
        }
        return Slots.value(type, sun);
    }

    // 0..1 for gauge types (battery, Body Battery, steps against the daily goal); -1 otherwise
    // or without a reading.
    function progress(type as Number) as Float {
        if (type == Slots.BATTERY) {
            return clamp(System.getSystemStats().battery / 100.0);
        }
        if (type == Slots.BODY_BATTERY) {
            var v = complicationValue(type);
            if (!(v instanceof Number)) {
                v = Slots.latestSample(:getBodyBatteryHistory);
            }
            return v == null ? -1.0 : clamp(v.toFloat() / 100.0);
        }
        if (type == Slots.STEPS) {
            var info = ActivityMonitor.getInfo();
            var goal = info.stepGoal;
            return (info.steps == null || goal == null || goal <= 0) ? -1.0 : clamp((info.steps as Number).toFloat() / goal);
        }
        return -1.0;
    }

    function clamp(p as Float) as Float {
        return p < 0.0 ? 0.0 : (p > 1.0 ? 1.0 : p);
    }

    // Icon for a slot type; the battery icon follows the charge. Null for types without one
    // (Solar, which the Venu does not offer).
    function icon(type as Number) as ResourceId? {
        switch (type) {
            case Slots.HEART_RATE: return Rez.Drawables.IconHeart;
            case Slots.BATTERY: return batteryIcon(System.getSystemStats().battery);
            case Slots.STEPS: return Rez.Drawables.IconSteps;
            case Slots.ALTITUDE: return Rez.Drawables.IconAltitude;
            case Slots.SUNRISE: return Rez.Drawables.IconSunrise;
            case Slots.SUNSET: return Rez.Drawables.IconSunset;
            case Slots.BODY_BATTERY: return Rez.Drawables.IconBodyBattery;
            case Slots.NOTIFICATIONS: return Rez.Drawables.IconNotifications;
            case Slots.CALORIES: return Rez.Drawables.IconCalories;
        }
        return null;
    }

    function color(type as Number) as Number {
        return type == Slots.BATTERY ? batteryColor(System.getSystemStats().battery) : COLORS[type] as Number;
    }

    function batteryIcon(level as Float) as ResourceId {
        if (level >= 95) {
            return Rez.Drawables.IconBattery;
        }
        if (level >= 65) {
            return Rez.Drawables.IconBattery80;
        }
        return level >= 35 ? Rez.Drawables.IconBattery50 : Rez.Drawables.IconBattery20;
    }

    function batteryColor(level as Float) as Number {
        return level <= LOW_BATTERY ? LOW_COLOR : COLORS[Slots.BATTERY] as Number;
    }
}
