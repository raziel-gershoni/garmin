import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// On-watch settings (sideloaded apps get no phone settings): one item per slot, showing its
// widget and opening the list of widgets for it, then the background colour.
module SettingsMenu {

    // The main settings list: each slot with its widget under it, then the background.
    function build() as [WatchUi.Views, WatchUi.InputDelegates] {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.SettingsTitle});
        var names = Slots.names();
        for (var slot = 1; slot <= FaceSlots.COUNT; slot++) {
            menu.addItem(new WatchUi.MenuItem(title(slot), names[FaceSlots.typeOf(slot)], slot, null));
        }
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.ThemeTitle, themeName(), :theme, null));
        return [menu, new SettingsDelegate()];
    }

    // A slot's name in the lists ("Slot 1 (top left)" and so on).
    function title(slot as Number) as ResourceId {
        return [Rez.Strings.Slot1Title, Rez.Strings.Slot2Title, Rez.Strings.Slot3Title,
                Rez.Strings.Slot4Title, Rez.Strings.Slot5Title, Rez.Strings.Slot6Title][slot - 1];
    }

    // Every widget this watch offers for slot (Slots.offered), with the current one ticked and the
    // list opening on it.
    function slotList(slot as Number) as WatchUi.CheckboxMenu {
        var types = Slots.offered();
        var current = FaceSlots.typeOf(slot);
        var focus = types.indexOf(current);
        var list = new WatchUi.CheckboxMenu({:title => title(slot), :focus => focus < 0 ? 0 : focus});
        var names = Slots.names();
        for (var i = 0; i < types.size(); i++) {
            list.addItem(new WatchUi.CheckboxMenuItem(names[types[i]], null, types[i], types[i] == current, null));
        }
        return list;
    }

    // Whether the user picked the light background.
    function isLight() as Boolean {
        return Properties.getValue("Theme") == 1;
    }

    // The background's name for the settings list.
    function themeName() as ResourceId {
        return isLight() ? Rez.Strings.ThemeLight : Rez.Strings.ThemeDark;
    }
}

class SettingsDelegate extends WatchUi.Menu2InputDelegate {

    // The main list's input handler.
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    // A slot opens its list; the background flips between dark and light.
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :theme) {
            Properties.setValue("Theme", SettingsMenu.isLight() ? 0 : 1);
            item.setSubLabel(SettingsMenu.themeName());
            WatchUi.requestUpdate();
        } else {
            var slot = id as Number;
            WatchUi.pushView(SettingsMenu.slotList(slot), new SlotListDelegate(slot, item), WatchUi.SLIDE_LEFT);
        }
    }
}

// A slot's list: picking a widget saves it, shows it under the slot's name and goes back; Back
// leaves the slot as it was.
class SlotListDelegate extends WatchUi.Menu2InputDelegate {

    var _slot as Number;
    var _slotItem as WatchUi.MenuItem;

    // A list for slot, which updates slotItem (the slot's entry in the main list) on a pick.
    function initialize(slot as Number, slotItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _slot = slot;
        _slotItem = slotItem;
    }

    // Picking a widget saves it and goes back to the main list.
    function onSelect(item as WatchUi.MenuItem) as Void {
        pick(item.getId() as Number);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    // Saves type for the slot, shows its name under the slot's entry and redraws the face.
    function pick(type as Number) as Void {
        FaceSlots.setType(_slot, type);
        _slotItem.setSubLabel(Slots.names()[type]);
        WatchUi.requestUpdate();
    }
}
