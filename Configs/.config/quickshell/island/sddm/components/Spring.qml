import QtQuick

// Critically damped spring, the same as the island's (core/Spring.qml): it heads for `target`
// quickly and stops there without bouncing; a new target starts from the current position and
// velocity.   x(t) = target + (x0 + (v0 + ω·x0)·t)·e^(−ω·t)
QtObject {
    id: s

    property real target: 0
    property real value: 0
    property real velocity: 0
    property real omega: 22
    property real epsilon: 0.1

    onTargetChanged: frames.running = true
    Component.onCompleted: value = target

    property FrameAnimation frames: FrameAnimation {
        running: false
        onTriggered: {
            const dt = Math.min(frameTime, 1 / 30);
            const w = s.omega;
            const x0 = s.value - s.target;
            const v0 = s.velocity;
            const e = Math.exp(-w * dt);
            const x = (x0 + (v0 + w * x0) * dt) * e;
            const v = (v0 - w * (v0 + w * x0) * dt) * e;
            if (Math.abs(x) < s.epsilon && Math.abs(v) < s.epsilon * 10) {
                s.value = s.target;
                s.velocity = 0;
                running = false;
            } else {
                s.value = s.target + x;
                s.velocity = v;
            }
        }
    }
}
