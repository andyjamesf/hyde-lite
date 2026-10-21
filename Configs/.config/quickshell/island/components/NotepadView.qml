pragma ComponentBehavior: Bound

import QtQuick
import qs.island.config
import qs.island.core
import qs.island.services
import qs.island.theme

// The notepad: one plain page that is always there, saved as you type.
//
// No documents, no tabs, no titles. The thing a scratch page is for is being open in one keystroke
// and holding whatever you paste into it, and every extra choice gets in the way of that. The file
// behind it is <XDG_DATA_HOME>/morphing-island/notes.md (services/Notepad.qml), so an editor can
// have the same page open at the same time -- it is watched, and an outside change shows up here.
//
// Size, text size and the save delay: config/NotepadConfig.qml.
FocusScope {
    id: root

    readonly property int pad: 14
    readonly property int textSize: NotepadConfig.fontSize > 0 ? NotepadConfig.fontSize : Appearance.fontSize

    implicitWidth: NotepadConfig.width
    implicitHeight: NotepadConfig.height

    focus: true

    // The island does not hand the focus to its keyboard modes, so the page takes it and puts it
    // straight in the text: opening it and typing has to work without a click in between.
    Component.onCompleted: editor.forceActiveFocus()
    // Closing must not lose the last few characters typed inside the debounce window.
    Component.onDestruction: Notepad.flush()

    Text {
        id: title

        x: root.pad
        y: root.pad - 2
        text: "Notes"
        color: Theme.dim
        font.family: Appearance.font
        font.pixelSize: Appearance.fontSize - 1
        font.weight: Font.DemiBold
    }

    // Unsaved changes, while the debounce runs. Small on purpose: it is reassurance, not a warning.
    Rectangle {
        anchors.verticalCenter: title.verticalCenter
        x: title.x + title.width + 7
        width: 5
        height: 5
        radius: 2.5
        color: Theme.accent
        opacity: Notepad.dirty ? 0.85 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Animations.duration(160)
            }
        }
    }

    Text {
        anchors.verticalCenter: title.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        text: {
            const n = Notepad.text.trim();
            if (n === "")
                return "";
            const words = n.split(/\s+/).length;
            const lines = Notepad.text.split("\n").length;
            return `${words} ${words === 1 ? "word" : "words"} · ${lines} ${lines === 1 ? "line" : "lines"}`;
        }
        color: Qt.alpha(Theme.foreground, 0.35)
        font.family: Appearance.font
        font.pixelSize: Appearance.fontSize - 3
    }

    Flickable {
        id: flick

        x: root.pad
        y: title.y + title.height + 8
        width: root.width - 2 * root.pad
        height: root.height - y - root.pad
        contentWidth: width
        contentHeight: editor.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Follows the caret when typing runs past the bottom.
        onContentHeightChanged: if (editor.activeFocus)
            flick.contentY = Math.max(0, Math.min(flick.contentY, flick.contentHeight - flick.height))

        TextEdit {
            id: editor

            width: flick.width
            text: Notepad.text
            onTextChanged: Notepad.set(text)

            // Typing into a TextEdit assigns its `text`, which breaks the binding above for good.
            // Without this, anything that changes the page from outside -- the file edited in an
            // editor, picked up by the watch in services/Notepad.qml -- would never reach the
            // editor again after the first keystroke.
            Connections {
                target: Notepad
                function onTextChanged() {
                    if (editor.text !== Notepad.text)
                        editor.text = Notepad.text;
                }
            }

            color: Theme.foreground
            selectionColor: Qt.alpha(Theme.accent, 0.35)
            selectedTextColor: Theme.foreground
            font.family: NotepadConfig.monospace ? Appearance.monoFont : Appearance.font
            font.pixelSize: root.textSize
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            persistentSelection: true
            // The island is a floating surface, not a document window: the caret should be visible
            // even while the pointer is elsewhere.
            activeFocusOnPress: true

            // Esc belongs to the island (back, then close); without this the editor eats it.
            Keys.onEscapePressed: event => {
                Notepad.flush();
                IslandController.back();
                event.accepted = true;
            }
            Keys.onPressed: event => {
                // Ctrl+S for the habit, even though it saves itself.
                if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
                    Notepad.flush();
                    event.accepted = true;
                }
            }

            // Keeps the caret inside the visible part while typing or moving around.
            onCursorRectangleChanged: {
                const r = editor.cursorRectangle;
                if (r.y < flick.contentY)
                    flick.contentY = Math.max(0, r.y);
                else if (r.y + r.height > flick.contentY + flick.height)
                    flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), r.y + r.height - flick.height);
            }
        }

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: NotepadConfig.placeholder
            visible: Notepad.text === ""
            color: Qt.alpha(Theme.foreground, 0.28)
            font.family: editor.font.family
            font.pixelSize: root.textSize
        }
    }

    // Thin indicator, only while there is more page than fits.
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 4
        width: 3
        radius: 1.5
        color: Qt.alpha(Theme.foreground, 0.22)
        visible: flick.contentHeight > flick.height
        y: flick.y + (flick.contentY / flick.contentHeight) * flick.height
        height: Math.max(24, (flick.height / flick.contentHeight) * flick.height)
    }
}
