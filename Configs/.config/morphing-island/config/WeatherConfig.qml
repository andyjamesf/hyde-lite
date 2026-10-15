pragma Singleton
import QtQuick
import Quickshell

// Weather (the "weather" status icon and IslandState.weather, components/WeatherView.qml).
//
// The numbers come from Open-Meteo, which needs no account and no key.
Singleton {
    // false hides the icon and stops the requests.
    readonly property bool enabled: true

    // Where the weather is for. Three ways, and the first one that is filled in wins:
    //
    //   1. `latitude` and `longitude`, when either is not 0: used as given, nothing is looked up.
    //   2. `place`, when not empty: looked up once per session.
    //   3. neither: the IP is asked where it is, if `locateByIp` allows it.
    //
    // Only the place name leaves the machine in case 2, and nothing at all in case 1.
    readonly property string place: "Sardoal"
    // Two-letter country for the name lookup, to settle a name that exists in several places:
    // "Sardoal" alone also finds one in the Porto district and one in Brazil. "" = no filter.
    readonly property string countryCode: "PT"
    readonly property real latitude: 0
    readonly property real longitude: 0

    // Used only when `place` is empty and no coordinates are set: asks a geolocation service where
    // this IP is, which reveals the IP to that service (get.geojs.io).
    //
    // Worth knowing before relying on it: an IP locates the operator's node, not you. Asked from
    // this machine it answers Coimbra while the machine is in Sardoal -- 80 km away, and 24.7°
    // against 21.8° at the moment it was measured. Naming the place is both more private and more
    // accurate; the IP is for a machine that moves and whose place nobody keeps up to date.
    readonly property bool locateByIp: true

    // "celsius" or "fahrenheit". Default "celsius".
    readonly property string temperatureUnit: "celsius"
    // "kmh", "mph", "ms" or "kn". Default "kmh".
    readonly property string windUnit: "kmh"
    // Minutes between refreshes. The data itself updates about every 15 minutes, so below that is
    // only traffic. 10-240, default 30.
    readonly property int refreshMinutes: 30
    // Hours shown in the strip, from the next whole hour. 0-24, default 8.
    readonly property int hoursShown: 8
    // Days shown under it, today included. 1-7, default 5.
    readonly property int daysShown: 5
    // Show the temperature next to the icon in the bar, not only the symbol. Default true.
    readonly property bool showTemperatureInBar: true
}
