import Toybox.Application.WatchFaceConfig;
import Toybox.Lang;

// The Venu's five spots: subdials 1-4 (slot N at place N, 1-2 the top row, 3-4 the bottom) and
// spot 5, the ring above 6. The user picks each spot's widget in the watch's own face editor
// (resources-round/configs/watchface.xml, with the same defaults as DEFAULTS); Sunrise or Sunset in
// spot 5 shows whichever comes next (Slots.SUN), as the native faces' sunrise/sunset does.
module FaceSlots {
    const COUNT = 5;
    const DEFAULTS = [Slots.HEART_RATE, Slots.ALTITUDE, Slots.BATTERY, Slots.STEPS, Slots.SUN];

    // Test hook: the spots' types, or null to follow the editor.
    var forced as Array<Number>? = null;
    // The editor settings to read: the ones the watch launched the face with or last edited, null
    // for the active ones.
    var configId as WatchFaceConfig.Id? = null;
    var _types as Array<Number>? = null;

    // slot is 1-based.
    function typeOf(slot as Number) as Number {
        if (forced != null) {
            return (forced as Array<Number>)[slot - 1];
        }
        if (_types == null) {
            load(configId);
        }
        return (_types as Array<Number>)[slot - 1];
    }

    // Reads the editor's choices for configuration id (null: the active one), and logs what it
    // found, which shows whether the watch offers its editor for this face.
    function load(id as WatchFaceConfig.Id?) as Void {
        var pairs = [];
        var found = "no settings";
        try {
            var settings = WatchFaceConfig.getSettings(id);
            var refs = settings == null ? null : settings.complicationSettings;
            if (settings != null) {
                found = refs == null ? "no refs" : refs.size() + " refs";
            }
            if (refs != null) {
                for (var i = 0; i < refs.size(); i++) {
                    var ref = refs[i];
                    pairs.add([ref.uniqueIdentifier, ref.complicationId == null ? null : ref.complicationId.getType()]);
                }
            }
        } catch (e) {
            Parasha.log("face config: " + e.getErrorMessage());
        }
        _types = fromPairs(pairs);
        Parasha.log("face config " + id + ": " + found + " -> " + _types);
    }

    // [[spot, complication type], ...] -> each spot's Slots type: DEFAULTS where a spot is missing,
    // outside 1-5 or of a type the face does not show, and SUN for Sunrise or Sunset in spot 5.
    function fromPairs(pairs as Array) as Array<Number> {
        var types = DEFAULTS.slice(0, null) as Array<Number>;
        for (var i = 0; i < pairs.size(); i++) {
            var spot = (pairs[i] as Array)[0];
            var type = Slots.fromComplication((pairs[i] as Array)[1] as Number?);
            if (spot instanceof Number && spot >= 1 && spot <= COUNT && type != Slots.NONE) {
                types[spot - 1] = spot == Rings.SUN && (type == Slots.SUNRISE || type == Slots.SUNSET) ? Slots.SUN : type;
            }
        }
        return types;
    }
}
