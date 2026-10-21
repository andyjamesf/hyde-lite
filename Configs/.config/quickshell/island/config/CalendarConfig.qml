pragma Singleton
import QtQuick
import Quickshell

// Calendar (island mode "calendar"): opened with a click on the clock pill, or on the time in the
// expanded island. A month view, the chosen day's events and your calendars, where new ones are
// added: paste an iCal/webcal link (Google Calendar's "secret address in iCal format", Outlook,
// Nextcloud…) or pick a .ics file.
//
// The list of calendars lives in ~/.local/share/quickshell/calendars.json and the events in
// ~/.cache/quickshell/calendar.json: shared with the HyDE Quickshell shell, outside the dotfiles
// repository (private iCal links give read access to the calendar). Dates and names follow
// Clock.locale. (Named CalendarConfig because services/Calendar.qml is the service.)
Singleton {
    // Width of the calendar, in pixels. Default 380.
    readonly property int width: 380
    // First day of the week: 1 = Monday … 7 = Sunday. Default 1.
    readonly property int firstDayOfWeek: 1
    // Most events listed for the chosen day. Default 6.
    readonly property int maxEvents: 6
    // Calendars are downloaded again every this many minutes (and when the calendar opens, at most
    // every 2 minutes). Default 15.
    readonly property int refreshMinutes: 15
    // New events (Google Calendar): length when only a start time is given, in minutes. Default 60.
    readonly property int defaultDurationMinutes: 60
    // Reminder choices offered in the full form, in minutes before the start (0 = at the start).
    readonly property var reminderChoices: [0, 10, 30, 60, 1440]
    // Colours given to new calendars, in turn.
    readonly property var colors: ["#8ab4f8", "#f28b82", "#81c995", "#fdd663", "#c58af9", "#78d9ec", "#fcad70", "#ff8bcb"]
}
