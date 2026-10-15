pragma Singleton
import QtQuick
import Quickshell
import qs.config

// System time. The clock wakes up every second (not every minute): the timer uses a clock that
// stops during suspend, so with minute precision the pill kept the pre-suspend time until "its" next
// minute, sometimes much later. The strings only change when the formatted text changes, so the
// text is not redrawn every second. Formats and locale: config/Clock.qml.
Singleton {
    readonly property date now: clock.date
    readonly property string time: clock.date.toLocaleTimeString(Clock.qtLocale, Clock.timeFormat)
    readonly property string date: clock.date.toLocaleDateString(Clock.qtLocale, Clock.dateFormat)
    readonly property string longDate: clock.date.toLocaleDateString(Clock.qtLocale, Clock.longDateFormat)

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
