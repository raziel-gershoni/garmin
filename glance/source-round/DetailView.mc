import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Opened from the glance on the Venu: the Hebrew date along the top rim, the parasha along the
// bottom rim, the Gregorian date in Hebrew under 12, and sunrise and sunset in the middle.
class DetailView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var c = w / 2;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setAntiAlias(true);
        var day = HebrewDay.now();
        var sun = day[2] as Array<Number>?;
        var t = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        RoundText.drawRim(dc, c, c, w, RoundText.fitRim(dc, RoundText.dateOptions(day[0] as Array<Number>), w, false), true);
        var title = Parasha.titleFor(day[1] as Number);
        if (title != null) {
            dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
            RoundText.drawRim(dc, c, c, w, RoundText.fitRim(dc, RoundText.titleOptions(title), w, false), false);
        }

        var hebrew = RoundText.font(RoundText.REGULAR, 28, w);
        var digits = RoundText.font("RobotoCondensedBold", 30, w);
        var gap = 8 * w / 390;
        dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        RoundText.drawPair(dc, c, c - 107 * w / 390, HebrewFormat.weekday(t.day_of_week as Number), hebrew,
            t.day + "." + t.month + "." + t.year, digits, gap);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        RoundText.drawPair(dc, c, c - 40 * w / 390, WatchUi.loadResource(Rez.Strings.Sunrise) as String, hebrew,
            SunTimes.format(sun == null ? null : sun[0]), digits, gap);
        RoundText.drawPair(dc, c, c + 10 * w / 390, WatchUi.loadResource(Rez.Strings.Sunset) as String, hebrew,
            SunTimes.format(sun == null ? null : sun[1]), digits, gap);
    }
}
