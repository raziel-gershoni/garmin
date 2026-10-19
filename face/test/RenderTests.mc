import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Draws the real face off-screen with every slot type in every slot, in both themes,
// with and without a parasha cache, so all drawing paths run at least once.
(:test)
function faceRendersEverySlotTypeAndTheme(logger as Logger) as Boolean {
    var dc = LayoutTestSupport.offscreenDc();
    var view = new HebrewFaceView();
    view.onLayout(dc);
    Storage.setValue(Parasha.ITEMS_KEY, [[Parasha.todayRd() + 3, "פרשת אחרי מות־קדושים", true]]);
    for (var theme = 0; theme <= 1; theme++) {
        Properties.setValue("Theme", theme);
        for (var type = 0; type < Slots.TYPE_COUNT; type++) {
            for (var slot = 1; slot <= Slots.SLOT_COUNT; slot++) {
                Slots.setType(slot, type);
            }
            view.onUpdate(dc);
        }
    }
    Storage.deleteValue(Parasha.ITEMS_KEY);
    view.onUpdate(dc);
    for (var slot = 1; slot <= Slots.SLOT_COUNT; slot++) {
        Slots.setType(slot, Slots.DEFAULTS[slot - 1]);
    }
    Properties.setValue("Theme", 0);
    return true;
}

(:test)
function settingsMenuBuildsAndCycles(logger as Logger) as Boolean {
    var built = SettingsMenu.build();
    var delegate = built[1] as SettingsDelegate;
    var item = new WatchUi.MenuItem("Slot 1", "", 1, null);
    var before = Slots.typeOf(1);
    delegate.onSelect(item);
    var ok = Slots.typeOf(1) == (before + 1) % Slots.TYPE_COUNT;
    Slots.setType(1, before);
    var theme = new WatchUi.MenuItem("Theme", "", :theme, null);
    delegate.onSelect(theme);
    ok = ok && SettingsMenu.isLight();
    delegate.onSelect(theme);
    return ok && !SettingsMenu.isLight();
}
