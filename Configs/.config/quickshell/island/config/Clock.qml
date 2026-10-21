pragma Singleton
import QtQuick
import Quickshell
import qs.island.services

// Time and date formats (pill, expanded island, lock screen). Formats use Qt's date/time syntax:
// https://doc.qt.io/qt-6/qml-qtqml-qt.html#formatDateTime-method
//   HH = hour 00–23, hh = hour 01–12 with AP (AM/PM), mm = minutes, ss = seconds,
//   d/dd = day, ddd/dddd = short/long weekday, M/MM = month number, MMM/MMMM = short/long month.
Singleton {
    // Time in the pill, the expanded island and the lock screen. Default "HH:mm" (e.g. "13:37");
    // "h:mm AP" is the 12-hour form (Settings screen: "12-hour clock", Prefs key clock.hour12).
    readonly property string timeFormat: Prefs.get("clock.hour12", false) ? "h:mm AP" : "HH:mm"
    // Short date under the time in the expanded island. Default "ddd d MMM" (e.g. "Thu 25 Sep").
    readonly property string dateFormat: "ddd d MMM"
    // Long date on the lock screen. Default "dddd, d MMMM" (e.g. "Thursday, 25 September").
    readonly property string longDateFormat: "dddd, d MMMM"
    // Locale for weekday/month names and AM/PM (e.g. "en_US", "en_GB", "pt_PT"). Default "en_US"
    // (the format strings above decide the order, so dates still read "Thu 25 Sep"; en_GB would
    // abbreviate September as "Sept").
    readonly property string locale: "en_US"

    readonly property var qtLocale: Qt.locale(locale)
}
