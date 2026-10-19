import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Today's Hebrew date (rolled over at sunset), shared by the glance and the detail view, and the
// glance's text fitting.
(:glance)
module HebrewDay {

    // [hebrewDate, hebrewRd, sun] where sun is [sunrise, sunset] seconds or null.
    function now() as Array {
        var day = Today.at(Time.now(), null);
        return [HebrewCalendar.fromFixed(day[3] as Number), day[3], day[2]];
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
}
