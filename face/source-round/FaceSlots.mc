import Toybox.Application;
import Toybox.Lang;

// How many of the swappable slots this face shows (four places, slot N at place N: 1-2 the top row, 3-4 the bottom; the sun ring above 6 always shows the next sunrise or sunset), their defaults (also in
// resources-round/settings/properties.xml), and the user's choice for each, saved as Slots.Type numbers
// in the SlotN properties by the settings menu.
module FaceSlots {
    const COUNT = 4;
    const DEFAULTS = [Slots.HEART_RATE, Slots.ALTITUDE, Slots.BATTERY, Slots.STEPS, Slots.SUNRISE, Slots.SUNSET];

    // slot is 1-based.
    function typeOf(slot as Number) as Number {
        var v = Properties.getValue("Slot" + slot);
        return (v instanceof Number && v >= 0 && v < Slots.TYPE_COUNT) ? v : DEFAULTS[slot - 1];
    }

    function setType(slot as Number, type as Number) as Void {
        Properties.setValue("Slot" + slot, type);
    }
}
