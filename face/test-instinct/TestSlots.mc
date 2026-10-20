import Toybox.Lang;
import Toybox.Test;

// Sets slot choices for tests through this watch's own FaceSlots, and puts them back.
(:test)
module TestSlots {

    function set(slot as Number, type as Number) as Void {
        FaceSlots.setType(slot, type);
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
        for (var slot = 1; slot <= saved.size(); slot++) {
            set(slot, saved[slot - 1]);
        }
    }

    function reset() as Void {
        restore(FaceSlots.DEFAULTS.slice(0, FaceSlots.COUNT) as Array<Number>);
    }
}
