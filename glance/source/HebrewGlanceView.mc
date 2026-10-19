import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Glance: the Hebrew date on the first line, the parasha (or holiday) under it, right-aligned.
(:glance)
class HebrewGlanceView extends WatchUi.GlanceView {

    var _loggedMemory = false;

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var day = HebrewDay.now();
        var h = day[0] as Array<Number>;
        var right = dc.getWidth() - 1;
        var maxWidth = dc.getWidth() - 2;

        var date = HebrewDay.fit(dc, [
            [HebrewFormat.full(h), Graphics.FONT_GLANCE],
            [HebrewFormat.full(h), Graphics.FONT_XTINY],
            [HebrewFormat.dayMonth(h), Graphics.FONT_GLANCE]
        ], maxWidth);
        dc.drawText(right, 2, date[1], date[0], Graphics.TEXT_JUSTIFY_RIGHT);

        var title = Parasha.titleFor(day[1] as Number);
        if (title != null) {
            var p = HebrewDay.fit(dc, HebrewDay.parashaOptions(title), maxWidth);
            dc.drawText(right, dc.getHeight() / 2 + 2, p[1], p[0], Graphics.TEXT_JUSTIFY_RIGHT);
        }
        if (!_loggedMemory) {
            var stats = System.getSystemStats();
            System.println("glance mem " + stats.usedMemory + "/" + stats.totalMemory);
            _loggedMemory = true;
        }
    }
}
