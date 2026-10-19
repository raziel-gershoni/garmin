import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Opened from the glance, laid out like the face: the Gregorian date and year left of the
// subscreen (left empty), the grey band with the full Hebrew date and the parasha, then sunrise and sunset.
class DetailView extends WatchUi.View {

    const YEAR_Y = 24;
    const SUNRISE_Y = 124;
    const SUNSET_Y = 146;

    var _band as BitmapResource?;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _band = WatchUi.loadResource(Rez.Drawables.Band) as BitmapResource;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var day = HebrewDay.now();
        var sun = day[2] as Array<Number>?;
        var t = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        DateBand.drawGregorian(dc, t);
        dc.drawText(DateBand.RIGHT, YEAR_Y, Graphics.FONT_XTINY, t.year.toString(), Graphics.TEXT_JUSTIFY_RIGHT);
        var title = Parasha.titleFor(day[1] as Number);
        DateBand.drawBand(dc, _band, DateBand.hebrewDate(dc, day[0] as Array<Number>),
            title == null ? null : DateBand.parasha(dc, title), Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

        drawLabelled(dc, SUNRISE_Y, WatchUi.loadResource(Rez.Strings.Sunrise) as String, SunTimes.format(sun == null ? null : sun[0]));
        drawLabelled(dc, SUNSET_Y, WatchUi.loadResource(Rez.Strings.Sunset) as String, SunTimes.format(sun == null ? null : sun[1]));
    }

    // "זריחה 06:44" centred: the Hebrew label on the right, the time to its left, drawn as two
    // pieces so the order does not depend on the firmware's handling of numbers in Hebrew text.
    function drawLabelled(dc as Dc, y as Number, label as String, value as String) as Void {
        var font = Graphics.FONT_SMALL;
        var labelWidth = dc.getTextWidthInPixels(label, font);
        var right = DateBand.CENTER_X + (labelWidth + DateBand.WORD_GAP + dc.getTextWidthInPixels(value, font)) / 2;
        dc.drawText(right, y, font, label, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(right - labelWidth - DateBand.WORD_GAP, y, font, value, Graphics.TEXT_JUSTIFY_RIGHT);
    }
}
