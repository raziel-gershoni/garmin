import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Test;

(:test)
module RoundTestSupport {
    // Offscreen dc the size of the Venu screen.
    function screenDc() as Dc {
        var s = System.getDeviceSettings();
        var ref = Graphics.createBufferedBitmap({:width => s.screenWidth, :height => s.screenHeight});
        return (ref.get() as BufferedBitmap).getDc();
    }

    // Every date of a Hebrew year fits the top rim, awake and always-on; only Adar I/II dates may
    // lose the month's geresh.
    function yearFitsTopRim(logger as Logger, year as Number) as Boolean {
        var dc = screenDc();
        var w = dc.getWidth();
        var max = RoundText.rimMaxLength(w);
        var failures = 0;
        var end = HebrewCalendar.newYear(year + 1);
        for (var rd = HebrewCalendar.newYear(year); rd < end; rd++) {
            var h = HebrewCalendar.fromFixed(rd);
            for (var low = 0; low <= 1; low++) {
                var line = RoundText.fitRim(dc, RoundText.dateOptions(h), w, low == 1);
                var logical = RoundText.visual(line[0] as String);
                var compacted = !logical.equals(HebrewFormat.full(h));
                if (dc.getTextWidthInPixels(line[0] as String, line[1]) > max || (compacted && h[1] < HebrewCalendar.ADAR)) {
                    logger.error(HebrewFormat.full(h) + " -> " + logical);
                    failures++;
                }
            }
        }
        return failures == 0;
    }
}

(:test)
function rimTextReversesIntoVisualOrder(logger as Logger) as Boolean {
    return RoundText.visual("אבג ד״ה").equals("ה״ד גבא") && RoundText.visual("").equals("");
}

// 5787 is a leap year (Adar I/II), 5788 a common year, 5798 a leap year with the widest year letters.
(:test)
function datesOf5787FitTopRim(logger as Logger) as Boolean {
    return RoundTestSupport.yearFitsTopRim(logger, 5787);
}

(:test)
function datesOf5788FitTopRim(logger as Logger) as Boolean {
    return RoundTestSupport.yearFitsTopRim(logger, 5788);
}

(:test)
function datesOf5798FitTopRim(logger as Logger) as Boolean {
    return RoundTestSupport.yearFitsTopRim(logger, 5798);
}

// Every parasha and holiday-Shabbat title (Israel) fits the bottom rim, awake and always-on.
(:test)
function titlesFitBottomRim(logger as Logger) as Boolean {
    var dc = RoundTestSupport.screenDc();
    var w = dc.getWidth();
    var max = RoundText.rimMaxLength(w);
    var titles = TitleFixtures.TITLES.slice(0, null);
    titles.addAll(["פרשת אחרי מות־קדושים", "פרשת תזריע־מצורע", "פרשת בהר־בחוקותי"]);
    var failures = 0;
    for (var i = 0; i < titles.size(); i++) {
        for (var low = 0; low <= 1; low++) {
            var line = RoundText.fitRim(dc, RoundText.titleOptions(titles[i]), w, low == 1);
            if (dc.getTextWidthInPixels(line[0] as String, line[1]) > max) {
                logger.error(titles[i] + " does not fit");
                failures++;
            }
        }
    }
    return failures == 0;
}

// Always-on moves the drawing every minute, never more than 3 px from centre.
(:test)
function burnInShiftMovesEveryMinuteWithinThreePixels(logger as Logger) as Boolean {
    for (var m = 0; m < 60; m++) {
        var o = Dial.burnInOffset(m);
        var n = Dial.burnInOffset((m + 1) % 60);
        if (o[0].abs() > 3 || o[1].abs() > 3 || (o[0] == n[0] && o[1] == n[1])) {
            logger.error("minute " + m + ": " + o + " then " + n);
            return false;
        }
    }
    return true;
}

// A hand's tip points along its clock angle: 12 o'clock is straight up.
(:test)
function handTipFollowsTheAngle(logger as Logger) as Boolean {
    var up = Dial.points(100, 100, 0.0, 50.0, 10.0, 0.0);
    var right = Dial.points(100, 100, (Math.PI / 2).toFloat(), 50.0, 10.0, 0.0);
    return (up[2][1] - 50).abs() < 0.01 && (up[3][1] - 50).abs() < 0.01
        && (right[2][0] - 150).abs() < 0.01 && (right[3][0] - 150).abs() < 0.01;
}
