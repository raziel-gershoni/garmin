import Toybox.Activity;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.System;
import Toybox.Time;

// Sunrise/sunset in seconds since local midnight.
// Source order: the watch's own values (watch faces only, via complications), then a
// NOAA calculation for the last known position, then Jerusalem.
(:glance)
module SunTimes {

    const JERUSALEM = [31.778d, 35.235d];
    const LOCATION_KEY = "loc";
    const LOCATION_REFRESH_SEC = 900;

    var _locationReadAt = 0;
    var _location = null as Array<Double>?;
    var _noaaKey = "";
    var _noaa = null as Array<Number>?;

    // [sunrise, sunset] for today, or null (polar day/night).
    // fromWatch: [sunrise, sunset] reported by the watch itself; either may be null.
    function today(civilRd as Number, fromWatch as Array?) as Array<Number>? {
        if (fromWatch != null && fromWatch[0] instanceof Number && fromWatch[1] instanceof Number) {
            return fromWatch as Array<Number>;
        }
        var loc = location();
        var tz = System.getClockTime().timeZoneOffset;
        var key = civilRd + ":" + loc[0].format("%.2f") + ":" + loc[1].format("%.2f") + ":" + tz;
        if (!key.equals(_noaaKey)) {
            _noaa = noaa(civilRd, loc[0], loc[1], tz);
            _noaaKey = key;
        }
        return _noaa;
    }

    // Last known [lat, lon] in degrees. Never starts GPS; re-reads at most every 15 minutes.
    function location() as Array<Double> {
        var now = Time.now().value();
        if (now - _locationReadAt >= LOCATION_REFRESH_SEC) {
            _locationReadAt = now;
            var fresh = readPosition();
            if (fresh != null) {
                Storage.setValue(LOCATION_KEY, fresh);
                _location = fresh;
            }
        }
        if (_location == null) {
            var stored = Storage.getValue(LOCATION_KEY);
            _location = (stored instanceof Array && stored.size() == 2) ? stored as Array<Double> : JERUSALEM as Array<Double>;
        }
        return _location as Array<Double>;
    }

    function readPosition() as Array<Double>? {
        var loc = null;
        var info = Position.getInfo();
        if (info != null && info.accuracy != Position.QUALITY_NOT_AVAILABLE) {
            loc = info.position;
        }
        if (loc == null && Toybox has :Activity) {
            var act = Activity.getActivityInfo();
            if (act != null) {
                loc = act.currentLocation;
            }
        }
        if (loc == null) {
            return null;
        }
        var deg = loc.toDegrees();
        var lat = deg[0].toDouble();
        var lon = deg[1].toDouble();
        // An unset position reads as roughly (180, 180).
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180 || (lat == 0 && lon == 0)) {
            return null;
        }
        return [lat, lon];
    }

    // NOAA-style sunrise equation (about +/-1 minute). R.D. date, degrees (east positive),
    // UTC offset in seconds. Returns [sunrise, sunset] seconds since local midnight, or null.
    function noaa(rd as Number, lat as Double, lon as Double, tzOffset as Number) as Array<Number>? {
        var n = (rd - 730120).toDouble(); // days since 2000-01-01 (J2000 date)
        var jStar = n - lon / 360.0d;
        var m = mod360(357.5291d + 0.98560028d * jStar);
        var mRad = Math.toRadians(m);
        var c = 1.9148d * Math.sin(mRad) + 0.02d * Math.sin(2 * mRad) + 0.0003d * Math.sin(3 * mRad);
        var lambda = Math.toRadians(mod360(m + c + 282.9372d));
        var transit = jStar + 0.0053d * Math.sin(mRad) - 0.0069d * Math.sin(2 * lambda);
        var sinDecl = Math.sin(lambda) * Math.sin(Math.toRadians(23.4397d));
        var cosDecl = Math.sqrt(1 - sinDecl * sinDecl);
        var latRad = Math.toRadians(lat);
        var cosW = (Math.sin(Math.toRadians(-0.833d)) - Math.sin(latRad) * sinDecl) / (Math.cos(latRad) * cosDecl);
        if (cosW < -1 || cosW > 1) {
            return null;
        }
        var w = Math.toDegrees(Math.acos(cosW)) / 360.0d;
        // transit is in days from J2000 noon; the local date's UTC midnight is n - 0.5.
        var noonUtc = (transit - n + 0.5d) * 86400;
        var halfDay = w * 86400;
        return [daySeconds(noonUtc - halfDay + tzOffset), daySeconds(noonUtc + halfDay + tzOffset)];
    }

    function mod360(x as Double) as Double {
        var r = x - (x / 360.0d).toLong() * 360.0d;
        return r < 0 ? r + 360.0d : r;
    }

    function daySeconds(s as Double) as Number {
        var n = (s + 0.5d).toLong() % 86400;
        return (n < 0 ? n + 86400 : n).toNumber();
    }

    // "06:21" (24h) or "6:21" (12h) following the watch setting.
    function format(seconds as Number?) as String {
        if (seconds == null) {
            return "--:--";
        }
        var h = seconds / 3600;
        var m = (seconds % 3600) / 60;
        if (!System.getDeviceSettings().is24Hour) {
            h = h % 12;
            if (h == 0) {
                h = 12;
            }
            return h.format("%d") + ":" + m.format("%02d");
        }
        return h.format("%02d") + ":" + m.format("%02d");
    }
}
