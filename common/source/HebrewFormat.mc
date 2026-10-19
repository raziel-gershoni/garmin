import Toybox.Lang;

// Hebrew-letter rendering of Hebrew dates, matching Hebcal's style:
// no niqqud, geresh after a single letter, gershayim before the last letter,
// 15/16 written ט״ו/ט״ז, years without the thousands (5787 -> תשפ״ז).
// Strings are in logical order; the watch's text renderer handles right-to-left.
(:glance)
module HebrewFormat {

    const GERESH = "׳";
    const GERSHAYIM = "״";

    const ONES = ["א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"];
    const TENS = ["י", "כ", "ל", "מ", "נ", "ס", "ע", "פ", "צ"];
    const HUNDREDS = ["ק", "ר", "ש"];

    // Index = Gregorian.Info.day_of_week - 1 (Sunday ... Saturday).
    const WEEKDAYS = ["א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ש׳"];

    // Index = Hebrew month number (1 = Nisan ... 13 = Adar II).
    const MONTHS = ["", "ניסן", "אייר", "סיון", "תמוז", "אב", "אלול",
                    "תשרי", "חשון", "כסלו", "טבת", "שבט", "אדר", "אדר ב׳"];

    // n in 1..999 (callers drop the thousands from years).
    function gematria(n as Number) as String {
        var letters = [] as Array<String>;
        while (n >= 400) {
            letters.add("ת");
            n -= 400;
        }
        if (n >= 100) {
            letters.add(HUNDREDS[n / 100 - 1]);
            n = n % 100;
        }
        if (n == 15 || n == 16) {
            letters.add("ט");
            letters.add(ONES[n - 10]);
            n = 0;
        }
        if (n >= 10) {
            letters.add(TENS[n / 10 - 1]);
            n = n % 10;
        }
        if (n > 0) {
            letters.add(ONES[n - 1]);
        }

        var count = letters.size();
        if (count == 1) {
            return letters[0] + GERESH;
        }
        var s = "";
        for (var i = 0; i < count; i++) {
            if (i == count - 1) {
                s += GERSHAYIM;
            }
            s += letters[i];
        }
        return s;
    }

    function monthName(month as Number, year as Number) as String {
        if (month == HebrewCalendar.ADAR && HebrewCalendar.isLeapYear(year)) {
            return "אדר א׳";
        }
        return MONTHS[month];
    }

    // 1 (Sunday) -> "א׳" ... 7 (Saturday) -> "ש׳"
    function weekday(dow as Number) as String {
        return WEEKDAYS[dow - 1];
    }

    // "ז׳ חשון"
    function dayMonth(hdate as Array<Number>) as String {
        return gematria(hdate[2]) + " " + monthName(hdate[1], hdate[0]);
    }

    // "תשפ״ז"
    function year(hdate as Array<Number>) as String {
        return gematria(hdate[0] % 1000);
    }

    // "ז׳ חשון תשפ״ז"
    function full(hdate as Array<Number>) as String {
        return dayMonth(hdate) + " " + year(hdate);
    }
}
