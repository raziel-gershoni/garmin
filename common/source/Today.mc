import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Today's dates for every view: the civil date, sunrise/sunset, and the Hebrew date, which
// rolls over at sunset.
(:glance)
module Today {

    // [info (FORMAT_SHORT), civilRd, sun, hebrewRd] for the moment now. fromWatch: the watch's own
    // [sunrise, sunset] (watch faces only, see WatchSun) or null.
    function at(now as Time.Moment, fromWatch as Array?) as Array {
        var t = Gregorian.info(now, Time.FORMAT_SHORT);
        var civilRd = HebrewCalendar.fixedFromGregorian(t.year as Number, t.month as Number, t.day as Number);
        var sun = SunTimes.today(civilRd, fromWatch);
        var secs = (t.hour as Number) * 3600 + (t.min as Number) * 60 + (t.sec as Number);
        return [t, civilRd, sun, hebrewRd(civilRd, secs, sun)];
    }

    // secs: seconds since local midnight.
    function hebrewRd(civilRd as Number, secs as Number, sun as Array<Number>?) as Number {
        return civilRd + ((sun != null && secs >= sun[1]) ? 1 : 0);
    }
}
