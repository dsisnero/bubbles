# Lipgloss Issue: blend1d method signature mismatch with Go implementation

## Problem
The Crystal `Lipgloss.blend1d` method has a signature mismatch with the Go implementation that prevents proper usage in the progress bar port.

## Current Crystal Implementation
```crystal
def self.blend1d(steps : Int32, *stops : Color | RGBAColor | Nil) : Array(RGBAColor)?
```

## Expected Go-like Behavior
The Go `lipgloss.Blend1D` function accepts a variadic parameter of `color.Color` interface types and returns `[]color.Color`. In the progress bar code, it's called with:
```go
blend = lipgloss.Blend1D(tw*multiplier, m.blend...)
```
Where `m.blend` is `[]color.Color`.

## Issue Details
1. **Type mismatch**: Crystal's `blend1d` returns `Array(RGBAColor)?` (nullable), but Go returns `[]color.Color` (non-nullable slice, may be empty)
2. **Nil handling**: Crystal's version accepts `Nil` in stops, but Go doesn't accept nil colors
3. **Return type**: Crystal returns optional (`?`), Go returns non-optional slice
4. **Array-to-tuple conversion**: When calling `blend1d` with an array of colors, Crystal requires splatting (`*array`), but the progress bar code needs to work with `Array(Color)` directly

## Impact
This prevents the progress bar blend rendering from working correctly. The progress bar's `bar_view` method needs to call `blend1d` with an array of colors and get back an array of colors for rendering.

## Required Fix
1. Add a `blend1d` overload that accepts `Array(Color | RGBAColor)` instead of just varargs
2. Ensure the return type is non-optional (`Array(RGBAColor)` not `Array(RGBAColor)?`)
3. Match Go behavior: return empty array for zero steps, not nil
4. Remove `Nil` from accepted stop types (colors shouldn't be nil)

## Example Fix
```crystal
# Current problematic signature
def self.blend1d(steps : Int32, *stops : Color | RGBAColor | Nil) : Array(RGBAColor)?

# Should add:
def self.blend1d(steps : Int32, stops : Array(Color | RGBAColor)) : Array(RGBAColor)
  safe_steps = [steps, 0].max
  compact_stops = normalize_stops(stops)
  blend1d_from_colors(safe_steps, compact_stops) || [] of RGBAColor
end
```

## Test Case
From progress bar golden test `30w-colorfunc-rgb-100perc`:
- Expected: Blend rendering works with color array
- Actual: Type mismatch prevents compilation/execution

## Priority: High
Blocks progress bar port completion and exact Go parity.