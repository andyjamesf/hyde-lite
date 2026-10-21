import QtQuick
import qs.bar.services

// Loads a bar widget by the id used in config.json.
Loader {
    id: root

    required property string name
    required property var bar

    readonly property var files: BarWidgets.files

    source: files[name] ? Qt.resolvedUrl(`widgets/${files[name]}Widget.qml`) : ""
    // Does the widget want to appear? (read by the Island, which can't use `visible`: that also depends
    // on the Island itself, and an island that started empty would never show up.)
    readonly property bool wanted: status === Loader.Ready && (item.shown ?? true)
    visible: wanted
    asynchronous: false

    onLoaded: {
        if ("bar" in item)
            item.bar = Qt.binding(() => root.bar);
        if ("ipcName" in item)
            item.ipcName = root.name;
    }

    Component.onCompleted: if (!files[name])
        console.warn(`config.json: unknown widget "${name}"`)
}
