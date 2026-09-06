#!/usr/bin/env python3
"""Parse Orbit.xcodeproj/project.pbxproj the way Xcode does, and fail loudly if it cannot.

Xcode reports a broken project file as "damaged ... parse error" with no line number, and the
file is edited by hand here, so this is the check that has to catch it first.

    python3 Tools/check_project.py
"""
import sys

PATH = "Orbit.xcodeproj/project.pbxproj"


def strip_noise(text):
    """Remove comments and quoted strings, tracking that quotes and comments are balanced."""
    out, i, n = [], 0, len(text)
    line = 1
    while i < n:
        char = text[i]
        if char == "\n":
            line += 1
            out.append(char)
            i += 1
        elif char == '"':
            start = line
            i += 1
            while i < n and text[i] != '"':
                if text[i] == "\n":
                    raise SyntaxError(f"line {start}: string is not closed before end of line")
                i += 2 if text[i] == "\\" else 1
            if i >= n:
                raise SyntaxError(f"line {start}: string is never closed")
            i += 1
            out.append("S")
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            if end < 0:
                raise SyntaxError(f"line {line}: comment is never closed")
            newlines = text.count("\n", i, end)
            line += newlines
            out.append("\n" * newlines)
            i = end + 2
        elif text.startswith("//", i):
            i = text.find("\n", i)
            if i < 0:
                i = n
        else:
            out.append(char)
            i += 1
    return "".join(out)


def check_balance(text):
    stack = []
    line = 1
    pairs = {"}": "{", ")": "(", ">": "<"}
    for char in text:
        if char == "\n":
            line += 1
        elif char in "{(":
            stack.append((char, line))
        elif char in "})":
            if not stack or stack[-1][0] != pairs[char]:
                raise SyntaxError(f"line {line}: unexpected '{char}'")
            stack.pop()
    if stack:
        char, line = stack[-1]
        raise SyntaxError(f"line {line}: '{char}' is never closed")


def check_statements(stripped):
    """Every setting inside a dictionary has to end in a semicolon."""
    for number, line in enumerate(stripped.splitlines(), start=1):
        text = line.strip()
        if not text or text.endswith((";", "{", "}", "(", ")", ",", "};", ");")):
            continue
        if "=" in text:
            raise SyntaxError(f"line {number}: setting has no terminating ';' — {text[:60]}")
        # A bare token that is not a list entry is a stray edit.
        raise SyntaxError(f"line {number}: unterminated line — {text[:60]}")


def main():
    raw = open(PATH, encoding="utf-8").read()
    if "\\n" in raw:
        line = raw[: raw.index("\\n")].count("\n") + 1
        raise SyntaxError(f"line {line}: literal backslash-n where a newline belongs")
    if "<<<<<<<" in raw:
        raise SyntaxError("unresolved merge conflict markers")

    stripped = strip_noise(raw)
    check_balance(stripped)
    check_statements(stripped)
    print(f"{PATH}: parses cleanly")


if __name__ == "__main__":
    try:
        main()
    except SyntaxError as error:
        print(f"{PATH} is damaged: {error}", file=sys.stderr)
        sys.exit(1)
