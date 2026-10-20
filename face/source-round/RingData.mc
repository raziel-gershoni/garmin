import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// How each widget type looks in a Venu subdial: its icon and colour (the battery's follow the
// charge), and which spots get a ring. The values and progress come from Slots.
module RingData {

    // Indexed by Slots.Type: none, HR, battery, steps, altitude, sunrise, sunset, Body Battery,
    // solar, notifications, calories, stress, floors, intensity minutes, temperature, high/low,
    // pulse ox, respiration, sleep score, pressure, recovery, VO2 max, next event, weekly run,
    // sun (unused: SUN takes the colour of the next sunrise or sunset).
    const COLORS = [0x000000, 0xFF4D5E, 0x4CD964, 0x3FA9F5, 0xB8C2CC, 0xFFC83D, 0xFF8A3D, 0x4FD8FF,
                    0xFFD000, 0xC79BFF, 0xFF7A45,
                    0xF5A623, 0x34C3A0, 0xFF6B9A, 0xFFA07A, 0xFFA07A, 0x7FA7FF, 0x7FE0D0, 0x9C8CFF,
                    0xB8C2CC, 0x8CD47E, 0xFF7AA2, 0x6FC3FF, 0x5AC8FA, 0x000000];
    const LOW_BATTERY = 20;
    const LOW_COLOR = 0xFF3B30;

    // Icon for a slot type; the battery icon follows the charge. Null for types without one
    // (Solar, which the Venu does not offer, and SUN, which shows the icon of the next sunrise or
    // sunset).
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
            case Slots.STRESS: return Rez.Drawables.IconStress;
            case Slots.FLOORS: return Rez.Drawables.IconFloors;
            case Slots.INTENSITY: return Rez.Drawables.IconIntensity;
            case Slots.TEMPERATURE: return Rez.Drawables.IconTemperature;
            case Slots.HIGH_LOW: return Rez.Drawables.IconHighLow;
            case Slots.PULSE_OX: return Rez.Drawables.IconPulseOx;
            case Slots.RESPIRATION: return Rez.Drawables.IconRespiration;
            case Slots.SLEEP_SCORE: return Rez.Drawables.IconSleep;
            case Slots.PRESSURE: return Rez.Drawables.IconPressure;
            case Slots.RECOVERY: return Rez.Drawables.IconRecovery;
            case Slots.VO2_MAX: return Rez.Drawables.IconVo2Max;
            case Slots.NEXT_EVENT: return Rez.Drawables.IconNextEvent;
            case Slots.RUN_WEEK: return Rez.Drawables.IconRunWeek;
        }
        return null;
    }

    // Gauges in the bottom row (places 3-4) and spot 5 get a ring, a track and a progress arc; the
    // top row has no rings, so a gauge there shows only icon and value, like the other types.
    function ringed(type as Number, place as Number) as Boolean {
        return Slots.isGauge(type) && place > 2;
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
