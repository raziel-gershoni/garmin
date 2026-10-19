import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

(:test)
module GlanceTestSupport {
    function dc(width as Number, height as Number) as Dc {
        var ref = Graphics.createBufferedBitmap({:width => width, :height => height});
        return (ref.get() as BufferedBitmap).getDc();
    }
}

// Draws the glance (164x61 content area) and the detail view off-screen, with and without a
// parasha cache, so every drawing path runs at least once.
(:test)
function glanceAndDetailRender(logger as Logger) as Boolean {
    var glance = new HebrewGlanceView();
    var detail = new DetailView();
    var glanceDc = GlanceTestSupport.dc(164, 61);
    var screenDc = GlanceTestSupport.dc(System.getDeviceSettings().screenWidth, System.getDeviceSettings().screenHeight);
    detail.onLayout(screenDc);
    glance.onUpdate(glanceDc);
    detail.onUpdate(screenDc);
    var saved = TestCache.save();
    var today = Parasha.todayRd();
    Storage.setValue(Parasha.ITEMS_KEY, [[HebrewCalendar.shabbatOnOrAfter(today), "פרשת תזריע־מצורע", true],
        [HebrewCalendar.shabbatOnOrAfter(today + 1), "פרשת תזריע־מצורע", true]]);
    if (Parasha.titleFor(today) == null) {
        TestCache.restore(saved);
        return false;
    }
    Parasha.changed = true;
    glance.onUpdate(glanceDc);
    detail.onUpdate(screenDc);
    TestCache.restore(saved);
    return true;
}

// The widest Hebrew date of a leap year still fits the glance line with some option.
(:test)
function glanceDateFitsWidth(logger as Logger) as Boolean {
    var dc = GlanceTestSupport.dc(164, 61);
    var start = HebrewCalendar.newYear(5787);
    var end = HebrewCalendar.newYear(5788);
    for (var rd = start; rd < end; rd++) {
        var h = HebrewCalendar.fromFixed(rd);
        var date = HebrewDay.fit(dc, [
            [HebrewFormat.full(h), Graphics.FONT_GLANCE],
            [HebrewFormat.full(h), Graphics.FONT_XTINY],
            [HebrewFormat.dayMonth(h), Graphics.FONT_GLANCE]
        ], 162);
        if (dc.getTextWidthInPixels(date[0], date[1]) > 162) {
            logger.error(date[0] + " does not fit");
            return false;
        }
    }
    return true;
}
