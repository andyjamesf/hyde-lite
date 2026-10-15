import QtQuick
import qs.config

// Critically damped spring: it approaches its target quickly and stops there, without bounce or
// oscillation. When the target changes midway, it starts from the current position and velocity
// (physical continuity). Stiffness: Animations.springOmega; disabled animations make it jump.
//   x(t) = target + (x0 + (v0 + ω·x0)·t)·e^(−ω·t)
QtObject {
    id: s

    property real target: 0
    property real value: 0
    property real velocity: 0
    property real omega: Animations.springOmega
    // Stop precision (in units of the value).
    property real epsilon: Animations.springEpsilon

    onTargetChanged: {
        if (!Animations.enabled) {
            value = target;
            velocity = 0;
            return;
        }
        frames.running = true;
    }

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
