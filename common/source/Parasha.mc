import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.StringUtil;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Weekly parasha (Israel schedule) and holidays, fetched from Hebcal by a background
// service and cached in Storage as [[rd, hebrewTitle, isParasha], ...].
(:glance, :background)
module Parasha {

    const ITEMS_KEY = "hc";
    const FETCHED_AT_KEY = "hcAt";
    const END_RD_KEY = "hcEnd";
    const SPAN_KEY = "hcSpan";
    const TRIED_KEY = "hcTried";
    const DEFAULT_SPAN_DAYS = 42;
    const MIN_SPAN_DAYS = 14;
    const MAX_AGE_SEC = 72000; // 20 hours
    const TEMPORAL_PERIOD_SEC = 3600;

    // Set by the app when a background sync finishes, so views reload the cache.
    var changed = false;

    // Parasha of the first Shabbat on or after hebrewRd; on a Shabbat without one, that day's holiday.
    function titleFor(hebrewRd as Number) as String? {
        var items = Storage.getValue(ITEMS_KEY);
        if (!(items instanceof Array)) {
            return null;
        }
        var shabbat = HebrewCalendar.shabbatOnOrAfter(hebrewRd);
        var holiday = null;
        for (var i = 0; i < items.size(); i++) {
            var item = items[i] as Array;
            if (item[0] != shabbat) {
                continue;
            }
            var title = item[1] as String;
            if (item[2]) {
                return title;
            }
            // Prefer the holiday itself over "ערב ..." (eve) entries.
            if (holiday == null || (holiday as String).find("ערב ") == 0) {
                holiday = title;
            }
        }
        return holiday;
    }

    function needsRefresh(todayRd as Number) as Boolean {
        var at = Storage.getValue(FETCHED_AT_KEY);
        var endRd = Storage.getValue(END_RD_KEY);
        if (!(at instanceof Number) || !(endRd instanceof Number)) {
            return true;
        }
        return Time.now().value() - at > MAX_AGE_SEC || endRd - todayRd < MIN_SPAN_DAYS;
    }

    // Called from the foreground (app start and after each background run).
    function scheduleSync() as Void {
        if (!(Toybox has :Background)) {
            return;
        }
        var registered = Background.getTemporalEventRegisteredTime();
        if (Storage.getValue(ITEMS_KEY) == null && Storage.getValue(TRIED_KEY) == null) {
            // First run: fetch soon instead of waiting a full period. Later retries are hourly.
            if (!(registered instanceof Time.Moment)) {
                Background.registerForTemporalEvent(Time.now().add(new Time.Duration(300)));
            }
        } else if (!(registered instanceof Time.Duration)) {
            Background.registerForTemporalEvent(new Time.Duration(TEMPORAL_PERIOD_SEC));
        }
    }

    function todayRd() as Number {
        var t = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return HebrewCalendar.fixedFromGregorian(t.year as Number, t.month as Number, t.day as Number);
    }

    // "2026-10-24" -> R.D.
    function rdFromIso(date as String) as Number {
        return HebrewCalendar.fixedFromGregorian(
            date.substring(0, 4).toNumber(), date.substring(5, 7).toNumber(), date.substring(8, 10).toNumber());
    }

    function isoFromInfo(t as Gregorian.Info) as String {
        return (t.year as Number).format("%04d") + "-" + (t.month as Number).format("%02d") + "-" + (t.day as Number).format("%02d");
    }

    // Drops parentheses (bidi would mirror them) and a trailing Gregorian-style year ("ראש השנה 5787").
    function cleanTitle(title as String) as String {
        var chars = title.toCharArray();
        var out = [] as Array<Char>;
        for (var i = 0; i < chars.size(); i++) {
            if (chars[i] != '(' && chars[i] != ')') {
                out.add(chars[i]);
            }
        }
        var end = out.size();
        while (end > 0 && ((out[end - 1] >= '0' && out[end - 1] <= '9') || out[end - 1] == ' ')) {
            end--;
        }
        return StringUtil.charArrayToString(out.slice(0, end));
    }

    // Turns a Hebcal JSON response into cache items. Keeps parashot and holidays only.
    function compact(data as Dictionary) as Array<Array> {
        var out = [] as Array<Array>;
        var items = data["items"];
        if (!(items instanceof Array)) {
            return out;
        }
        for (var i = 0; i < items.size(); i++) {
            var item = items[i];
            if (!(item instanceof Dictionary)) {
                continue;
            }
            var category = item["category"];
            var date = item["date"];
            var hebrew = item["hebrew"];
            if (!(date instanceof String) || !(hebrew instanceof String) || date.length() < 10) {
                continue;
            }
            var isParasha = "parashat".equals(category);
            if (isParasha || "holiday".equals(category)) {
                out.add([rdFromIso(date), cleanTitle(hebrew), isParasha]);
            }
        }
        return out;
    }
}

(:background)
class ParashaService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        Storage.setValue(Parasha.TRIED_KEY, true);
        if (!Parasha.needsRefresh(Parasha.todayRd())) {
            Background.exit(null);
            return;
        }
        var span = Storage.getValue(Parasha.SPAN_KEY);
        if (!(span instanceof Number)) {
            span = Parasha.DEFAULT_SPAN_DAYS;
        }
        var now = Time.now();
        var params = {
            "v" => "1", "cfg" => "json", "i" => "on", "s" => "on", "maj" => "on",
            "min" => "off", "mod" => "off", "nx" => "off", "mf" => "off", "ss" => "off", "leyning" => "off",
            "start" => Parasha.isoFromInfo(Gregorian.info(now, Time.FORMAT_SHORT)),
            "end" => Parasha.isoFromInfo(Gregorian.info(now.add(new Time.Duration(span * 86400)), Time.FORMAT_SHORT))
        };
        Communications.makeWebRequest("https://www.hebcal.com/hebcal", params,
            {:method => Communications.HTTP_REQUEST_METHOD_GET,
             :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON},
            method(:onResponse));
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        var span = Storage.getValue(Parasha.SPAN_KEY);
        if (!(span instanceof Number)) {
            span = Parasha.DEFAULT_SPAN_DAYS;
        }
        var stats = System.getSystemStats();
        System.println("hebcal " + code + " mem " + stats.usedMemory + "/" + stats.totalMemory);
        if (code == 200 && data instanceof Dictionary) {
            var items = Parasha.compact(data);
            System.println("hebcal items " + items.size());
            Storage.setValue(Parasha.ITEMS_KEY, items);
            Storage.setValue(Parasha.FETCHED_AT_KEY, Time.now().value());
            Storage.setValue(Parasha.END_RD_KEY, Parasha.todayRd() + span);
            Background.exit(true);
            return;
        }
        if (code == Communications.NETWORK_RESPONSE_OUT_OF_MEMORY && span > Parasha.MIN_SPAN_DAYS) {
            Storage.setValue(Parasha.SPAN_KEY, span / 2);
        }
        Background.exit(false);
    }
}
