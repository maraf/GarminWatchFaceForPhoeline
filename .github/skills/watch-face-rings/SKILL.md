---
name: watch-face-rings
description: Draw progress rings/arcs around a Garmin Monkey C watch face. USE FOR any circular gauge, ring, arc, or radial progress indicator on the watch face - picking the start position (12/3/6/9 o'clock), making the fill run clock-wise (incrementing) or counter-clock-wise (decrementing), partial arcs that grow with a metric, and background tracks. Covers the two conflicting angle systems (Dc.drawArc degrees vs Math.cos/sin radians) and the pitfalls that make an arc render inverted, mirrored, filled, or as a near-full circle.
---

# Watch face rings and arcs (Monkey C)

Rings on this watch face are drawn as **polylines built from `Math.cos`/`Math.sin`**, not with
`Dc.drawArc`, for partial/progress arcs. That decision is deliberate - see *Why not drawArc*.
Read this whole file before touching `drawMetricRings`, `drawProgressArc` or
`drawBodyBatteryArc` in `source/View.mc`.

## The one rule that matters

There are **two different angle systems** in play and they rotate in **opposite** directions.
Mixing them up is what makes an arc go the wrong way.

| System | Zero angle | Positive direction on screen | Unit |
| --- | --- | --- | --- |
| `Math.cos/sin` + `dc.drawLine` (what we use) | 3 o'clock (east) | **clock-wise** | radians |
| `Dc.drawArc(...)` degrees | 3 o'clock (east) | **counter-clock-wise** | integer degrees |

Why the polyline system is clock-wise-positive: screen `y` grows **downward**, so plotting
`(cx + r*cos(a), cy + r*sin(a))` maps increasing `a` to `3 o'clock -> 6 -> 9 -> 12`:

```
a = 0        -> (cx + r, cy)      -> 3 o'clock  (right)
a = +pi/2    -> (cx,     cy + r)  -> 6 o'clock  (bottom)   <- +y is DOWN
a = +pi      -> (cx - r, cy)      -> 9 o'clock  (left)
a = +3pi/2   -> (cx,     cy - r)  -> 12 o'clock (top)
```

So, for the polyline helpers:

* **Clock-wise fill => INCREMENT the angle** (`angle = start + sweep * progress`)
* **Counter-clock-wise fill => DECREMENT the angle** (`angle = start - sweep * progress`)

Never "fix" a wrong-direction ring by negating the radius, swapping `cos`/`sin`, or flipping
the sign of the `y` term. That mirrors the arc instead of reversing it, and it silently breaks
the start position. Change the **sign of the increment** only.

## Start position: clock hours -> radians

Use this conversion, never hand-typed magic constants:

```
angleRad = (clockHour / 12.0) * 2 * PI - PI / 2
```

| Clock position | radians | notes |
| --- | --- | --- |
| 12 o'clock (top) | `-PI/2` | start of the steps ring |
| 3 o'clock (right) | `0` | |
| 6 o'clock (bottom) | `+PI/2` | start of the body-battery ring |
| 9 o'clock (left) | `+PI` | |

`-PI/2` and `+3PI/2` are the same point; prefer the one that keeps the whole sweep monotonic so
the loop interpolation stays simple.

## Recipe A - clock-wise ring, incrementing

Full 360-degree ring starting at 12 o'clock, filling clock-wise (this is the steps ring):

```monkeyc
private function drawProgressArc(dc as Dc, centerX as Number, centerY as Number,
    radius as Number, progress as Float) as Void {
    var pi = 3.14159265359;
    var startAngle = -pi / 2.0;                          // 12 o'clock
    var endAngle = startAngle + (2.0 * pi * progress);   // + => clock-wise
    var segmentCount = 72;
    var previousX = centerX + radius * Math.cos(startAngle);
    var previousY = centerY + radius * Math.sin(startAngle);

    for (var i = 1; i <= segmentCount; i += 1) {
        var ratio = i.toFloat() / segmentCount.toFloat();
        var angle = startAngle + ((endAngle - startAngle) * ratio);
        var currentX = centerX + radius * Math.cos(angle);
        var currentY = centerY + radius * Math.sin(angle);
        dc.drawLine(previousX, previousY, currentX, currentY);
        previousX = currentX;
        previousY = currentY;
    }
}
```

Partial sweep variant (body battery: starts at 6 o'clock, sweeps 270 degrees clock-wise through
9 and 12, ending at 3 o'clock):

```monkeyc
var startAngle = pi / 2.0;                                    // 6 o'clock
var endAngle = startAngle + ((3.0 * pi / 2.0) * progress);    // 270 deg, clock-wise
```

## Recipe B - counter-clock-wise ring, decrementing

Identical loop, only the `endAngle` sign changes. To fill counter-clock-wise from 6 o'clock
over 270 degrees (6 -> 3 -> 12 -> 9):

```monkeyc
var startAngle = pi / 2.0;                                    // 6 o'clock
var endAngle = startAngle - ((3.0 * pi / 2.0) * progress);    // - => counter-clock-wise
```

Full counter-clock-wise ring from 12 o'clock:

```monkeyc
var startAngle = -pi / 2.0;
var endAngle = startAngle - (2.0 * pi * progress);
```

The interpolation `angle = startAngle + ((endAngle - startAngle) * ratio)` already handles a
negative delta, so **nothing else in the loop changes**. If you find yourself reversing the
loop bounds (`for (var i = segmentCount; i >= 1; i -= 1)`) you are solving the wrong problem:
that reverses the *drawing order*, not the geometry, and the arc looks identical.

## Reusable helper (preferred for new rings)

```monkeyc
// startClockHour: 0..12 (12 or 0 = top). sweepDegrees: length of the full track.
// clockwise: true => incrementing angle, false => decrementing angle.
private function drawRingArc(dc as Dc, centerX as Number, centerY as Number, radius as Number,
    startClockHour as Float, sweepDegrees as Float, clockwise as Boolean, progress as Float) as Void {
    var pi = 3.14159265359;
    if (progress <= 0.0) { return; }
    if (progress > 1.0) { progress = 1.0; }

    var startAngle = (startClockHour / 12.0) * 2.0 * pi - (pi / 2.0);
    var sweep = (sweepDegrees / 180.0) * pi * progress;
    var endAngle = clockwise ? startAngle + sweep : startAngle - sweep;

    // ~5 degrees per segment keeps the polyline visually smooth at r >= 150.
    var segmentCount = (sweepDegrees / 5.0).toNumber();
    if (segmentCount < 8) { segmentCount = 8; }

    var previousX = centerX + radius * Math.cos(startAngle);
    var previousY = centerY + radius * Math.sin(startAngle);
    for (var i = 1; i <= segmentCount; i += 1) {
        var angle = startAngle + ((endAngle - startAngle) * (i.toFloat() / segmentCount.toFloat()));
        var currentX = centerX + radius * Math.cos(angle);
        var currentY = centerY + radius * Math.sin(angle);
        dc.drawLine(previousX, previousY, currentX, currentY);
        previousX = currentX;
        previousY = currentY;
    }
}
```

## Drawing order and colors

1. `dc.setPenWidth(4)` once before the ring block; pen width is sticky device state.
2. Draw the **dark background track first** with `progress = 1.0` and the exact same
   `startAngle` / direction / radius as the value arc. Deriving the track from the same helper
   is what guarantees the value arc lands exactly on top of it.
3. Then draw the value arc.
4. **Always pass `Graphics.COLOR_TRANSPARENT` as the second argument of `setColor`.**
   `dc.setColor(color, color)` sets an opaque background and produced filled/smeared rings -
   this was a real bug in this repo (fixed in commit `0d146b3`).
5. Clamp progress before drawing: `if (p > 1.0) { p = 1.0; }` and skip drawing when `p <= 0.0`.
   An unclamped `p > 1` wraps past the start point and repaints over the track.

Current radii on this face: steps ring `184`, body battery ring `164` (20 px apart, pen width 4).

## Why not `Dc.drawArc` for progress

`dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 0, 360)` is fine for a **full** circle track, and
that is the only place it is still used.

For partial arcs it is a trap:

* Its degrees increase **counter-clock-wise**, the opposite of the `cos`/`sin` system, so the
  same "add progress to the start angle" reflex produces a mirrored arc.
* With `ARC_CLOCKWISE` the sweep goes from `degreeStart` **down** to `degreeEnd`. The original
  code in commit `62d8851` did
  `dc.drawArc(cx, cy, 164, Graphics.ARC_CLOCKWISE, -90, -90 + (180 * bodyProgress))`, i.e. an end
  angle *greater* than the start, so it swept clock-wise the long way round and rendered
  `360 - 180*progress` degrees - a nearly full ring that **shrank** as the metric grew. That is
  the exact bug this skill exists to prevent. For a clock-wise arc the end degree must be
  `start - sweep`.
* Degrees are integers, so slow-moving metrics quantize and the arc visibly steps.

If you do use `drawArc`, convert once: `degrees = -radians * 180 / PI`, and remember
`ARC_CLOCKWISE` decrements while `ARC_COUNTER_CLOCKWISE` increments.

## Verification checklist

Before considering a ring change done, check on the simulator with forced values:

* `progress = 0.0` - nothing drawn (no stray dot at the start point).
* `progress = 0.25` - the filled part ends at the expected clock position. For a clock-wise
  270-degree track starting at 6 o'clock, 25% is 67.5 degrees, ending at the 8:15 clock
  position (between 8 and 9 o'clock).
* `progress = 1.0` - the value arc exactly covers the dark track, no overshoot, no gap.
* Increase the metric - the arc must **grow**. If it shrinks, the direction sign is wrong (or
  you are on `drawArc` with an inverted sweep).
* Both rings start where the design says (steps at 12 o'clock, body battery at 6 o'clock).
