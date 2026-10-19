import Toybox.Application;
import Toybox.Lang;

// Tests that write the parasha cache put the simulator's real cache back afterwards, so a test
// run does not leave the face without a parasha until its next hourly retry.
(:test)
module TestCache {
    function save() as Application.PropertyValueType? {
        return Application.Storage.getValue(Parasha.ITEMS_KEY);
    }

    function restore(saved as Application.PropertyValueType?) as Void {
        if (saved == null) {
            Application.Storage.deleteValue(Parasha.ITEMS_KEY);
        } else {
            Application.Storage.setValue(Parasha.ITEMS_KEY, saved);
        }
    }
}
