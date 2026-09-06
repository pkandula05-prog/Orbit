#!/usr/bin/env python3
"""Render the Orbit app icon (artboard 9a · 01) to a PNG.

The icon is the dial reduced to what survives at 60pt: the swept blue arc, the red heading
body and one yellow marker on a neutral ring. Geometry is expressed in the artboard's 66-unit
square and scaled, so this stays in step with `OrbitMark` in the app.

    python3 Tools/make_icon.py Orbit/Assets.xcassets/AppIcon.appiconset/icon-1024.png 1024
"""
import math
import struct
import sys
import zlib

BG = (0xF3, 0xF2, 0xF2)
TRACK = (0xD9, 0xD7, 0xD5)
BLUE = (0x1B, 0x3F, 0xA8)
RED = (0xEC, 0x30, 0x13)
YELLOW = (0xFB, 0xC4, 0x17)

BOX = 66.0            # the artboard's icon square
RADIUS = 19.0         # ring centre-line radius
STROKE = 6.0
DOT = 7.0             # heading body / marker radius
MARKER_STROKE = 3.0
ARC = (265.0, 355.0)  # the swept arc, clockwise from north
BODY_BEARING = 39.0
MARKER_BEARING = 239.0

SAMPLES = 2           # per axis; 2x2 is enough at 1024


def point(bearing, radius, centre):
    theta = math.radians(bearing)
    return centre + radius * math.sin(theta), centre - radius * math.cos(theta)


def render(size):
    scale = size / BOX
    centre = size / 2.0
    radius, stroke, dot = RADIUS * scale, STROKE * scale, DOT * scale
    marker_stroke = MARKER_STROKE * scale
    body = point(BODY_BEARING, radius, centre)
    marker = point(MARKER_BEARING, radius, centre)
    step = 1.0 / SAMPLES
    weight = 1.0 / (SAMPLES * SAMPLES)

    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            r = g = b = 0.0
            for sy in range(SAMPLES):
                py = y + (sy + 0.5) * step
                for sx in range(SAMPLES):
                    px = x + (sx + 0.5) * step
                    colour = sample(px, py, centre, radius, stroke, dot, marker_stroke, body, marker)
                    r += colour[0] * weight
                    g += colour[1] * weight
                    b += colour[2] * weight
            row += bytes((int(r + 0.5), int(g + 0.5), int(b + 0.5)))
        rows.append(bytes(row))
    return rows


def sample(px, py, centre, radius, stroke, dot, marker_stroke, body, marker):
    dx, dy = px - centre, py - centre
    distance = math.hypot(dx, dy)

    colour = BG
    if abs(distance - radius) <= stroke / 2:
        # Bearing of this pixel, clockwise from north, to test against the swept arc.
        bearing = (math.degrees(math.atan2(dx, -dy))) % 360
        inside = ARC[0] <= bearing <= ARC[1]
        colour = BLUE if inside else TRACK

    if math.hypot(px - marker[0], py - marker[1]) <= dot:
        inner = dot - marker_stroke
        colour = YELLOW if math.hypot(px - marker[0], py - marker[1]) > inner else BG

    if math.hypot(px - body[0], py - body[1]) <= dot:
        colour = RED

    return colour


def write_png(path, rows, size):
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag, payload):
        data = tag + payload
        return struct.pack(">I", len(payload)) + data + struct.pack(">I", zlib.crc32(data))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as handle:
        handle.write(png)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "icon-1024.png"
    dimension = int(sys.argv[2]) if len(sys.argv) > 2 else 1024
    write_png(out, render(dimension), dimension)
    print(f"wrote {out} at {dimension}px")
