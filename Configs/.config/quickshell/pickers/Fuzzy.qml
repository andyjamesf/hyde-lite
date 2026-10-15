pragma Singleton
import QtQuick
import Quickshell

// Shared fuzzy scoring for the launcher and pickers (one implementation instead of a copy per
// picker). Scores: exact 120 > prefix ~100 > word start ~85 > substring ~70 > subsequence ≤ base.
Singleton {
    id: root

    // Last word-start expression (rebuilt only when the query or separators change). Mutated in
    // place, so no property change is emitted while a binding is being evaluated.
    readonly property var _cache: ({
            "key": null,
            "re": null
        })

    // Score of the lower-case query `q` in `text` (0 = no match).
    //   extraSeps       characters that also start a word, besides space, "-", "_" and "."
    //                   (e.g. "/" for URLs, ":" for game titles)
    //   subBase         best subsequence score (default 50); each gap between letters costs 8
    //   lengthPenalty   subsequence also loses up to 10 points for extra length (default true)
    function score(q, text, extraSeps, subBase, lengthPenalty) {
        if (!text)
            return 0;
        const t = String(text).toLowerCase();
        if (t === q)
            return 120;
        if (t.startsWith(q))
            return 100 - Math.min(20, t.length - q.length);
        const seps = extraSeps ?? "";
        const key = seps + "\u0000" + q;
        if (_cache.key !== key) {
            _cache.re = new RegExp(`(^|[\\s\\-_.${seps.replace(/[\]\\^-]/g, "\\$&")}])${q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`);
            _cache.key = key;
        }
        const word = t.search(_cache.re);
        if (word >= 0)
            return 85 - Math.min(15, word);
        const idx = t.indexOf(q);
        if (idx >= 0)
            return 70 - Math.min(20, idx);
        // Subsequence: every letter in order; each jump costs points.
        let ti = 0, gaps = 0, last = -1;
        for (const ch of q) {
            const found = t.indexOf(ch, ti);
            if (found < 0)
                return 0;
            if (last >= 0 && found > last + 1)
                gaps++;
            last = found;
            ti = found + 1;
        }
        const penalty = lengthPenalty === false ? 0 : Math.min(10, t.length - q.length);
        return Math.max(1, (subBase ?? 50) - gaps * 8 - penalty);
    }

    // `list` ([{ key, … }]) with the item whose key is `current` moved to the front.
    function currentFirst(list, current) {
        return list.filter(it => it.key === current).concat(list.filter(it => it.key !== current));
    }
}
