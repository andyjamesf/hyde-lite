import qs.components
import qs.services

// Standalone cava visualizer (the media widget can also show it embedded).
BarItem {
    shown: stream.text !== ""
    text: stream.text
    textColor: Theme.primary
    fontFamily: Config.appearance.monoFont

    JsonStream {
        id: stream
        exec: "hyde-shell cava.py waybar --json"
    }
}
