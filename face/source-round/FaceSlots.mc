// How many of the swappable slots this face shows (Slots holds all six settings): four places,
// slot N at place N (1-2 the top row, 3-4 the bottom); the sun ring above 6 always shows the next
// sunrise or sunset. The defaults (also in resources-round/settings/properties.xml) keep the plain
// values on top and the gauges, which get rings there, below.
module FaceSlots {
    const COUNT = 4;
    const DEFAULTS = [Slots.HEART_RATE, Slots.ALTITUDE, Slots.BATTERY, Slots.STEPS, Slots.SUNRISE, Slots.SUNSET];
}
