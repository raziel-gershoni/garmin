import Toybox.Lang;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// The other season's clock against the watch's: through the area's winter summer time runs ahead
// of the clock (usually an hour), through its summer winter time runs behind it, and where the
// area keeps one offset all year there is none. The area's offsets come from the watch's own
// time-zone data for the last known position (SunTimes.location, Jerusalem before any), so no
// dates are written in here. The shift counts only while the clock is on the area's current
// offset: a clock off it (a border zone mix-up, or an old position after travel) shows nothing. A
// zone that happens to share the area's current offset can't be told apart: with an Israeli
// position, a January clock in Johannesburg (+2 all year) still shows Israel's summer hour until
// the watch gets a new position. The Venu shows the other season as a barely visible hour hand
// (Dial.drawPhantom).
module SummerTime {

    // Days on from now at which yearOffsets also reads the area's offset: one of them falls in the
    // other season wherever that lasts more than about three months. (A single reading half a year
    // on misses south-east Australia's 189-day winters.) A shorter one is seen only while a reading
    // lands in it, so Morocco's five-week Ramadan time shows on some weeks and not others.
    const PROBE_DAYS = [91, 182, 273];

    // Tests set a shift here; null uses the watch's own.
    var override = null as Number?;

    var _key = "";
    var _shift = 0;
    var _failed = false;
    var _mismatchLogged = false;

    // Seconds from the clock to the other season's clock now: positive in winter (summer time),
    // negative in summer (winter time), 0 for none. Worked out again each hour, when the clock's
    // offset changes, or when the face moves.
    function shift() as Number {
        if (override != null) {
            return override as Number;
        }
        var now = Time.now();
        var loc = SunTimes.location();
        var clock = System.getClockTime().timeZoneOffset;
        var key = (now.value() / 3600) + ":" + clock + ":" + loc[0].format("%.2f") + ":" + loc[1].format("%.2f");
        if (!key.equals(_key)) {
            var area = offsetAt(loc, now);
            if (area != null && area != clock && !_mismatchLogged) {
                Parasha.log("summer time: clock " + clock + " but " + area + " at " + loc);
                _mismatchLogged = true;
            }
            _shift = shiftOf(area, yearOffsets(loc, now), clock);
            _key = key;
        }
        return _shift;
    }

    // From the area's current offset (nowOffset) to its other one over the coming year (year:
    // [smallest, largest]), while the clock is on the current one (clockOffset): the largest when
    // the area is not on it (winter), else the smallest (summer). Offsets in seconds from UTC, null
    // where unknown; 0 otherwise.
    function shiftOf(nowOffset as Number?, year as Array<Number>?, clockOffset as Number) as Number {
        if (nowOffset == null || year == null || clockOffset != nowOffset) {
            return 0;
        }
        return (nowOffset == year[1] ? year[0] : year[1]) - nowOffset;
    }

    // [smallest, largest] UTC offset at loc from moment to PROBE_DAYS on, in seconds; null if the
    // watch gives none for any of them.
    function yearOffsets(loc as Array<Double>, moment as Time.Moment) as Array<Number>? {
        var first = offsetAt(loc, moment);
        if (first == null) {
            return null;
        }
        var smallest = first;
        var largest = first;
        for (var i = 0; i < PROBE_DAYS.size(); i++) {
            var o = offsetAt(loc, moment.add(new Time.Duration(PROBE_DAYS[i] * 86400)));
            if (o == null) {
                return null;
            }
            smallest = o < smallest ? o : smallest;
            largest = o > largest ? o : largest;
        }
        return [smallest, largest];
    }

    // The UTC offset in seconds at loc ([lat, lon] in degrees) at moment, from the watch's
    // time-zone data; null (logged once) where the watch gives none.
    function offsetAt(loc as Array<Double>, moment as Time.Moment) as Number? {
        var where = new Position.Location({:latitude => loc[0], :longitude => loc[1], :format => :degrees});
        var local = null;
        try {
            local = Gregorian.localMoment(where, moment);
        } catch (e) {
            logOnce("summer time: " + e.getErrorMessage());
            return null;
        }
        if (local == null) {
            logOnce("summer time: no zone at " + loc);
            return null;
        }
        return local.getOffset();
    }

    // The first failure goes into the log; the face asks every hour, so later ones would crowd it.
    function logOnce(message as String) as Void {
        if (!_failed) {
            Parasha.log(message);
            _failed = true;
        }
    }
}
