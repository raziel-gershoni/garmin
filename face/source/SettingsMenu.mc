import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// On-watch settings (sideloaded apps get no phone settings).
// Selecting an item cycles to the next choice.
module SettingsMenu {

    function build() as [WatchUi.Views, WatchUi.InputDelegates] {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.SettingsTitle});
        var titles = [Rez.Strings.Slot1Title, Rez.Strings.Slot2Title, Rez.Strings.Slot3Title,
                      Rez.Strings.Slot4Title, Rez.Strings.Slot5Title, Rez.Strings.Slot6Title];
        var names = Slots.names();
        for (var slot = 1; slot <= FaceSlots.COUNT; slot++) {
            menu.addItem(new WatchUi.MenuItem(titles[slot - 1], names[FaceSlots.typeOf(slot)], slot, null));
        }
        if (!amoled()) {
            menu.addItem(new WatchUi.MenuItem(Rez.Strings.ThemeTitle, themeName(), :theme, null));
        }
        return [menu, new SettingsDelegate()];
    }

    // AMOLED faces stay black: a light background would burn power and break always-on rules.
    function amoled() as Boolean {
        return System.getDeviceSettings().requiresBurnInProtection;
    }

    function isLight() as Boolean {
        return Properties.getValue("Theme") == 1;
    }

    function themeName() as ResourceId {
        return isLight() ? Rez.Strings.ThemeLight : Rez.Strings.ThemeDark;
    }
}

class SettingsDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :theme) {
            Properties.setValue("Theme", SettingsMenu.isLight() ? 0 : 1);
            item.setSubLabel(SettingsMenu.themeName());
        } else {
            var slot = id as Number;
            var next = Slots.next(FaceSlots.typeOf(slot));
            FaceSlots.setType(slot, next);
            item.setSubLabel(Slots.names()[next]);
        }
        WatchUi.requestUpdate();
    }
}
