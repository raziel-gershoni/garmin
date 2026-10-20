import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.WatchUi;

// The widgets a slot can show on either watch: what each is, where its reading comes from (the
// watch's own complication first, then the face's own sources), how it reads and whether it is a
// gauge. Which widget each slot holds is up to each watch's FaceSlots.
module Slots {

    // Saved settings hold these numbers, so new types only ever go at the end.
    enum Type {
        NONE, HEART_RATE, BATTERY, STEPS, ALTITUDE, SUNRISE, SUNSET,
        BODY_BATTERY, SOLAR, NOTIFICATIONS, CALORIES,
        STRESS, FLOORS, INTENSITY, TEMPERATURE, HIGH_LOW, PULSE_OX, RESPIRATION, SLEEP_SCORE,
        PRESSURE, RECOVERY, VO2_MAX, NEXT_EVENT, RUN_WEEK, SUN
    }
    const TYPE_COUNT = 25;
    const SLOT_COUNT = 6;

    // The order lists offer the types in (the Instinct's slot lists, the Venu's editor), Empty last.
    const ORDER = [HEART_RATE, BATTERY, BODY_BATTERY, STRESS, STEPS, FLOORS, INTENSITY, CALORIES,
                   SLEEP_SCORE, PULSE_OX, RESPIRATION, RECOVERY, VO2_MAX, RUN_WEEK, ALTITUDE, PRESSURE,
                   TEMPERATURE, HIGH_LOW, SUN, SUNRISE, SUNSET, SOLAR, NOTIFICATIONS, NEXT_EVENT, NONE];

    // Glyphs in the Instinct's Icons font (tools/make_assets.py), indexed by Type. SUN draws the
    // glyph of the next sunrise or sunset (resolve).
    const ICONS = ["", "H", "B", "S", "A", "R", "T", "Y", "O", "N", "C",
                   "X", "F", "I", "E", "L", "P", "W", "Z", "G", "K", "V", "D", "U", ""];

    // The watch's complication behind each type (Complications.Type numbers: heart rate 18,
    // battery 1, steps 2, altitude 15, sunrise 13, sunset 14, Body Battery 23, solar input 37,
    // notifications 17, calories 3, stress 22, floors 4, intensity minutes 5, temperature 38,
    // high/low 39, pulse ox 35, respiration 36, sleep score 42, sea-level pressure 16, recovery
    // time 21, VO2 max run 24, calendar events 12, weekly run distance 19), or -1. It is also
    // what a hold on a Venu ring opens.
    const COMPLICATIONS = [-1, 18, 1, 2, 15, 13, 14, 23, 37, 17, 3,
                           22, 4, 5, 38, 39, 35, 36, 42, 16, 21, 24, 12, 19, -1];

    // Types with a natural 0..1 progress (progress).
    const GAUGES = [BATTERY, STEPS, BODY_BATTERY, STRESS, FLOORS, INTENSITY, SLEEP_SCORE, SUN];

    function names() as Array<ResourceId> {
        return [Rez.Strings.SlotNone, Rez.Strings.SlotHeartRate, Rez.Strings.SlotBattery, Rez.Strings.SlotSteps,
                Rez.Strings.SlotAltitude, Rez.Strings.SlotSunrise, Rez.Strings.SlotSunset, Rez.Strings.SlotBodyBattery,
                Rez.Strings.SlotSolar, Rez.Strings.SlotNotifications, Rez.Strings.SlotCalories,
                Rez.Strings.SlotStress, Rez.Strings.SlotFloors, Rez.Strings.SlotIntensity, Rez.Strings.SlotTemperature,
                Rez.Strings.SlotHighLow, Rez.Strings.SlotPulseOx, Rez.Strings.SlotRespiration, Rez.Strings.SlotSleepScore,
                Rez.Strings.SlotPressure, Rez.Strings.SlotRecovery, Rez.Strings.SlotVo2Max, Rez.Strings.SlotNextEvent,
                Rez.Strings.SlotRunWeek, Rez.Strings.SlotSun];
    }

    function complicationType(type as Number) as Number {
        return COMPLICATIONS[type] as Number;
    }

    // The type a complication type stands for, or NONE for one the face does not show.
    function fromComplication(ct as Number?) as Number {
        if (ct == null || ct < 0) {
            return NONE;
        }
        var t = COMPLICATIONS.indexOf(ct);
        return t < 0 ? NONE : t;
    }

    function isGauge(type as Number) as Boolean {
        return GAUGES.indexOf(type) >= 0;
    }

    // Whether this watch can show type: Solar only with solar charging (AMOLED watches have none),
    // the newer types only where the watch publishes their complication, the rest always (they
    // have the face's own sources).
    function available(type as Number) as Boolean {
        if (type == SOLAR) {
            return !System.getDeviceSettings().requiresBurnInProtection;
        }
        return type < STRESS || type == SUN || complication(type) != null;
    }

    // ORDER without the types this watch cannot show.
    function offered() as Array<Number> {
        var list = [];
        for (var i = 0; i < ORDER.size(); i++) {
            if (available(ORDER[i])) {
                list.add(ORDER[i]);
            }
        }
        return list;
    }

    // The watch's complication behind type, or null where it has none.
    function complication(type as Number) as Complications.Complication? {
        var ct = COMPLICATIONS[type] as Number;
        if (ct < 0 || !(Toybox has :Complications)) {
            return null;
        }
        try {
            return Complications.getComplication(new Complications.Id(ct as Complications.Type));
        } catch (e) {
            Parasha.log("no complication " + ct + ": " + e.getErrorMessage());
            return null;
        }
    }

    // SUN shows the next sunrise or sunset; every other type is itself.
    function resolve(type as Number, sun as Array<Number>?) as Number {
        return type == SUN ? nextSun(sun, now())[0] as Number : type;
    }

    // Seconds since local midnight.
    function now() as Number {
        var c = System.getClockTime();
        return c.hour * 3600 + c.min * 60 + c.sec;
    }

    // Text for a slot type; "--" when the watch has no reading.
    function value(type as Number, sun as Array<Number>?) as String {
        switch (type) {
            case NONE:
                return "";
            case SUN:
                return value(resolve(type, sun), sun);
            case SUNRISE:
                return SunTimes.format(sun == null ? null : sun[0]);
            case SUNSET:
                return SunTimes.format(sun == null ? null : sun[1]);
            case BATTERY:
                return battery();
            case SOLAR:
                var s = System.getSystemStats().solarIntensity;
                return (s == null || s < 0) ? "--" : s.format("%d") + "%";
        }
        var settings = System.getDeviceSettings();
        var units = type == TEMPERATURE ? settings.temperatureUnits : settings.distanceUnits;
        return format(type, reading(type), units == System.UNIT_STATUTE);
    }

    // The reading behind type: the watch's complication first, then the face's own source for the
    // original types; null without one.
    function reading(type as Number) {
        var c = complication(type);
        if (c != null && c.value != null) {
            return c.value;
        }
        switch (type) {
            case HEART_RATE:
                return heartRate();
            case STEPS:
                return ActivityMonitor.getInfo().steps;
            case ALTITUDE:
                return altitude();
            case BODY_BATTERY:
                return latestSample(:getBodyBatteryHistory);
            case NOTIFICATIONS:
                return System.getDeviceSettings().notificationCount;
            case CALORIES:
                return ActivityMonitor.getInfo().calories;
        }
        return null;
    }

    // How a reading reads: whole numbers rounded to the nearest, with a unit where the native faces
    // show one; the watch's own strings as they are; "--" without a reading. imperial: °F for
    // temperature, miles for distance.
    function format(type as Number, v, imperial as Boolean) as String {
        if (v == null) {
            return "--";
        }
        if (v instanceof String) {
            return v;
        }
        if (!(v instanceof Number || v instanceof Float || v instanceof Long || v instanceof Double)) {
            return "--";
        }
        switch (type) {
            case ALTITUDE:
                return whole(v) + "m";
            case TEMPERATURE:
                return whole(imperial ? v * 9.0 / 5.0 + 32 : v) + "°";
            case PULSE_OX:
                return whole(v) + "%";
            case PRESSURE:
                return whole(v / 100.0);
            case RECOVERY:
                return whole(v / 60.0) + "h";
            case RUN_WEEK:
                var d = v / (imperial ? 1609.344 : 1000.0);
                return (d < 99.95 ? d.format("%.1f") : whole(d)) + (imperial ? "mi" : "km");
        }
        return whole(v);
    }

    // A reading as a whole number, rounded to the nearest like the watch's own screens (format("%d")
    // would cut 2.8 days down to 2).
    function whole(v as Numeric) as String {
        return (v instanceof Float || v instanceof Double ? Math.round(v) : v).toNumber().format("%d");
    }

    // 0..1 for gauges: battery, Body Battery, stress and sleep score out of 100; steps, floors and
    // this week's intensity minutes against the watch's goals; SUN the day or night so far. -1 for
    // the other types or without a reading.
    function progress(type as Number, sun as Array<Number>?) as Float {
        switch (type) {
            case BATTERY:
                return clamp(System.getSystemStats().battery / 100.0);
            case BODY_BATTERY:
                return ratio(reading(type), 100);
            case STRESS:
                return ratio(reading(type), 100);
            case SLEEP_SCORE:
                return ratio(reading(type), 100);
            case STEPS:
                return ratio(reading(type), ActivityMonitor.getInfo().stepGoal);
            case FLOORS:
                return ratio(reading(type), ActivityMonitor.getInfo().floorsClimbedGoal);
            case INTENSITY:
                return ratio(reading(type), ActivityMonitor.getInfo().activeMinutesWeekGoal);
            case SUN:
                return nextSun(sun, now())[1] as Float;
        }
        return -1.0;
    }

    // v / goal within 0..1, or -1 without a numeric reading or a goal.
    function ratio(v, goal) as Float {
        if (!(v instanceof Number || v instanceof Float || v instanceof Long || v instanceof Double)
                || goal == null || goal <= 0) {
            return -1.0;
        }
        return clamp(v.toFloat() / goal);
    }

    function clamp(p as Float) as Float {
        return p < 0.0 ? 0.0 : (p > 1.0 ? 1.0 : p);
    }

    // [SUNSET or SUNRISE, progress] for the next of the two, with how far the day (sunrise to
    // sunset) or the night (sunset to the next sunrise, taken at today's times) has run. sun is
    // [sunrise, sunset] in seconds after midnight, either way round past midnight; without it,
    // sunrise and an empty arc.
    function nextSun(sun as Array<Number>?, now as Number) as Array {
        if (sun == null) {
            return [SUNRISE, 0.0];
        }
        var day = (sun[1] - sun[0] + 86400) % 86400;
        var sinceRise = (now - sun[0] + 86400) % 86400;
        if (sinceRise < day) {
            return [SUNSET, sinceRise.toFloat() / day];
        }
        return [SUNRISE, (sinceRise - day).toFloat() / (86400 - day)];
    }

    // The next type offered after type, wrapping round to Empty. (Removed in Task 2.)
    function next(type as Number) as Number {
        var n = (type + 1) % TYPE_COUNT;
        while (!available(n)) {
            n = (n + 1) % TYPE_COUNT;
        }
        return n;
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
