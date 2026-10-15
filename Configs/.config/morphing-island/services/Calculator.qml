pragma Singleton
import QtQuick
import Quickshell

// Launcher calculator: its own recursive-descent parser, no eval — only numbers, operators,
// parentheses and known functions and constants are accepted. A decimal comma works too ("2,5").
//
//   + - * / ^ %(remainder)   ( )   pi e   sqrt abs sin cos tan asin acos atan log(base 10) ln exp
//   round floor ceil      "50 * 20%" or "20% + 1" → percentage (20% = 0.2).
// The constants come from the JavaScript Math object (Math.PI, Math.E); "pi" alone shows pi.
// A lone number ("42") is not an expression: returns null.
Singleton {
    id: root

    readonly property var _functions: ({
            sqrt: Math.sqrt,
            abs: Math.abs,
            sin: Math.sin,
            cos: Math.cos,
            tan: Math.tan,
            asin: Math.asin,
            acos: Math.acos,
            atan: Math.atan,
            log: Math.log10,
            ln: Math.log,
            exp: Math.exp,
            round: Math.round,
            floor: Math.floor,
            ceil: Math.ceil
        })
    readonly property var _constants: ({
            pi: Math.PI,
            e: Math.E
        })

    // Returns the result (a number), or null when `text` is not a valid, complete expression.
    function evaluate(text) {
        const src = String(text ?? "").replace(/,/g, ".").replace(/×/g, "*").replace(/÷/g, "/").trim();
        // Needs a digit (or a constant of two letters or more, so "pi" works on its own; a lone "e" is left to the
        // launcher's search) and at least one operator/function (a lone number does not count).
        if (src === "" || !(/[\d)]/.test(src) || /(^|[^a-z])pi($|[^a-z])/i.test(src)) || !/[+\-*/^%()a-z]/i.test(src.replace(/^[+-]?\d+(\.\d+)?$/, "")))
            return null;
        const tokens = _tokenize(src);
        if (!tokens)
            return null;
        const functions = _functions;
        const constants = _constants;
        let pos = 0;
        const peek = () => tokens[pos];
        const next = () => tokens[pos++];
        // "%" is a percentage at the end, before ")" or before another operator.
        const percentHere = () => {
            const after = tokens[pos + 1];
            return after === undefined || after === ")" || "+-*/^".includes(after);
        };

        // expr := term (('+'|'-') term)*
        function expr() {
            let v = term();
            while (peek() === "+" || peek() === "-") {
                const op = next();
                const r = term();
                v = op === "+" ? v + r : v - r;
            }
            return v;
        }
        // term := power (('*'|'/'|'%') power)*    ('%' here is the remainder)
        function term() {
            let v = power();
            while (peek() === "*" || peek() === "/" || (peek() === "%" && !percentHere())) {
                const op = next();
                const r = power();
                v = op === "*" ? v * r : op === "/" ? v / r : v % r;
            }
            return v;
        }
        // power := unary ('^' power)?   (right-associative)
        function power() {
            const b = unary();
            if (peek() === "^") {
                next();
                return Math.pow(b, power());
            }
            return b;
        }
        // unary := ('-'|'+') unary | postfix
        function unary() {
            if (peek() === "-") {
                next();
                return -unary();
            }
            if (peek() === "+") {
                next();
                return unary();
            }
            return postfix();
        }
        // postfix := primary '%'?
        function postfix() {
            let v = primary();
            if (peek() === "%" && percentHere()) {
                next();
                v /= 100;
            }
            return v;
        }
        function primary() {
            const t = next();
            if (t === undefined)
                throw "end";
            if (typeof t === "number")
                return t;
            if (t === "(") {
                const v = expr();
                if (next() !== ")")
                    throw "parenthesis";
                return v;
            }
            if (Object.prototype.hasOwnProperty.call(constants, t))
                return constants[t];
            if (Object.prototype.hasOwnProperty.call(functions, t)) {
                if (next() !== "(")
                    throw "function";
                const v = expr();
                if (next() !== ")")
                    throw "parenthesis";
                return functions[t](v);
            }
            throw "symbol";
        }

        try {
            const v = expr();
            if (pos !== tokens.length || typeof v !== "number" || !isFinite(v))
                return null;
            return v;
        } catch (e) {
            return null;
        }
    }

    // Tokens: numbers (optional exponent), identifiers and operators; null if junk is left over.
    function _tokenize(src) {
        const out = [];
        const re = /\s*(\d+\.?\d*(?:e[+-]?\d+)?|\.\d+|[a-z]+|[+\-*/^%()])/iy;
        re.lastIndex = 0;
        while (re.lastIndex < src.length) {
            const m = re.exec(src);
            if (!m)
                return /^\s*$/.test(src.slice(re.lastIndex)) ? out : null;
            const t = m[1];
            out.push(/^[\d.]/.test(t) ? parseFloat(t) : t.toLowerCase());
        }
        return out;
    }

    // Readable result: 12 significant digits (removes floating-point noise, e.g. 0.1+0.2 → 0.3),
    // no trailing zeros; scientific notation for extreme values.
    function format(n) {
        if (typeof n !== "number" || !isFinite(n))
            return "";
        if (n === 0)
            return "0";
        const a = Math.abs(n);
        if (a >= 1e15 || a < 1e-9)
            return n.toExponential(6).replace(/\.?0+e/, "e");
        const s = String(Number(n.toPrecision(12)));
        // String() may return scientific notation for small values; force decimal.
        return s.includes("e") ? Number(n.toPrecision(12)).toFixed(12).replace(/\.?0+$/, "") : s;
    }
}
