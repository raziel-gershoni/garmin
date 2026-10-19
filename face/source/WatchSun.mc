import Toybox.Complications;
import Toybox.Lang;

// The watch's own sunrise/sunset (GPS-based), when it publishes them as complications.
// Watch faces only.
module WatchSun {

    // [sunrise, sunset] in seconds since local midnight; either may be null.
    function get() as Array? {
        if (!(Toybox has :Complications)) {
            return null;
        }
        return [value(Complications.COMPLICATION_TYPE_SUNRISE), value(Complications.COMPLICATION_TYPE_SUNSET)];
    }

    function value(type as Complications.Type) as Number? {
        try {
            var v = Complications.getComplication(new Complications.Id(type)).value;
            return v instanceof Number ? v : null;
        } catch (e) {
            return null;
        }
    }
}
