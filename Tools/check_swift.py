#!/usr/bin/env python3
"""Balance-check every Swift file, lexing strings and comments properly.

Not a compiler — it only catches unbalanced braces and unterminated strings, which is the class
of damage a scripted edit does. A naive checker sees the // in an https:// URL as a comment and
reports a phantom error, so this walks the text once and tracks what it is actually inside of.
"""
import glob
import sys


def check(path):
    text = open(path, encoding="utf-8").read()
    i, n, line, depth = 0, len(text), 1, 0
    while i < n:
        char = text[i]
        if char == "\n":
            line += 1
            i += 1
        elif text.startswith("//", i):
            i = text.find("\n", i)
            if i < 0:
                i = n
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            if end < 0:
                return f"{path}: block comment opened at line {line} is never closed"
            line += text.count("\n", i, end)
            i = end + 2
        elif text.startswith('"""', i):
            end = text.find('"""', i + 3)
            if end < 0:
                return f"{path}: multiline string at line {line} is never closed"
            line += text.count("\n", i, end)
            i = end + 3
        elif char == '"':
            start, i = line, i + 1
            while i < n and text[i] != '"':
                if text[i] == "\n":
                    return f"{path}: string at line {start} runs past the end of the line"
                # An escape, or an interpolation that can itself contain braces.
                if text[i] == "\\" and i + 1 < n:
                    if text[i + 1] == "(":
                        nested, i = 1, i + 2
                        while i < n and nested:
                            if text[i] == "(":
                                nested += 1
                            elif text[i] == ")":
                                nested -= 1
                            i += 1
                        continue
                    i += 2
                    continue
                i += 1
            i += 1
        else:
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth < 0:
                    return f"{path}: unexpected '}}' at line {line}"
            i += 1
    if depth:
        return f"{path}: {depth} brace(s) left open"
    return None


paths = sorted(glob.glob("Shared/**/*.swift", recursive=True)
               + glob.glob("Orbit/**/*.swift", recursive=True))
problems = [problem for path in paths if (problem := check(path))]
for problem in problems:
    print(problem, file=sys.stderr)
print(f"{len(paths)} files checked, {len(problems)} problem(s)")
sys.exit(1 if problems else 0)
