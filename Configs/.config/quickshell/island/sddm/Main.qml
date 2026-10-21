import QtQuick
import QtQuick.Effects
import "components"

// Login screen (SDDM) of the Morphing Island, a copy of the island's lock screen
// (core/LockSurface.qml): the blurred wallpaper with a veil, and the clock pill at the top that
// grows with the island's springs into the card at the centre: time, date, avatar, name and the
// password pill. Below the card, a small pill with the session button (a menu of sessions) and
// suspend / restart / power off. Everything but the background follows the monitor's scale.
//
// Colours, fonts, sizes and the wallpaper come from theme.conf.user, written by the island
// (scripts/sddm.py sync) so this screen always matches it; theme.conf holds the defaults. Straight
// after a clean install that file holds only the bundled font paths (sddm.py install writes those,
// as no island is running yet) and the first sync adds the rest.
// Keys: Enter logs in, Esc clears, Up/Down change the user, Tab opens the sessions.
Rectangle {
    id: root

    width: 1920
    height: 1080
    color: theme.background

    // One greeter window per screen; the card sits on the primary one.
    readonly property bool isPrimary: typeof primaryScreen === "undefined" || primaryScreen

    function cfg(key, fallback) {
        const v = config[key];
        return v === undefined || v === null || String(v) === "" ? fallback : v;
    }
    function num(key, fallback) {
        const v = Number(cfg(key, fallback));
        return isNaN(v) ? fallback : v;
    }

    QtObject {
        id: theme
        property color background: root.cfg("background", "#15161e")
        property color surface: root.cfg("surface", "#1f2130")
        property color foreground: root.cfg("foreground", "#e6e6f0")
        property color accent: root.cfg("accent", "#8ab4f8")
        property color accentContent: root.cfg("accentContent", "#10131a")
        property color dim: root.cfg("dim", "#a0a3b5")
        property color faint: root.cfg("faint", "#6c6f85")
        property color border: root.cfg("border", "#2c2f42")
        property color shadow: root.cfg("shadow", "#80000000")
        property color danger: root.cfg("danger", "#f28b82")
        property color hover: root.cfg("hover", "#1affffff")
        property real islandOpacity: root.num("islandOpacity", 0.94)
        property string font: interFont.status === FontLoader.Ready ? interFont.name : root.cfg("font", "Inter")
        property string iconFont: iconFontLoader.status === FontLoader.Ready ? iconFontLoader.name : root.cfg("iconFont", "JetBrainsMono Nerd Font")
        property int fontSize: root.num("fontSize", 13)
        property real springOmega: root.num("springOmega", 22)
    }

    // The island's font, shipped with the theme (SDDM's user cannot read ~/.local/share/fonts).
    FontLoader {
        id: interFont
        source: root.cfg("fontFile", "") !== "" ? Qt.resolvedUrl(root.cfg("fontFile", "")) : ""
    }

    // The icon font (a Nerd Font), shipped the same way: it lives under ~/.local/share/fonts, which SDDM's user
    // cannot read, so without this copy every icon is an empty box.
    FontLoader {
        id: iconFontLoader
        source: root.cfg("iconFontFile", "") !== "" ? Qt.resolvedUrl(root.cfg("iconFontFile", "")) : ""
    }

    // The desktop's scale (Hyprland's monitor scale, written by the sync): SDDM draws at 1×, so the
    // island is scaled up to look the same size as the lock screen.
    readonly property real uiScale: Math.max(0.5, num("scale", 1))
    readonly property int pillHeight: num("pillHeight", 36)
    readonly property int pillTop: num("pillTopMargin", 6)
    readonly property int pillMinWidth: num("pillMinWidth", 128)
    readonly property int cardWidth: num("cardWidth", 380)
    readonly property int cardPadding: num("cardPadding", 30)
    readonly property int cardRadius: num("cardRadius", 30)
    readonly property real cardOffset: num("cardOffset", -0.04)
    readonly property int clockSize: num("clockSize", 64)
    readonly property int avatarSize: num("avatarSize", 76)
    readonly property var locale: Qt.locale(cfg("locale", "en_US"))

    // ---- Time ----
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
    readonly property string time: locale.toString(now, cfg("timeFormat", "HH:mm"))
    readonly property string longDate: locale.toString(now, cfg("longDateFormat", "dddd, d MMMM"))

    // ---- Users and sessions ----
    Instantiator {
        id: users
        model: userModel
        delegate: QtObject {
            required property string name
            required property string realName
            required property string icon
        }
    }
    Instantiator {
        id: sessions
        model: sessionModel
        delegate: QtObject {
            required property string name
        }
    }
    property int userIndex: Math.max(0, userModel.lastIndex)
    property int sessionIndex: Math.max(0, sessionModel.lastIndex)
    readonly property var user: users.count > 0 ? users.objectAt(Math.min(userIndex, users.count - 1)) : null
    readonly property string userName: user ? user.name : (userModel.lastUser || "")
    readonly property string displayName: user && user.realName !== "" ? user.realName : userName
    readonly property string sessionName: sessions.count > 0 && sessions.objectAt(sessionIndex) ? sessions.objectAt(sessionIndex).name : ""

    function cycleUser(step) {
        if (users.count < 2)
            return;
        userIndex = (userIndex + step + users.count) % users.count;
        error = "";
        field.clear();
    }
    function cycleSession(step) {
        if (sessions.count > 0)
            sessionIndex = (sessionIndex + step + sessions.count) % sessions.count;
    }

    // ---- Login ----
    property bool busy: false
    property bool leaving: false
    property string error: ""

    function login(secret) {
        busy = true;
        error = "";
        sddm.login(userName, secret, sessionIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            root.error = "Wrong password";
            field.clear();
            field.shake();
            field.focusField();
            errorTimer.restart();
        }
        function onLoginSucceeded() {
            root.leaving = true;
        }
    }
    Timer {
        id: errorTimer
        interval: 3500
        onTriggered: root.error = ""
    }

    // ---- Background: sharp wallpaper, then the blurred one with a veil ----
    Image {
        id: sharp
        anchors.fill: parent
        source: Qt.resolvedUrl(root.cfg("wallpaper", "background.png"))
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root.width
        sourceSize.height: root.height
        asynchronous: true
    }

    Item {
        anchors.fill: parent
        opacity: root.leaving ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: 420
                easing.type: Easing.OutCubic
            }
        }

        Image {
            id: blur
            anchors.fill: parent
            visible: status === Image.Ready
            source: Qt.resolvedUrl(root.cfg("wallpaperBlur", "background-blur.png"))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        // Without the blurred copy: blur the sharp one here.
        Loader {
            anchors.fill: parent
            active: blur.status === Image.Error && sharp.status === Image.Ready
            sourceComponent: MultiEffect {
                source: sharp
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1
                blurMax: 64
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(theme.background, root.num("veil", 0.4))
        }
    }

    // ---- The island ----
    property bool ready: false
    readonly property bool expanded: ready && isPrimary && !leaving
    // Entry: "rise" (the clock pill grows into the card) or "fade" (no pill; the card fades in at the
    // centre). The island writes "rise", the bar shell's login sync writes "fade" (theme.conf.user).
    readonly property bool fade: cfg("entry", "rise") === "fade"
    readonly property bool open: fade || expanded
    Timer {
        interval: 350
        running: true
        onTriggered: root.ready = true
    }
    onExpandedChanged: if (expanded)
        focusTimer.restart()
    Timer {
        id: focusTimer
        interval: 60
        onTriggered: field.focusField()
    }

    Keys.onUpPressed: cycleUser(-1)
    Keys.onDownPressed: cycleUser(1)
    Keys.onTabPressed: sessionMenu.open = !sessionMenu.open

    // Everything above the background, in the desktop's logical pixels (scaled by uiScale).
    Item {
    id: ui
    width: root.width / root.uiScale
    height: root.height / root.uiScale
    scale: root.uiScale
    transformOrigin: Item.TopLeft

    MouseArea {
        anchors.fill: parent
        onClicked: {
            sessionMenu.open = false;
            field.focusField();
        }
    }

    Spring {
        id: ys
        omega: theme.springOmega
        target: root.open ? Math.round((ui.height - island.targetHeight) / 2 + ui.height * root.cardOffset) : root.pillTop
    }

    IslandSurface {
        id: island
        theme: theme
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(ys.value)
        opacity: root.fade ? (root.expanded ? 1 : 0) : 1
        targetWidth: root.open ? root.cardWidth : clockPill.implicitWidth
        targetHeight: root.open ? card.implicitHeight : root.pillHeight
        maxRadius: root.cardRadius

        Behavior on opacity {
            NumberAnimation {
                duration: root.expanded ? 180 : 110
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: field.focusField()
        }

        // Collapsed: the island's clock pill.
        Item {
            id: clockPill
            anchors.centerIn: parent
            implicitWidth: Math.max(root.pillMinWidth, pillTime.implicitWidth + 2 * Math.round(root.pillHeight * 0.55))
            implicitHeight: root.pillHeight
            opacity: root.open ? 0 : 1
            scale: root.open ? 0.94 : 1
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: root.expanded ? 110 : 180
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                id: pillTime
                anchors.centerIn: parent
                text: root.time
                color: theme.foreground
                font.family: theme.font
                font.pixelSize: theme.fontSize + 1
                font.weight: Font.DemiBold
            }
        }

        // Open: the card.
        Item {
            id: card
            anchors.centerIn: parent
            implicitWidth: root.cardWidth
            implicitHeight: column.implicitHeight + 2 * root.cardPadding
            width: implicitWidth
            height: implicitHeight
            // The fade entry fades the whole island (island.opacity), not the card inside it.
            opacity: root.fade || root.expanded ? 1 : 0
            scale: root.fade || root.expanded ? 1 : 0.94

            Behavior on opacity {
                NumberAnimation {
                    duration: root.expanded ? 180 : 110
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            Column {
                id: column
                anchors.centerIn: parent

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.time
                    color: theme.foreground
                    font.family: theme.font
                    font.pixelSize: root.clockSize
                    font.weight: Font.Light
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.longDate
                    color: theme.dim
                    font.family: theme.font
                    font.pixelSize: theme.fontSize + 2
                }

                Item {
                    width: 1
                    height: 26
                }

                // Avatar: the island's copy (faces/<user>.png), SDDM's icon, or the initial.
                Rectangle {
                    id: avatarFrame
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.avatarSize
                    height: root.avatarSize
                    radius: width / 2
                    color: theme.surface
                    border.width: 1
                    border.color: theme.border

                    property int sourceIndex: 0
                    readonly property var sources: [Qt.resolvedUrl(`faces/${root.userName}.png`), root.user && root.user.icon ? root.user.icon : ""].filter(s => s !== "")
                    Connections {
                        target: root
                        function onUserNameChanged() {
                            avatarFrame.sourceIndex = 0;
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: avatarImage.status !== Image.Ready
                        text: (root.displayName || "?").charAt(0).toUpperCase()
                        color: theme.accent
                        font.family: theme.font
                        font.pixelSize: Math.round(root.avatarSize * 0.42)
                        font.weight: Font.DemiBold
                    }

                    Image {
                        id: avatarImage
                        anchors.fill: parent
                        visible: false
                        source: avatarFrame.sources[avatarFrame.sourceIndex] ?? ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: root.avatarSize * 2
                        sourceSize.height: root.avatarSize * 2
                        asynchronous: true
                        onStatusChanged: if (status === Image.Error && avatarFrame.sourceIndex < avatarFrame.sources.length - 1)
                            avatarFrame.sourceIndex++
                    }
                    Rectangle {
                        id: avatarMask
                        anchors.fill: parent
                        radius: width / 2
                        visible: false
                        layer.enabled: true
                    }
                    MultiEffect {
                        anchors.fill: parent
                        visible: avatarImage.status === Image.Ready
                        source: avatarImage
                        maskEnabled: true
                        maskSource: avatarMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }
                }

                Item {
                    width: 1
                    height: 10
                }

                // Name; with more than one user, arrows (or Up/Down) change it.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Text {
                        visible: users.count > 1
                        anchors.verticalCenter: parent.verticalCenter
                        text: "‹"
                        color: prevMouse.containsMouse ? theme.foreground : theme.dim
                        font.family: theme.font
                        font.pixelSize: theme.fontSize + 6
                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cycleUser(-1)
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 300)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.displayName
                        color: theme.foreground
                        font.family: theme.font
                        font.pixelSize: theme.fontSize + 3
                        font.weight: Font.DemiBold
                    }
                    Text {
                        visible: users.count > 1
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        color: nextMouse.containsMouse ? theme.foreground : theme.dim
                        font.family: theme.font
                        font.pixelSize: theme.fontSize + 6
                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cycleUser(1)
                        }
                    }
                }

                Item {
                    width: 1
                    height: 18
                }

                PasswordField {
                    id: field
                    theme: theme
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: root.num("fieldWidth", 300)
                    implicitHeight: root.num("fieldHeight", 46)
                    busy: root.busy
                    hasError: root.error !== ""
                    onSubmitted: secret => root.login(secret)
                    onEdited: if (root.error !== "")
                        root.error = ""
                }

                // Error, or a Caps Lock warning.
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 26
                    verticalAlignment: Text.AlignBottom
                    text: root.error !== "" ? root.error : keyboard.capsLock ? "Caps Lock is on" : ""
                    color: root.error !== "" ? theme.danger : theme.dim
                    font.family: theme.font
                    font.pixelSize: theme.fontSize
                    opacity: text !== "" ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }
            }
        }
    }

    // ---- Below the card: session and power ----
    Rectangle {
        id: bottomPill
        anchors.horizontalCenter: parent.horizontalCenter
        y: island.y + island.height + 14
        visible: root.isPrimary
        width: bottomRow.implicitWidth + 2 * 10
        height: root.pillHeight
        radius: height / 2
        color: Qt.alpha(theme.background, theme.islandOpacity)
        border.width: 1
        border.color: theme.border
        opacity: root.expanded ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }

        Row {
            id: bottomRow
            anchors.centerIn: parent
            spacing: 4

            // Sessions: a button that opens the menu above (also Tab).
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: sessions.count > 0
                width: root.pillHeight - 8
                height: width
                radius: width / 2
                color: sessionMenu.open ? theme.hover : sessionMouse.containsMouse ? theme.hover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "\u{F0379}"
                    color: sessionMenu.open ? theme.accent : theme.foreground
                    font.family: theme.iconFont
                    font.pixelSize: theme.fontSize + 3
                }
                MouseArea {
                    id: sessionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sessionMenu.open = !sessionMenu.open
                }
            }

            Repeater {
                model: [
                    {
                        glyph: "\u{F04B2}",
                        show: sddm.canSuspend,
                        run: () => sddm.suspend()
                    },
                    {
                        glyph: "\u{F0709}",
                        show: sddm.canReboot,
                        run: () => sddm.reboot()
                    },
                    {
                        glyph: "\u{F0425}",
                        show: sddm.canPowerOff,
                        run: () => sddm.powerOff()
                    }
                ]

                Rectangle {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    visible: modelData.show
                    width: root.pillHeight - 8
                    height: width
                    radius: width / 2
                    color: powerMouse.pressed ? Qt.darker(theme.hover, 1.2) : powerMouse.containsMouse ? theme.hover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.glyph
                        color: theme.foreground
                        font.family: theme.iconFont
                        font.pixelSize: theme.fontSize + 3
                    }
                    MouseArea {
                        id: powerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.modelData.run()
                    }
                }
            }
        }
    }

    // The sessions (Hyprland, …), under the pill: click one to use it.
    Rectangle {
        id: sessionMenu
        property bool open: false
        anchors.horizontalCenter: parent.horizontalCenter
        y: bottomPill.y + bottomPill.height + 8
        width: Math.max(180, sessionList.implicitWidth + 12)
        height: sessionList.implicitHeight + 12
        radius: Math.min(height / 2, 18)
        color: Qt.alpha(theme.background, theme.islandOpacity)
        border.width: 1
        border.color: theme.border
        opacity: open && root.expanded ? 1 : 0
        visible: opacity > 0.01
        scale: open ? 1 : 0.96

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: sessionList
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: sessions.count

                Rectangle {
                    required property int index
                    readonly property bool chosen: index === root.sessionIndex
                    width: Math.max(168, itemText.implicitWidth + 32)
                    height: root.pillHeight - 6
                    radius: height / 2
                    color: chosen ? theme.accent : itemMouse.containsMouse ? theme.hover : "transparent"

                    Text {
                        id: itemText
                        anchors.centerIn: parent
                        text: sessions.objectAt(parent.index) ? sessions.objectAt(parent.index).name : ""
                        color: parent.chosen ? theme.accentContent : theme.foreground
                        font.family: theme.font
                        font.pixelSize: theme.fontSize
                    }
                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.sessionIndex = parent.index;
                            sessionMenu.open = false;
                            field.focusField();
                        }
                    }
                }
            }
        }
    }
    }
}
