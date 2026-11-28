pragma Singleton
import QtQuick

// Small view transforms and discontinuity-aware graph sampling for CalculatorWide.
QtObject {
    function sample(fn, view, width) {
        const segments = [];
        let segment = [];
        const count = Math.max(2, Math.min(1600, Math.floor(width)));
        const spanY = view.yMax - view.yMin;
        let previous = null;
        for (let i = 0; i <= count; i++) {
            const x = view.xMin + (view.xMax - view.xMin) * i / count;
            let y = null;
            try { y = fn(x); } catch (e) { y = null; }
            const good = typeof y === "number" && isFinite(y) && y >= view.yMin - spanY && y <= view.yMax + spanY;
            let jump = false;
            // A break is a step that stays however narrow the interval gets: follow the half with the larger
            // change. Steps too small to be seen are not examined (that also leaves the peaks alone).
            const step = previous !== null && good ? Math.abs(y - previous[1]) : 0;
            if (step > spanY * 0.005) {
                let leftX = previous[0];
                let leftY = previous[1];
                let rightX = x;
                let rightY = y;
                for (let depth = 0; depth < 10 && !jump; depth++) {
                    const midX = (leftX + rightX) / 2;
                    let midY = null;
                    try { midY = fn(midX); } catch (e) { midY = null; }
                    if (typeof midY !== "number" || !Number.isFinite(midY))
                        jump = true;
                    else if (Math.abs(midY - leftY) > Math.abs(rightY - midY)) { rightX = midX; rightY = midY; }
                    else { leftX = midX; leftY = midY; }
                }
                jump = jump || Math.abs(rightY - leftY) > step * 0.5;
            }
            if (!good || jump) {
                if (segment.length > 1) segments.push(segment);
                segment = [];
            }
            if (good) segment.push([x, y]);
            previous = good ? [x, y] : null;
        }
        if (segment.length > 1) segments.push(segment);
        return segments;
    }
    function zoom(view, factor, cx, cy) {
        return { xMin: cx + (view.xMin - cx) * factor, xMax: cx + (view.xMax - cx) * factor,
                 yMin: cy + (view.yMin - cy) * factor, yMax: cy + (view.yMax - cy) * factor };
    }
    function pan(view, dxFraction, dyFraction) {
        const dx = (view.xMax - view.xMin) * dxFraction;
        const dy = (view.yMax - view.yMin) * dyFraction;
        return { xMin: view.xMin + dx, xMax: view.xMax + dx, yMin: view.yMin + dy, yMax: view.yMax + dy };
    }
    function ticks(min, max, count) {
        const raw = (max - min) / Math.max(1, count - 1);
        const power = Math.pow(10, Math.floor(Math.log10(raw)));
        const scaled = raw / power;
        const step = (scaled <= 1 ? 1 : scaled <= 2 ? 2 : scaled <= 5 ? 5 : 10) * power;
        const first = Math.ceil(min / step) * step;
        const out = [];
        for (let value = first; value <= max + step * 1e-10; value += step) out.push(Number(value.toPrecision(12)));
        return out;
    }
}
