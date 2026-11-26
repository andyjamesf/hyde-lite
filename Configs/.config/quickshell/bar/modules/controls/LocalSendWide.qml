import QtQuick

// LocalSend filling a tab of the control centre. `LocalSendPanel` itself
// stays fixed-width (320, right for the bar's popout, same as
// BluetoothPanel/WifiPanel): stretched to the tab's own width it left its
// content pinned to the left edge with a wide dead strip on the right,
// which is what looked "disfigured" about it. This only centers the same
// panel in the wider area; it is not the two-column reflow a CalendarWide
// does, which would need designing this content for a wide space on
// purpose rather than just making the narrow one not look broken there.
Item {
    id: root

    implicitHeight: panel.implicitHeight

    LocalSendPanel {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }
}
