pragma Singleton
import QtQuick
import Quickshell

// Screenshots (Super+P area, Super+Ctrl+P area on a frozen screen, Super+Alt+P this monitor, Print
// all monitors): the island shows the capture with Copy, Save, Edit and Delete. Taken with HyDE's
// grimblast; edited with satty. (Named ScreenshotConfig because services/Screenshot.qml is the
// service.)
Singleton {
    // Folder the screenshots are saved in ("~/" and "{pictures}" are expanded).
    // Default "{pictures}/Screenshots" (HyDE's folder).
    readonly property string saveDir: "{pictures}/Screenshots"
    // Copy every capture to the clipboard right away. Default true.
    readonly property bool copyAtOnce: true
    // How long the preview stays when left alone, in milliseconds (the pointer over it holds it).
    // Default 6000.
    readonly property int previewMs: 6000
    // What happens when the preview goes away without a choice: "save" or "discard". Default "save".
    readonly property string whenLeft: "save"
    // Width of the preview image in pixels (the height follows the capture, at most 60% of it).
    // Default 300.
    readonly property int previewWidth: 300
    // Editor: the capture file is appended after these arguments, then the save path after
    // `outputFlag`. Default satty.
    readonly property var editor: ["satty", "--copy-command", "wl-copy", "--filename"]
    readonly property string outputFlag: "--output-filename"
}
