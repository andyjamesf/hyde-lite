import QtQuick
import qs.services

// NumberAnimation with the shell's default duration and easing curve.
NumberAnimation {
    duration: Anim.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Anim.standard
}
