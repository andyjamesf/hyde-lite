import QtQuick
import qs.bar.components
import qs.bar.services

// Quick notes. A click opens the notes card (modules/notes) on the open note, a right click on the list of all of them.
BarItem {
    id: root

    icon: "sticky_note_2"
    iconColor: Theme.text
    active: ShellState.notesOpen
    tooltip: "Notes\nClick: write · Right click: all notes"
    onClicked: ShellState.toggleNotes("edit")
    onRightClicked: ShellState.toggleNotes("list")
}
