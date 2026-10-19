import Toybox.Lang;
import Toybox.Test;

// Gauge progress: Body Battery as a fraction of 100 with a given reading winning over the sensor
// history, readings out of range clamped, battery always within 0..1, and no gauge for other types.
(:test)
function slotProgressClampsAndOverrides(logger as Logger) as Boolean {
    var battery = Slots.progress(Slots.BATTERY, null);
    return Slots.progress(Slots.BODY_BATTERY, 50) == 0.5
        && Slots.progress(Slots.BODY_BATTERY, 150) == 1.0
        && Slots.progress(Slots.BODY_BATTERY, -5) == 0.0
        && battery >= 0.0 && battery <= 1.0
        && Slots.progress(Slots.HEART_RATE, null) == -1.0
        && Slots.progress(Slots.ALTITUDE, null) == -1.0
        && Slots.progress(Slots.SUNRISE, null) == -1.0;
}
