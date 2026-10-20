import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;
import Toybox.WatchUi;

// The settings list every slot, each showing its widget, then the background.
(:test)
function settingsListEverySlotAndTheBackground(logger as Logger) as Boolean {
    var menu = SettingsMenu.build()[0] as WatchUi.Menu2;
    for (var slot = 1; slot <= FaceSlots.COUNT; slot++) {
        if (menu.findItemById(slot) != slot - 1) {
            return false;
        }
    }
    return menu.findItemById(:theme) == FaceSlots.COUNT;
}

// A slot's list offers every widget the watch can show, in Slots.ORDER with Empty last, and ticks
// only the slot's current one.
(:test)
function slotListTicksTheCurrentWidget(logger as Logger) as Boolean {
    var saved = TestSlots.save();
    TestSlots.set(2, Slots.STEPS);
    var list = SettingsMenu.slotList(2);
    var types = Slots.offered();
    var ticked = 0;
    var ok = list.getItem(types.size()) == null;
    for (var i = 0; i < types.size(); i++) {
        var item = list.getItem(i) as WatchUi.CheckboxMenuItem;
        ok = ok && item.getId() == types[i];
        if (item.isChecked()) {
            ticked++;
            ok = ok && types[i] == Slots.STEPS;
        }
    }
    TestSlots.restore(saved);
    return ok && ticked == 1 && types[types.size() - 1] == Slots.NONE;
}

// Picking a widget saves it for the slot, shows its name under the slot's name and moves the
// slot list's tick to it alone.
(:test)
function pickingAWidgetSavesIt(logger as Logger) as Boolean {
    var saved = TestSlots.save();
    var item = new WatchUi.MenuItem("Slot 4", "", 4, null);
    new SlotListDelegate(4, item).pick(Slots.STRESS);
    var sub = item.getSubLabel();
    var name = WatchUi.loadResource(Slots.names()[Slots.STRESS]) as String;
    logger.debug("sub-label " + sub);
    var ok = FaceSlots.typeOf(4) == Slots.STRESS && sub instanceof String && sub.equals(name);
    var list = SettingsMenu.slotList(4);
    var ticked = [];
    for (var i = 0; list.getItem(i) != null; i++) {
        var entry = list.getItem(i) as WatchUi.CheckboxMenuItem;
        if (entry.isChecked()) {
            ticked.add(entry.getId());
        }
    }
    logger.debug("ticked " + ticked);
    TestSlots.restore(saved);
    return ok && ticked.toString().equals([Slots.STRESS].toString());
}

// The background item flips between dark and light.
(:test)
function backgroundItemFlipsTheTheme(logger as Logger) as Boolean {
    var delegate = SettingsMenu.build()[1] as SettingsDelegate;
    var theme = new WatchUi.MenuItem("Theme", "", :theme, null);
    var was = SettingsMenu.isLight();
    delegate.onSelect(theme);
    var flipped = SettingsMenu.isLight() != was;
    delegate.onSelect(theme);
    return flipped && SettingsMenu.isLight() == was;
}
