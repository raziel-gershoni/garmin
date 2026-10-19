import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Opened from the glance: both dates, the parasha, sunrise and sunset.
// Text stays clear of the subscreen (x >= 113, y < 62) and the cut corners.
class DetailView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var day = HebrewDay.now();
        var h = day[0] as Array<Number>;
        var sun = day[2] as Array<Number>?;

        var m = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        dc.drawText(108, 14, Graphics.FONT_XTINY, m.day_of_week + " " + m.day + " " + m.month, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(108, 34, Graphics.FONT_XTINY, m.year.toString(), Graphics.TEXT_JUSTIFY_RIGHT);

        var date = HebrewDay.fit(dc, [
            [HebrewFormat.full(h), Graphics.FONT_MEDIUM],
            [HebrewFormat.full(h), Graphics.FONT_SMALL],
            [HebrewFormat.full(h), Graphics.FONT_XTINY]
        ], 168);
        dc.drawText(88, 62, date[1], date[0], Graphics.TEXT_JUSTIFY_CENTER);

        var title = Parasha.titleFor(day[1] as Number);
        if (title != null) {
            var p = HebrewDay.fit(dc, HebrewDay.parashaOptions(title), 168);
            dc.drawText(88, 92, p[1], p[0], Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.drawText(88, 120, Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.Sunrise) + " " + SunTimes.format(sun == null ? null : sun[0]),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(88, 142, Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.Sunset) + " " + SunTimes.format(sun == null ? null : sun[1]),
            Graphics.TEXT_JUSTIFY_CENTER);
    }
}
