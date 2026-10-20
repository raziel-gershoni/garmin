import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// What a ring shows for each slot type on the Venu: value text, progress, icon and colour.
// Values come from the watch's own complications where they exist, else from Slots.
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

    // Gauges in the bottom row (places 3-4) get a ring, a track and a progress arc; the top row
    // has no rings, so a gauge there shows only icon and value, like the other types.
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
