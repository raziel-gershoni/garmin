import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Today's Hebrew date (rolled over at sunset) and text fitting, shared by the glance and the detail view.
(:glance)
module HebrewDay {

    // [hebrewDate, hebrewRd, sun] where sun is [sunrise, sunset] seconds or null.
    function now() as Array {
        var t = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var civilRd = HebrewCalendar.fixedFromGregorian(t.year as Number, t.month as Number, t.day as Number);
        var sun = SunTimes.today(civilRd, null);
        var secs = (t.hour as Number) * 3600 + (t.min as Number) * 60 + (t.sec as Number);
        var hebrewRd = civilRd + ((sun != null && secs >= sun[1]) ? 1 : 0);
        return [HebrewCalendar.fromFixed(hebrewRd), hebrewRd, sun];
    }

    // First [text, font] pair whose width fits maxWidth; otherwise the last one.
    function fit(dc as Dc, options as Array<Array>, maxWidth as Number) as Array {
        for (var i = 0; i < options.size(); i++) {
            if (dc.getTextWidthInPixels(options[i][0], options[i][1]) <= maxWidth) {
                return options[i];
            }
        }
        return options[options.size() - 1];
    }

    function parashaOptions(title as String) as Array<Array> {
        var options = [[title, Graphics.FONT_SMALL], [title, Graphics.FONT_XTINY]];
        if (title.find("פרשת ") == 0) {
            var short = title.substring(5, title.length());
            options.add([short, Graphics.FONT_SMALL]);
            options.add([short, Graphics.FONT_XTINY]);
        }
        return options;
    }

    // Registering may be refused in some contexts (e.g. the glance on some firmware); the next
    // foreground start tries again.
    function scheduleSync() as Void {
        try {
            Parasha.scheduleSync();
        } catch (e) {
            System.println("scheduleSync: " + e.getErrorMessage());
        }
    }
}
