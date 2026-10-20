import Toybox.Lang;
import Toybox.Test;

// Sets the Venu's spots for tests through FaceSlots.forced, which leaves the simulator's saved
// editor settings untouched (WatchFaceConfig.setSettings would overwrite them), and puts them back.
(:test)
module TestSlots {

    function set(slot as Number, type as Number) as Void {
        var types = save();
        types[slot - 1] = type;
        FaceSlots.forced = types;
    }

    function setAll(type as Number) as Void {
        for (var slot = 1; slot <= FaceSlots.COUNT; slot++) {
            set(slot, type);
        }
    }

    function save() as Array<Number> {
        var types = [];
        for (var slot = 1; slot <= FaceSlots.COUNT; slot++) {
            types.add(FaceSlots.typeOf(slot));
        }
        return types;
    }

    function restore(saved as Array<Number>) as Void {
        FaceSlots.forced = saved;
    }

    function reset() as Void {
        FaceSlots.forced = null;
    }
}
