import QtQuick
import qs.config
import qs.services
import qs.theme

// Google Calendar connection (calendars page, and the new-event page while not connected):
// 1. the OAuth client file from Google Cloud Console (see the README, "Google Calendar"),
// 2. Connect: the browser asks for permission. Connected: Disconnect.
Column {
    id: root

    spacing: 8

    Label {
        text: "Google Calendar"
        font.pixelSize: Appearance.fontSize - 1
        font.weight: Font.DemiBold
        color: Theme.dim
    }

    Label {
        width: parent.width
        wrapMode: Text.WordWrap
        font.pixelSize: Appearance.fontSize - 1
        color: Theme.dim
        text: GoogleCalendar.connected ? `Connected · events can be added to ${GoogleCalendar.calendars.length || "your"} calendar${GoogleCalendar.calendars.length === 1 ? "" : "s"}` : GoogleCalendar.hasClient ? "Step 2: connect, then allow access in the browser." : "Step 1: create a Google OAuth client (Desktop app) and choose the file Google gives you (client_secret_….json). How: the island's README, \"Google Calendar\"."
    }

    Row {
        spacing: 8

        CcTextButton {
            visible: !GoogleCalendar.connected
            implicitHeight: 30
            text: GoogleCalendar.hasClient ? "Change client file…" : "Choose client file…"
            primary: !GoogleCalendar.hasClient
            onClicked: GoogleCalendar.chooseClient()
        }
        CcTextButton {
            visible: GoogleCalendar.hasClient && !GoogleCalendar.connected
            implicitHeight: 30
            text: GoogleCalendar.busy ? "Waiting for the browser…" : "Connect"
            primary: true
            enabled: !GoogleCalendar.busy
            onClicked: GoogleCalendar.connect()
        }
        CcTextButton {
            visible: GoogleCalendar.connected
            implicitHeight: 30
            text: "Disconnect"
            onClicked: GoogleCalendar.disconnect()
        }
    }

    Label {
        visible: GoogleCalendar.error !== ""
        width: parent.width
        wrapMode: Text.WordWrap
        text: GoogleCalendar.error
        font.pixelSize: Appearance.fontSize - 2
        color: Theme.danger
    }
}
