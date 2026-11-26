"""The portal emblem's sparks, shared by the Blender render (tools/emblem/portal_blend.py: the gold
spark bodies) and the packer (tools/emblem/make_emblem.py: the star glints laid over them, and the
twinkles). Plain Python, no Blender or numpy, so both sides compute the very same positions.

Coordinates are the emblem's own plane: x right, y up, the frame spans -1..1 (the camera's
orthographic view). t is the loop time 0..1 (frame / FRAMES). Every motion is periodic in t, so
frame FRAMES equals frame 0 and the game can step the frames round and round.
"""
import math
import random

# The layout (frame units): the open vortex, the gold rune ring round it, where the sparks fly to.
VORTEX_R = 0.64     # the swirl disc (its soft edge tucks under the ring)
RING_IN = 0.605     # the inner gold rim
RING_OUT = 0.735    # the outer gold rim
SPARK_REACH = 0.97  # flung sparks fade out by here

# The swirl turns 120 degrees clockwise per loop (three arms), the ring 60 degrees the other way
# (twelve glyphs, two designs alternating: six-fold).
SWIRL_TURN = -2 * math.pi / 3
RING_TURN = math.pi / 3

_R = random.Random(20261119)

# Flung sparks: born on the ring's rim, thrown outwards, dragged along with the swirl's turn.
# (base angle, phase, laps per loop (integer: seamless), reach, size)
FLUNG = []
for _i in range(14):
    FLUNG.append((2 * math.pi * _i / 14 + _R.uniform(-0.18, 0.18), _R.random(), 1 if _i % 3 else 2,
                  _R.uniform(0.75, 1.0), _R.uniform(0.8, 1.2)))

# Twinkles: fixed glints round the ring that flash (an integer number of times per loop).
# (x, y, phase, flashes per loop, size)
TWINKLES = []
for _i in range(7):
    _a = 2 * math.pi * (_i + _R.uniform(-0.3, 0.3)) / 7 + 0.4
    _r = _R.uniform(0.70, 0.90)
    TWINKLES.append((_r * math.cos(_a), _r * math.sin(_a), _R.random(), 1 + (_i % 2), _R.uniform(0.85, 1.15)))

# Stars caught in the swirl: three-fold copies turning with it, so the loop stays seamless.
# (radius, angle, phase, size)
SWIRL_STARS = []
for _i in range(4):
    _rr, _a0, _ph = _R.uniform(0.18, 0.52), _R.uniform(0, 2 * math.pi), _R.random()
    for _k in range(3):
        SWIRL_STARS.append((_rr, _a0 + 2 * math.pi * _k / 3, _ph, _R.uniform(0.7, 1.0)))


def flung(t):
    """[(x, y, brightness 0..1, size, dx, dy)] for each flung spark at loop time t."""
    out = []
    for a0, ph, laps, reach, size in FLUNG:
        u = (laps * t + ph) % 1.0
        out.append(_flung_at(a0, u, reach, size))
    return out


def _flung_pos(a0, u, reach):
    ease = 1 - (1 - u) ** 2
    r = RING_OUT - 0.01 + (SPARK_REACH - RING_OUT) * reach * ease
    a = a0 - 0.75 * ease  # clockwise, with the swirl
    return r * math.cos(a), r * math.sin(a)


def _flung_at(a0, u, reach, size):
    x, y = _flung_pos(a0, u, reach)
    x2, y2 = _flung_pos(a0, min(1.0, u + 0.04), reach)
    b = math.sin(math.pi * u) ** 0.6 * (1 - 0.45 * u)
    return x, y, b, size * (1 - 0.45 * u), x2 - x, y2 - y


def twinkles(t):
    """[(x, y, brightness 0..1, size)] for the fixed twinkles and the stars in the swirl."""
    out = []
    for x, y, ph, k, size in TWINKLES:
        b = max(0.0, math.sin(2 * math.pi * (k * t + ph))) ** 4
        out.append((x, y, b, size))
    for rr, a0, ph, size in SWIRL_STARS:
        a = a0 + SWIRL_TURN * t
        r = rr * VORTEX_R
        b = 0.35 + 0.65 * max(0.0, math.sin(2 * math.pi * (2 * t + ph))) ** 2
        out.append((r * math.cos(a), r * math.sin(a), b, size * 0.6))
    return out
