pragma Singleton
import QtQuick
import Quickshell

// Shared control center state, for IPC tests without a mouse: the open view writes a summary of
// what it shows here (current page, counts).
Singleton {
    // "page=<page> …" while the control center is open; "closed" otherwise.
    property string status: "closed"
}
