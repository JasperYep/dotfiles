#!/usr/bin/env python3
"""Convert a small LaTeX math subset into terminal-friendly Unicode."""

from __future__ import annotations

import sys


COMMANDS = {
    "alpha": "\u03b1",
    "beta": "\u03b2",
    "gamma": "\u03b3",
    "delta": "\u03b4",
    "epsilon": "\u03b5",
    "varepsilon": "\u03b5",
    "zeta": "\u03b6",
    "eta": "\u03b7",
    "theta": "\u03b8",
    "vartheta": "\u03d1",
    "iota": "\u03b9",
    "kappa": "\u03ba",
    "lambda": "\u03bb",
    "mu": "\u03bc",
    "nu": "\u03bd",
    "xi": "\u03be",
    "pi": "\u03c0",
    "varpi": "\u03d6",
    "rho": "\u03c1",
    "varrho": "\u03f1",
    "sigma": "\u03c3",
    "varsigma": "\u03c2",
    "tau": "\u03c4",
    "upsilon": "\u03c5",
    "phi": "\u03c6",
    "varphi": "\u03d5",
    "chi": "\u03c7",
    "psi": "\u03c8",
    "omega": "\u03c9",
    "Gamma": "\u0393",
    "Delta": "\u0394",
    "Theta": "\u0398",
    "Lambda": "\u039b",
    "Xi": "\u039e",
    "Pi": "\u03a0",
    "Sigma": "\u03a3",
    "Upsilon": "\u03a5",
    "Phi": "\u03a6",
    "Psi": "\u03a8",
    "Omega": "\u03a9",
    "cdot": "\u00b7",
    "times": "\u00d7",
    "pm": "\u00b1",
    "mp": "\u2213",
    "neq": "\u2260",
    "ne": "\u2260",
    "leq": "\u2264",
    "le": "\u2264",
    "geq": "\u2265",
    "ge": "\u2265",
    "ll": "\u226a",
    "gg": "\u226b",
    "approx": "\u2248",
    "sim": "\u223c",
    "simeq": "\u2243",
    "equiv": "\u2261",
    "to": "\u2192",
    "rightarrow": "\u2192",
    "leftarrow": "\u2190",
    "leftrightarrow": "\u2194",
    "Rightarrow": "\u21d2",
    "Leftarrow": "\u21d0",
    "Leftrightarrow": "\u21d4",
    "mapsto": "\u21a6",
    "infty": "\u221e",
    "partial": "\u2202",
    "nabla": "\u2207",
    "forall": "\u2200",
    "exists": "\u2203",
    "neg": "\u00ac",
    "land": "\u2227",
    "lor": "\u2228",
    "cap": "\u2229",
    "cup": "\u222a",
    "subset": "\u2282",
    "subseteq": "\u2286",
    "supset": "\u2283",
    "supseteq": "\u2287",
    "in": "\u2208",
    "notin": "\u2209",
    "ni": "\u220b",
    "sum": "\u2211",
    "prod": "\u220f",
    "int": "\u222b",
    "oint": "\u222e",
    "propto": "\u221d",
    "parallel": "\u2225",
    "perp": "\u27c2",
    "angle": "\u2220",
    "degree": "\u00b0",
    "ldots": "\u2026",
    "cdots": "\u22ef",
    "dots": "\u2026",
    "mid": "\u2223",
    "vert": "\u2223",
    "Vert": "\u2016",
}

TEXT_COMMANDS = {
    "mathrm",
    "mathbf",
    "mathit",
    "mathsf",
    "mathtt",
    "text",
    "textrm",
    "textbf",
    "textit",
    "operatorname",
    "operatorname*",
}

SUPER_MAP = {
    "0": "\u2070",
    "1": "\u00b9",
    "2": "\u00b2",
    "3": "\u00b3",
    "4": "\u2074",
    "5": "\u2075",
    "6": "\u2076",
    "7": "\u2077",
    "8": "\u2078",
    "9": "\u2079",
    "+": "\u207a",
    "-": "\u207b",
    "=": "\u207c",
    "(": "\u207d",
    ")": "\u207e",
    "n": "\u207f",
    "i": "\u2071",
    "a": "\u1d43",
    "b": "\u1d47",
    "c": "\u1d9c",
    "d": "\u1d48",
    "e": "\u1d49",
    "f": "\u1da0",
    "g": "\u1d4d",
    "h": "\u02b0",
    "j": "\u02b2",
    "k": "\u1d4f",
    "l": "\u02e1",
    "m": "\u1d50",
    "o": "\u1d52",
    "p": "\u1d56",
    "r": "\u02b3",
    "s": "\u02e2",
    "t": "\u1d57",
    "u": "\u1d58",
    "v": "\u1d5b",
    "w": "\u02b7",
    "x": "\u02e3",
    "y": "\u02b8",
    "z": "\u1dbb",
    "A": "\u1d2c",
    "B": "\u1d2e",
    "D": "\u1d30",
    "E": "\u1d31",
    "G": "\u1d33",
    "H": "\u1d34",
    "I": "\u1d35",
    "J": "\u1d36",
    "K": "\u1d37",
    "L": "\u1d38",
    "M": "\u1d39",
    "N": "\u1d3a",
    "O": "\u1d3c",
    "P": "\u1d3e",
    "R": "\u1d3f",
    "T": "\u1d40",
    "U": "\u1d41",
    "V": "\u2c7d",
    "W": "\u1d42",
}

SUB_MAP = {
    "0": "\u2080",
    "1": "\u2081",
    "2": "\u2082",
    "3": "\u2083",
    "4": "\u2084",
    "5": "\u2085",
    "6": "\u2086",
    "7": "\u2087",
    "8": "\u2088",
    "9": "\u2089",
    "+": "\u208a",
    "-": "\u208b",
    "=": "\u208c",
    "(": "\u208d",
    ")": "\u208e",
    "a": "\u2090",
    "e": "\u2091",
    "h": "\u2095",
    "i": "\u1d62",
    "j": "\u2c7c",
    "k": "\u2096",
    "l": "\u2097",
    "m": "\u2098",
    "n": "\u2099",
    "o": "\u2092",
    "p": "\u209a",
    "r": "\u1d63",
    "s": "\u209b",
    "t": "\u209c",
    "u": "\u1d64",
    "v": "\u1d65",
    "x": "\u2093",
    "\u03b2": "\u1d66",
    "\u03b3": "\u1d67",
    "\u03c1": "\u1d68",
    "\u03c6": "\u1d69",
    "\u03c7": "\u1d6a",
}


def extract_group(text: str, start: int) -> tuple[str, int]:
    depth = 1
    i = start + 1
    chars: list[str] = []
    while i < len(text):
        ch = text[i]
        if ch == "{":
            depth += 1
            chars.append(ch)
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return "".join(chars), i + 1
            chars.append(ch)
        else:
            chars.append(ch)
        i += 1
    return "".join(chars), i


def read_command(text: str, start: int) -> tuple[str, int]:
    i = start + 1
    if i >= len(text):
        return "", i
    if text[i].isalpha():
        while i < len(text) and text[i].isalpha():
            i += 1
        if i < len(text) and text[i] == "*":
            i += 1
        return text[start + 1 : i], i
    return text[i], i + 1


def read_argument(text: str, start: int) -> tuple[str, int]:
    i = start
    while i < len(text) and text[i].isspace():
        i += 1
    if i >= len(text):
        return "", i
    if text[i] == "{":
        inner, i = extract_group(text, i)
        return convert(inner), i
    if text[i] == "\\":
        command, i = read_command(text, i)
        return convert_command(command, text, i, inline=True)
    return text[i], i + 1


def stylize(text: str, mapping: dict[str, str]) -> tuple[str, bool]:
    out: list[str] = []
    ok = True
    for ch in text:
        if ch == " ":
            continue
        mapped = mapping.get(ch)
        if mapped is None:
            ok = False
            out.append(ch)
        else:
            out.append(mapped)
    return "".join(out), ok


def format_fraction(num: str, den: str) -> str:
    sup, sup_ok = stylize(num, SUPER_MAP)
    sub, sub_ok = stylize(den, SUB_MAP)
    if sup and sub and sup_ok and sub_ok:
        return f"{sup}\u2044{sub}"
    if len(num) > 1:
        num = f"({num})"
    if len(den) > 1:
        den = f"({den})"
    return f"{num}\u2044{den}"


def format_sqrt(value: str) -> str:
    if len(value) <= 1:
        return f"\u221a{value}"
    return f"\u221a({value})"


def convert_command(command: str, text: str, pos: int, inline: bool = False) -> tuple[str, int] | str:
    if command in {"left", "right", "!", ",", ";", ":", "quad", "qquad"}:
        result: str | tuple[str, int] = (" " if command in {"quad", "qquad"} else "", pos)
    elif command == "frac":
        num, pos = read_argument(text, pos)
        den, pos = read_argument(text, pos)
        result = (format_fraction(num, den), pos)
    elif command == "sqrt":
        if pos < len(text) and text[pos] == "[":
            while pos < len(text) and text[pos] != "]":
                pos += 1
            if pos < len(text):
                pos += 1
        value, pos = read_argument(text, pos)
        result = (format_sqrt(value), pos)
    elif command in TEXT_COMMANDS:
        value, pos = read_argument(text, pos)
        result = (value, pos)
    elif command in COMMANDS:
        result = (COMMANDS[command], pos)
    else:
        fallback = command
        result = (fallback, pos)
    if inline:
        assert isinstance(result, tuple)
        return result[0]
    return result


def convert(text: str) -> str:
    out: list[str] = []
    i = 0
    while i < len(text):
        ch = text[i]
        if ch == "\\":
            command, i = read_command(text, i)
            piece, i = convert_command(command, text, i)
            out.append(piece)
            continue
        if ch == "{":
            inner, i = extract_group(text, i)
            out.append(convert(inner))
            continue
        if ch in {"^", "_"}:
            value, i = read_argument(text, i + 1)
            styled, ok = stylize(value, SUPER_MAP if ch == "^" else SUB_MAP)
            out.append(styled if styled and ok else value)
            continue
        if ch in {"$", "}"}:
            i += 1
            continue
        out.append(ch)
        i += 1
    return " ".join("".join(out).split())


def main() -> int:
    source = sys.stdin.read().strip()
    sys.stdout.write(convert(source))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
