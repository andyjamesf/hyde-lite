import QtQuick

// What a plugin is: one file in ~/.config/morphing-island/plugins/<name>.qml whose root is this.
//
// A status icon used to mean editing four core files -- the id into a list, a component and two
// switch statements. A plugin declares the same four things in one place instead, and the core only
// has to ask services/Plugins.qml for anything it does not recognise.
//
// The smallest one that works:
//
//     import QtQuick
//     import qs.components
//     import qs.theme
//
//     IslandPlugin {
//         id: root
//         name: "hello"
//         hint: "Says hello"
//         onActivate: console.log("hello")
//         icon: Component {
//             Text {
//                 text: "H"
//                 color: Theme.icon
//             }
//         }
//     }
//
// Then add "hello" to StatusPillConfig.icons where you want it in the row. Nothing else.
QtObject {
    id: root

    // Id of the plugin, and the id used in StatusPillConfig.icons. Taken from the file name when it
    // is left empty, so the two cannot disagree.
    property string name: ""

    // Whether the icon takes a place in the row at all. A hidden icon leaves no gap, so this is for
    // things that have nothing to say yet -- no VPN configured, no updates waiting.
    property bool available: true

    // One line shown when the pointer rests on the icon, or "" for none. Two lines are allowed:
    // the first is read as the title.
    property string hint: ""

    // The icon itself. The component is given no properties: read the services it needs directly,
    // the way the built-in icons read Audio or Battery.
    property Component icon: null

    // A left click on the icon. `button` is Qt.LeftButton or Qt.MiddleButton; right click opens the
    // menu instead and never arrives here.
    signal activate(int button)

    // Called once after loading, for a plugin that has something to start.
    signal started
}
