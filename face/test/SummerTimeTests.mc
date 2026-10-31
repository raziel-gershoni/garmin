import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;
import Toybox.Time.Gregorian;

// The other season's clock against the watch's: summer time's lead (an hour, half on Lord Howe)
// through the area's winter and winter time's lag through its summer; nothing where the area keeps
// one offset all year, nothing while the clock is not on the area's current offset (a border zone
// mix-up, or another offset with an old position after travel), and nothing without the area's
// offsets.
(:test)
function otherSeasonShiftsTheClock(logger as Logger) as Boolean {
    // [area's offset now, its smallest and largest over the coming year, the clock's offset, shift]
    var cases = [
        [7200, 7200, 10800, 7200, 3600],      // Israel in winter: summer time an hour on
        [10800, 7200, 10800, 10800, -3600],   // Israel in summer: winter time an hour back
        [10800, 10800, 10800, 10800, 0],      // Jordan: one offset all year
        [36000, 36000, 39600, 36000, 3600],   // Sydney in July
        [39600, 36000, 39600, 39600, -3600],  // Sydney in January
        [37800, 37800, 39600, 37800, 1800],   // Lord Howe in July: half an hour
        [39600, 37800, 39600, 39600, -1800],  // Lord Howe in January
        [7200, 7200, 10800, 10800, 0],        // the clock already on summer time (a border zone mix-up)
        [7200, 7200, 10800, 14400, 0],        // the clock ahead of summer time
        [7200, 7200, 10800, 3600, 0],         // Rome's clock in January, the last position in Israel
        [10800, 7200, 10800, 7200, 0],        // Rome's clock in July, the last position in Israel
        [7200, 7200, 10800, -18000, 0],       // the clock far away
        [null, 7200, 10800, 7200, 0],
        [7200, null, null, 7200, 0]
    ];
    var failures = 0;
    for (var i = 0; i < cases.size(); i++) {
        var c = cases[i] as Array;
        var year = c[1] == null ? null : [c[1], c[2]] as Array<Number>;
        var got = SummerTime.shiftOf(c[0] as Number?, year, c[3] as Number);
        if (got != c[4]) {
            logger.error("case " + i + ": " + got + " instead of " + c[4]);
            failures++;
        }
    }
    return failures == 0;
}

// The area's smallest and largest offsets over the coming year span both seasons from any day,
// even in Sydney's 189-day winter of 2029 (summer time ends on 1 April and starts again on
// 7 October, so the day half a year after 2 April is still winter).
(:test)
function yearOffsetsReachAcrossLongWinters(logger as Logger) as Boolean {
    var sydney = [-33.87d, 151.21d] as Array<Double>;
    var jerusalem = SunTimes.JERUSALEM as Array<Double>;
    var cases = [
        [sydney, Gregorian.moment({:year => 2029, :month => 4, :day => 2, :hour => 12}), [36000, 39600]],
        [sydney, Gregorian.moment({:year => 2029, :month => 7, :day => 15, :hour => 12}), [36000, 39600]],
        [sydney, Gregorian.moment({:year => 2029, :month => 1, :day => 15, :hour => 12}), [36000, 39600]],
        [jerusalem, Gregorian.moment({:year => 2026, :month => 11, :day => 15, :hour => 12}), [7200, 10800]],
        [jerusalem, Gregorian.moment({:year => 2026, :month => 7, :day => 15, :hour => 12}), [7200, 10800]]
    ];
    var failures = 0;
    for (var i = 0; i < cases.size(); i++) {
        var c = cases[i] as Array;
        var got = SummerTime.yearOffsets(c[0] as Array<Double>, c[1] as Time.Moment);
        var want = c[2] as Array<Number>;
        if (got == null || got[0] != want[0] || got[1] != want[1]) {
            logger.error("case " + i + ": " + got + " instead of " + want);
            failures++;
        }
    }
    return failures == 0;
}

// The watch's own time-zone data gives Jerusalem two hours in January and three in July.
(:test)
function watchKnowsJerusalemSummerTime(logger as Logger) as Boolean {
    var january = Gregorian.moment({:year => 2026, :month => 1, :day => 15, :hour => 12});
    var july = Gregorian.moment({:year => 2026, :month => 7, :day => 15, :hour => 12});
    var winter = SummerTime.offsetAt(SunTimes.JERUSALEM as Array<Double>, january);
    var summer = SummerTime.offsetAt(SunTimes.JERUSALEM as Array<Double>, july);
    logger.debug("Jerusalem " + winter + " / " + summer);
    return winter == 7200 && summer == 10800;
}

// On the watch's own clock and position the shift is nothing or an hour either way, and a test
// override wins until it is cleared.
(:test)
function summerTimeShiftRuns(logger as Logger) as Boolean {
    var own = SummerTime.shift();
    logger.debug("shift " + own);
    SummerTime.override = -1800;
    var forced = SummerTime.shift();
    SummerTime.override = null;
    return (own == 0 || own == 3600 || own == -3600) && forced == -1800 && SummerTime.shift() == own;
}

// The face draws with the other season's clock an hour and half an hour on, an hour back, and
// without it, awake and asleep, so every path runs (each watch's own tests add its low-power
// paths).
(:test)
function faceDrawsWithAndWithoutTheOtherSeason(logger as Logger) as Boolean {
    var dc = FaceTestSupport.screenDc();
    var view = new HebrewFaceView();
    view.onLayout(dc);
    var shifts = [3600, 1800, -3600, 0];
    for (var i = 0; i < shifts.size(); i++) {
        SummerTime.override = shifts[i];
        view.onUpdate(dc);
        view.onEnterSleep();
        view.onUpdate(dc);
        view.onExitSleep();
    }
    SummerTime.override = null;
    return true;
}
