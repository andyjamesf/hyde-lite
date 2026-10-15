import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.modules.controls

// Clock. Click opens the calendar.
BarItem {
    id: root

    readonly property var cfg: Config.widgets.clock

    icon: "schedule"
    iconColor: Theme.primary
    text: Utils.formatDate(clock.date, cfg.format) + (cfg.showDate ? "  ·  " + Utils.formatDate(clock.date, cfg.dateFormat) : "")
    tooltip: Utils.formatDate(clock.date, "dddd, d MMMM")
    popoutName: "calendar"
    popout: Component {
        CalendarView {}
            }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
