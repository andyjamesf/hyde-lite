pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.island.config

// Weather from Open-Meteo: no account, no key, and nothing sent but the place from
// config/WeatherConfig.qml. Two requests: the place is turned into coordinates once per session
// (skipped when the config gives coordinates), then the forecast on a timer.
//
// curl rather than a Quickshell HTTP client, because there isn't one; argv rather than a shell, so
// a place name with a space or a quote in it is just an argument.
Singleton {
    id: root

    // { temp, feels, humidity, wind, code, isDay } or null until the first answer.
    property var current: null
    // [{ time, temp, code }] from the next whole hour.
    property var hours: []
    // [{ date, min, max, code }] from today.
    property var days: []
    // "Sardoal, Portugal" once resolved, or the configured place until then.
    property string place: WeatherConfig.place
    // The place came from the IP rather than from the config: said out loud in the view, because an
    // IP points at the operator's node and can be a long way off.
    property bool locatedByIp: false
    property real latitude: 0
    property real longitude: 0
    // Last failure, "" when the last request worked. Shown in the view instead of stale numbers
    // being passed off as current.
    property string error: ""
    property bool loading: false
    // The icon only takes a place in the bar once there is something to show.
    readonly property bool available: WeatherConfig.enabled && root.current !== null

    readonly property string unitSuffix: WeatherConfig.temperatureUnit === "fahrenheit" ? "°F" : "°C"
    readonly property string windSuffix: ({
            "kmh": "km/h",
            "mph": "mph",
            "ms": "m/s",
            "kn": "kn"
        })[WeatherConfig.windUnit] ?? "km/h"

    // --- WMO weather codes ------------------------------------------------------------------------
    // The forecast speaks in WMO codes; these turn one into words and a glyph. Grouped the way the
    // codes are grouped: every drizzle is one entry, every shower another.
    function describe(code) {
        const c = Number(code);
        if (c === 0)
            return "Clear";
        if (c === 1)
            return "Mainly clear";
        if (c === 2)
            return "Partly cloudy";
        if (c === 3)
            return "Overcast";
        if (c === 45 || c === 48)
            return "Fog";
        if (c >= 51 && c <= 57)
            return "Drizzle";
        if (c >= 61 && c <= 67)
            return "Rain";
        if (c >= 71 && c <= 77)
            return "Snow";
        if (c >= 80 && c <= 82)
            return "Showers";
        if (c === 85 || c === 86)
            return "Snow showers";
        if (c === 95)
            return "Thunderstorm";
        if (c === 96 || c === 99)
            return "Thunderstorm with hail";
        return "—";
    }

    // Nerd Font (Material Design) glyph for a code. `isDay` only changes the clear-sky one: a sun
    // at three in the morning reads as wrong even when the sky really is clear.
    function glyph(code, isDay) {
        const c = Number(code);
        const day = isDay === undefined ? true : !!isDay;
        if (c === 0 || c === 1)
            return day ? "\u{F0599}" : "\u{F0594}";
        if (c === 2)
            return day ? "\u{F0595}" : "\u{F0F31}";
        if (c === 3)
            return "\u{F0590}";
        if (c === 45 || c === 48)
            return "\u{F0591}";
        if (c >= 51 && c <= 57)
            return "\u{F0597}";
        if (c >= 61 && c <= 67)
            return "\u{F0596}";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86)
            return "\u{F0598}";
        if (c >= 80 && c <= 82)
            return "\u{F0597}";
        if (c >= 95)
            return "\u{F067E}";
        return "\u{F0590}";
    }

    // --- requests ---------------------------------------------------------------------------------

    // Coordinates beat a name, a name beats the IP: the more exact the answer, the less there is to
    // get wrong, and the less leaves the machine.
    function refresh() {
        if (!WeatherConfig.enabled)
            return;
        if (WeatherConfig.latitude !== 0 || WeatherConfig.longitude !== 0) {
            root.latitude = WeatherConfig.latitude;
            root.longitude = WeatherConfig.longitude;
            root.place = WeatherConfig.place !== "" ? WeatherConfig.place : `${WeatherConfig.latitude}, ${WeatherConfig.longitude}`;
            root.locatedByIp = false;
            root.fetchForecast();
            return;
        }
        // Already resolved this session: no second lookup.
        if (root.latitude !== 0 || root.longitude !== 0) {
            root.fetchForecast();
            return;
        }
        root.loading = true;
        if (WeatherConfig.place !== "") {
            const args = ["curl", "-sS", "--max-time", "15", "--get", "--data-urlencode", `name=${WeatherConfig.place}`, "--data-urlencode", "count=1", "--data-urlencode", "format=json"];
            if (WeatherConfig.countryCode !== "")
                args.push("--data-urlencode", `countryCode=${WeatherConfig.countryCode}`);
            args.push("https://geocoding-api.open-meteo.com/v1/search");
            geocoder.command = args;
            geocoder.running = true;
            return;
        }
        if (!WeatherConfig.locateByIp) {
            root._fail("no place set, and locating by IP is off");
            return;
        }
        locator.command = ["curl", "-sS", "--max-time", "15", "https://get.geojs.io/v1/ip/geo.json"];
        locator.running = true;
    }

    function fetchForecast() {
        root.loading = true;
        const q = [`latitude=${root.latitude}`, `longitude=${root.longitude}`, "current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day", "hourly=temperature_2m,weather_code", "daily=weather_code,temperature_2m_max,temperature_2m_min", "timezone=auto", `forecast_days=${Math.max(1, Math.min(7, WeatherConfig.daysShown))}`, `temperature_unit=${WeatherConfig.temperatureUnit}`, `wind_speed_unit=${WeatherConfig.windUnit}`].join("&");
        forecaster.command = ["curl", "-sS", "--max-time", "20", `https://api.open-meteo.com/v1/forecast?${q}`];
        forecaster.running = true;
    }

    function _fail(what) {
        root.loading = false;
        root.error = what;
        Errors.report("weather", what);
    }

    // Where this IP looks like it is. Approximate by nature: see config/WeatherConfig.qml.
    Process {
        id: locator
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    const lat = Number(d.latitude), lon = Number(d.longitude);
                    if (!isFinite(lat) || !isFinite(lon) || (lat === 0 && lon === 0)) {
                        root._fail("the IP lookup gave no coordinates");
                        return;
                    }
                    root.latitude = lat;
                    root.longitude = lon;
                    root.place = d.city ? (d.country ? `${d.city}, ${d.country}` : d.city) : "Here";
                    root.locatedByIp = true;
                    root.fetchForecast();
                } catch (e) {
                    root._fail(`the IP lookup could not be read: ${e}`);
                }
            }
        }
        onExited: code => {
            if (code !== 0)
                root._fail(`the IP lookup failed (curl exit ${code})`);
        }
    }

    Process {
        id: geocoder
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = (JSON.parse(text).results ?? [])[0];
                    if (!r) {
                        root._fail(`no place called "${WeatherConfig.place}"`);
                        return;
                    }
                    root.latitude = r.latitude;
                    root.longitude = r.longitude;
                    root.place = r.country ? `${r.name}, ${r.country}` : r.name;
                    root.locatedByIp = false;
                    root.fetchForecast();
                } catch (e) {
                    root._fail(`the place lookup could not be read: ${e}`);
                }
            }
        }
        onExited: code => {
            if (code !== 0)
                root._fail(`the place lookup failed (curl exit ${code})`);
        }
    }

    Process {
        id: forecaster
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    const c = d.current ?? {};
                    // A refusal from Open-Meteo is valid JSON with no `current` in it, and an
                    // answer that parses is not the same as an answer that is usable: without this
                    // the fields came through undefined and the bar drew "NaN°". The last good
                    // reading is kept instead, and the reason is said out loud.
                    if (typeof c.temperature_2m !== "number" || !isFinite(c.temperature_2m)) {
                        root._fail(d.reason ? `the forecast was refused: ${d.reason}` : "the forecast arrived without a current temperature");
                        return;
                    }
                    root.current = {
                        "temp": c.temperature_2m,
                        "feels": c.apparent_temperature,
                        "humidity": c.relative_humidity_2m,
                        "wind": c.wind_speed_10m,
                        "code": c.weather_code,
                        "isDay": c.is_day === 1
                    };

                    // The hourly series starts at midnight today, so it is mostly in the past.
                    // It starts at the hour being lived, not at the next one: the reading you want
                    // first is the one for now, and the next whole hour has not arrived yet.
                    const now = new Date();
                    const thisHour = new Date(now);
                    thisHour.setMinutes(0, 0, 0);
                    const times = d.hourly?.time ?? [];
                    const temps = d.hourly?.temperature_2m ?? [];
                    const codes = d.hourly?.weather_code ?? [];
                    const out = [];
                    for (let i = 0; i < times.length && out.length < Math.max(0, Math.min(24, WeatherConfig.hoursShown)); ++i) {
                        const t = new Date(times[i]);
                        if (t < thisHour)
                            continue;
                        out.push({
                            "time": t,
                            "temp": temps[i],
                            "code": codes[i]
                        });
                    }
                    root.hours = out;

                    const dt = d.daily?.time ?? [];
                    const dmin = d.daily?.temperature_2m_min ?? [];
                    const dmax = d.daily?.temperature_2m_max ?? [];
                    const dcode = d.daily?.weather_code ?? [];
                    const dayList = [];
                    for (let i = 0; i < dt.length; ++i)
                        dayList.push({
                            "date": new Date(dt[i]),
                            "min": dmin[i],
                            "max": dmax[i],
                            "code": dcode[i]
                        });
                    root.days = dayList;

                    root.error = "";
                    root.loading = false;
                } catch (e) {
                    root._fail(`the forecast could not be read: ${e}`);
                }
            }
        }
        onExited: code => {
            if (code !== 0)
                root._fail(`the forecast request failed (curl exit ${code})`);
        }
    }

    // First reading a moment after startup, so it does not race the network coming up, then on the
    // configured period. Open-Meteo itself only moves about every 15 minutes.
    Timer {
        running: WeatherConfig.enabled
        interval: 4000
        onTriggered: root.refresh()
    }

    Timer {
        running: WeatherConfig.enabled
        repeat: true
        interval: Math.max(10, Math.min(240, WeatherConfig.refreshMinutes)) * 60000
        onTriggered: root.refresh()
    }
}
