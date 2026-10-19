import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// Draws the Venu face awake and always-on with every slot type (including Empty) in every slot,
// with and without a parasha, so every drawing path runs.
(:test)
function roundFaceRendersAwakeAndAlwaysOn(logger as Logger) as Boolean {
    var dc = RoundTestSupport.screenDc();
    var view = new HebrewFaceView();
    view.onLayout(dc);
    var saved = TestCache.save();
    var today = Parasha.todayRd();
    Storage.setValue(Parasha.ITEMS_KEY, [[HebrewCalendar.shabbatOnOrAfter(today), "פרשת אחרי מות־קדושים", true],
        [HebrewCalendar.shabbatOnOrAfter(today + 1), "פרשת אחרי מות־קדושים", true]]);
    Parasha.changed = true;
    for (var low = 0; low <= 1; low++) {
        view.setLowPower(low == 1);
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
    for (var slot = 1; slot <= Slots.SLOT_COUNT; slot++) {
        Slots.setType(slot, Slots.DEFAULTS[slot - 1]);
    }
    view.setLowPower(null);
    TestCache.restore(saved);
    return true;
}

// Review focus: the cached rim lines follow the Hebrew day and the display mode, are reused
// while nothing changes, and are refitted when the parasha cache changes.
(:test)
function rimLinesFollowTheDayAndTheMode(logger as Logger) as Boolean {
    var dc = RoundTestSupport.screenDc();
    var w = dc.getWidth();
    var view = new HebrewFaceView();
    var saved = TestCache.save();
    var rd = Parasha.todayRd();
    Parasha.changed = false;
    Storage.setValue(Parasha.ITEMS_KEY, [[HebrewCalendar.shabbatOnOrAfter(rd), "פרשת אחרי מות־קדושים", true],
        [HebrewCalendar.shabbatOnOrAfter(rd + 1), "פרשת אחרי מות־קדושים", true]]);
    view.setLowPower(false);
    view.refreshLines(dc, rd, w);
    var awake = view._dateLine as Array;
    var hasParasha = view._parashaLine != null;

    // Same day and mode: the cached line is reused (== on arrays is identity).
    view.refreshLines(dc, rd, w);
    var reused = view._dateLine == awake;

    // A changed parasha cache forces a refit and clears the flag.
    Parasha.changed = true;
    view.refreshLines(dc, rd, w);
    var refitted = view._dateLine != awake && !Parasha.changed;

    // Removing the cache drops the parasha line once the change is signalled.
    Storage.deleteValue(Parasha.ITEMS_KEY);
    Parasha.changed = true;
    view.refreshLines(dc, rd, w);
    var parashaGone = view._parashaLine == null;

    view.refreshLines(dc, rd + 1, w);
    var nextDay = view._dateLine as Array;
    view.setLowPower(true);
    view.refreshLines(dc, rd + 1, w);
    var dim = view._dateLine as Array;

    view.setLowPower(null);
    Parasha.changed = false;
    TestCache.restore(saved);
    return hasParasha && reused && refitted && parashaGone
        && !(awake[0] as String).equals(nextDay[0] as String) && dim[1] != nextDay[1];
}
