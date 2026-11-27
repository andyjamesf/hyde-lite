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
    function evaluate(text, angle) {
        const src = String(text ?? "").replace(/,/g, ".").replace(/×/g, "*").replace(/÷/g, "/").trim();
        // Needs a digit (or a constant of two letters or more, so "pi" works on its own; a lone "e" is left to the
        // launcher's search) and at least one operator/function (a lone number does not count).
        if (src === "" || !(/[\d)]/.test(src) || /(^|[^a-z])pi($|[^a-z])/i.test(src)) || !/[+\-*/^%()a-z]/i.test(src.replace(/^[+-]?\d+(\.\d+)?$/, "")))
            return null;
        const tokens = _tokenize(src);
        if (!tokens)
            return null;
        const functions = angle === "deg" ? Object.assign({}, _functions, { sin: x => Math.sin(x * Math.PI / 180), cos: x => Math.cos(x * Math.PI / 180), tan: x => Math.tan(x * Math.PI / 180), asin: x => Math.asin(x) * 180 / Math.PI, acos: x => Math.acos(x) * 180 / Math.PI, atan: x => Math.atan(x) * 180 / Math.PI }) : _functions;
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

    // Compile the smaller, eval-free graph language. Substitution happens only after token validation;
    // implicit multiplication is accepted around x (for example 2x and x(x)).
    function compile(text, angle) {
        let src = String(text ?? "").trim().toLowerCase().replace(/×/g, "*").replace(/÷/g, "/");
        if (src === "" || /,/.test(src) || !/^[a-z0-9.pi e()+\-*/^%]*$/.test(src.replace(/\s/g, ""))) return null;
        // "ex" is e times x, but "exp" stays a name: split only letter runs made of constants and x.
        const raw = _tokenize(src);
        if (!raw) return null;
        const tokens = [];
        for (const t of raw)
            tokens.push(...(typeof t === "string" && /^(?:pi|e|x){2,}$/.test(t) ? t.match(/pi|e|x/g) : [t]));
        const expanded = [];
        for (const token of tokens) {
            const prior = expanded[expanded.length - 1];
            const priorEndsValue = typeof prior === "number" || ["x", "pi", "e", ")"].includes(prior);
            const startsValue = typeof token === "number" || ["x", "pi", "e", "("].includes(token) || Object.prototype.hasOwnProperty.call(_functions, token);
            if (priorEndsValue && startsValue) expanded.push("*");
            expanded.push(token);
        }
        tokens.splice(0, tokens.length, ...expanded);
        const names = new Set(["x", "pi", "e", ...Object.keys(_functions)]);
        if (tokens.some(t => typeof t === "string" && !["(", ")", "+", "-", "*", "/", "^", "%"].includes(t) && !names.has(t))) return null;
        let pos = 0;
        const peek = () => tokens[pos];
        const next = () => tokens[pos++];
        function expr() {
            let left = term();
            while (peek() === "+" || peek() === "-") { const op = next(); const right = term(); const prior = left; left = x => op === "+" ? prior(x) + right(x) : prior(x) - right(x); }
            return left;
        }
        function term() {
            let left = unary();
            while (peek() === "*" || peek() === "/" || peek() === "%") { const op = next(); const right = unary(); const prior = left; left = x => op === "*" ? prior(x) * right(x) : op === "/" ? prior(x) / right(x) : prior(x) % right(x); }
            return left;
        }
        // In a graph the sign binds looser than the power: -x^2 opens downwards.
        function unary() { if (peek() === "-") { next(); const v = unary(); return x => -v(x); } if (peek() === "+") { next(); return unary(); } return power(); }
        function power() { const left = postfix(); if (peek() === "^") { next(); const right = unary(); return x => Math.pow(left(x), right(x)); } return left; }
        function postfix() { let v = primary(); if (peek() === "%") { next(); const prior = v; v = x => prior(x) / 100; } return v; }
        function primary() {
            const t = next();
            if (typeof t === "number") return () => t;
            if (t === "x") return x => x;
            if (t === "pi") return () => Math.PI;
            if (t === "e") return () => Math.E;
            if (t === "(") { const v = expr(); if (next() !== ")") throw "parenthesis"; return v; }
            if (Object.prototype.hasOwnProperty.call(_functions, t)) {
                if (next() !== "(") throw "function";
                const arg = expr();
                if (next() !== ")") throw "parenthesis";
                return x => {
                    const value = arg(x);
                    if (angle === "deg" && ["sin", "cos", "tan"].includes(t)) return _functions[t](value * Math.PI / 180);
                    if (angle === "deg" && ["asin", "acos", "atan"].includes(t)) return _functions[t](value) * 180 / Math.PI;
                    return _functions[t](value);
                };
            }
            throw "symbol";
        }
        try {
            const run = expr();
            if (pos !== tokens.length) return null;
            return x => {
                if (typeof x !== "number" || !isFinite(x)) return null;
                try { const value = run(x); return Number.isFinite(value) ? value : null; } catch (e) { return null; }
            };
        } catch (e) { return null; }
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
