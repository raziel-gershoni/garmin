import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;
import Toybox.WatchUi;

(:test)
module FaceTestSupport {
    // Offscreen dc the size of the device's screen.
    function screenDc() as Dc {
        var s = System.getDeviceSettings();
        var ref = Graphics.createBufferedBitmap({:width => s.screenWidth, :height => s.screenHeight});
        return (ref.get() as BufferedBitmap).getDc();
    }
}

// Draws the real face off-screen with every slot type in every slot, in both themes,
// with and without a parasha cache, so all drawing paths run at least once.
(:test)
function faceRendersEverySlotTypeAndTheme(logger as Logger) as Boolean {
    var dc = FaceTestSupport.screenDc();
    var view = new HebrewFaceView();
    view.onLayout(dc);
    var saved = TestCache.save();
    var today = Parasha.todayRd();
    Storage.setValue(Parasha.ITEMS_KEY, [[HebrewCalendar.shabbatOnOrAfter(today), "פרשת אחרי מות־קדושים", true],
        [HebrewCalendar.shabbatOnOrAfter(today + 1), "פרשת אחרי מות־קדושים", true]]);
    if (Parasha.titleFor(today) == null) {
        TestCache.restore(saved);
        return false;
    }
    Parasha.changed = true;
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
    Parasha.changed = true;
    view.onUpdate(dc);
    TestCache.restore(saved);
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
    var ok = Slots.typeOf(1) == Slots.next(before);
    Slots.setType(1, before);
    var theme = new WatchUi.MenuItem("Theme", "", :theme, null);
    delegate.onSelect(theme);
    ok = ok && SettingsMenu.isLight();
    delegate.onSelect(theme);
    return ok && !SettingsMenu.isLight();
}

// Solar is offered only where there is solar charging (not on AMOLED watches), and cycling
// the slot setting skips what is not offered.
(:test)
function solarSlotOnlyWithSolarCharging(logger as Logger) as Boolean {
    var amoled = SettingsMenu.amoled();
    return Slots.available(Slots.SOLAR) == !amoled
        && Slots.next(Slots.BODY_BATTERY) == (amoled ? Slots.NOTIFICATIONS : Slots.SOLAR)
        && Slots.next(Slots.CALORIES) == Slots.NONE;
}

// The light background is offered only on memory-in-pixel screens; AMOLED faces stay black.
(:test)
function themeOnlyWithoutAmoled(logger as Logger) as Boolean {
    var menu = SettingsMenu.build()[0] as WatchUi.Menu2;
    return (menu.findItemById(:theme) == -1) == SettingsMenu.amoled();
}

// Battery shows days left where the watch estimates them, like the native faces; percent otherwise.
(:test)
function batteryShowsDaysWhenKnown(logger as Logger) as Boolean {
    var stats = System.getSystemStats();
    var days = (stats has :batteryInDays) && stats.batteryInDays != null;
    var v = Slots.value(Slots.BATTERY, null);
    logger.debug("battery slot: " + v);
    return v.substring(v.length() - 1, v.length()).equals(days ? "d" : "%");
}
