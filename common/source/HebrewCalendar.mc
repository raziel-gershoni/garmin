import Toybox.Lang;

// Hebrew calendar arithmetic after Reingold & Dershowitz, "Calendrical Calculations".
//
// Dates are R.D. fixed day numbers (R.D. 1 = Monday 1 January 1, proleptic Gregorian).
// Hebrew months use the Biblical numbering, same as Hebcal:
//   Nisan = 1 ... Elul = 6, Tishrei = 7 ... Adar = 12 (Adar I in leap years), Adar II = 13.
// Every intermediate value fits a 32-bit Number for Hebrew years up to ~12600.
// tools/hebcal-oracle.mjs mirrors this file line by line and checks it against @hebcal/core.
(:glance, :background)
module HebrewCalendar {

    const EPOCH = -1373427; // R.D. of 1 Tishrei AM 1
    const NISAN = 1;
    const TISHREI = 7;
    const ADAR = 12;
    const ADAR_II = 13;

    function isLeapYear(year as Number) as Boolean {
        return (7 * year + 1) % 19 < 7;
    }

    function lastMonthOfYear(year as Number) as Number {
        return isLeapYear(year) ? ADAR_II : ADAR;
    }

    // Days from the epoch to the molad-based new year, with the first postponement rule applied.
    function elapsedDays(year as Number) as Number {
        var months = (235 * year - 234) / 19;
        var parts = 12084 + 13753 * months;
        var days = 29 * months + parts / 25920;
        if ((3 * (days + 1)) % 7 < 3) {
            days += 1;
        }
        return days;
    }

    // Remaining postponements, so no year has 356 or 382 days.
    function yearLengthCorrection(year as Number) as Number {
        var ny0 = elapsedDays(year - 1);
        var ny1 = elapsedDays(year);
        var ny2 = elapsedDays(year + 1);
        if (ny2 - ny1 == 356) {
            return 2;
        }
        if (ny1 - ny0 == 382) {
            return 1;
        }
        return 0;
    }

    // R.D. of 1 Tishrei of the given year.
    function newYear(year as Number) as Number {
        return EPOCH + elapsedDays(year) + yearLengthCorrection(year);
    }

    function daysInYear(year as Number) as Number {
        return newYear(year + 1) - newYear(year);
    }

    // Month length given the year's leap status and total length (353-355 or 383-385 days).
    function monthLength(month as Number, leap as Boolean, yearDays as Number) as Number {
        if (month == 2 || month == 4 || month == 6 || month == 10 || month == ADAR_II) {
            return 29;
        }
        if (month == ADAR && !leap) {
            return 29;
        }
        if (month == 8 && yearDays % 10 != 5) { // Cheshvan is long only in "complete" years
            return 29;
        }
        if (month == 9 && yearDays % 10 == 3) { // Kislev is short only in "deficient" years
            return 29;
        }
        return 30;
    }

    function lastDayOfMonth(month as Number, year as Number) as Number {
        return monthLength(month, isLeapYear(year), daysInYear(year));
    }

    // Month that follows `month` in year order (Tishrei first, Elul last).
    function nextMonth(month as Number, leap as Boolean) as Number {
        if (month == (leap ? ADAR_II : ADAR)) {
            return NISAN;
        }
        return month + 1;
    }

    function toFixed(year as Number, month as Number, day as Number) as Number {
        var ny = newYear(year);
        var yearDays = newYear(year + 1) - ny;
        var leap = isLeapYear(year);
        var rd = ny + day - 1;
        for (var m = TISHREI; m != month; m = nextMonth(m, leap)) {
            rd += monthLength(m, leap, yearDays);
        }
        return rd;
    }

    // Returns [year, month, day] for an R.D. date.
    function fromFixed(rd as Number) as Array<Number> {
        var year = (((rd - EPOCH).toLong() * 98496l) / 35975351l).toNumber() + 1;
        while (newYear(year) > rd) {
            year -= 1;
        }
        while (newYear(year + 1) <= rd) {
            year += 1;
        }
        var ny = newYear(year);
        var yearDays = newYear(year + 1) - ny;
        var leap = isLeapYear(year);
        var dayOfYear = rd - ny;
        var month = TISHREI;
        var len = monthLength(month, leap, yearDays);
        while (dayOfYear >= len) {
            dayOfYear -= len;
            month = nextMonth(month, leap);
            len = monthLength(month, leap, yearDays);
        }
        return [year, month, dayOfYear + 1];
    }

    function isGregorianLeapYear(year as Number) as Boolean {
        return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
    }

    // R.D. of a Gregorian date (year >= 1, month 1-12).
    function fixedFromGregorian(year as Number, month as Number, day as Number) as Number {
        var py = year - 1;
        var rd = 365 * py + py / 4 - py / 100 + py / 400 + (367 * month - 362) / 12 + day;
        if (month > 2) {
            rd -= isGregorianLeapYear(year) ? 1 : 2;
        }
        return rd;
    }

    // 0 = Sunday ... 6 = Saturday.
    function dayOfWeek(rd as Number) as Number {
        var dow = rd % 7;
        return dow < 0 ? dow + 7 : dow;
    }

    // R.D. of the first Saturday on or after rd.
    function shabbatOnOrAfter(rd as Number) as Number {
        return rd + (6 - dayOfWeek(rd));
    }
}
