# Lipgloss Issue: ANSI reset code mismatch and RGBAColor/Color type conversion

## Problem 1: ANSI Reset Code Difference
Go's lipgloss outputs `\e[m` for reset, but Crystal's lipgloss outputs `\e[0m`. This causes golden test failures when comparing output with Go reference implementations.

### Current Crystal Behavior
```crystal
style = Lipgloss::Style.new.foreground(color)
style.render("text")  # Outputs: \e[38;2;255;0;0mtext\e[0m
```

### Expected Go-like Behavior
```go
style := lipgloss.NewStyle().Foreground(color)
style.Render("text")  // Outputs: \e[38;2;255;0;0mtext\e[m
```

### Impact
- Golden tests fail due to `\e[0m` vs `\e[m` mismatch
- Breaks exact parity with Go reference implementations
- Affects all components using lipgloss for rendering (progress bars, tables, etc.)

### Required Fix
The ANSI reset code should be `\e[m` (empty parameter) not `\e[0m` (explicit 0 parameter) to match Go behavior.

## Problem 2: RGBAColor to Color Conversion Missing
`Lipgloss.blend1d` returns `Array(RGBAColor)?` but `Lipgloss::Style#foreground` expects `Color` type. There's no built-in conversion from `RGBAColor` to `Color`.

### Current Issue
```crystal
# blend1d returns RGBAColor array
blend_array = Lipgloss.blend1d(10, color1, color2)  # Returns Array(RGBAColor)

# But Style#foreground expects Color
style = Lipgloss::Style.new.foreground(blend_array[0])  # ERROR: expected Color, got RGBAColor
```

### Workaround Needed
Currently requires manual conversion:
```crystal
color_array = blend_array.map do |rgba|
  Lipgloss::Color.rgb(rgba.r, rgba.g, rgba.b)
end
```

### Expected Behavior
Either:
1. `blend1d` should return `Array(Color)` instead of `Array(RGBAColor)`
2. OR `Style#foreground` should accept `RGBAColor`
3. OR there should be a conversion method: `RGBAColor#to_color`

### Impact
- Extra conversion code needed in all consumers of `blend1d`
- Breaks clean API design
- Performance overhead for manual conversion

## Priority: High
Both issues block exact Go parity and cause test failures in dependent libraries (like bubbles progress bar).

## Test Cases
From progress bar golden tests:
1. **ANSI reset**: All golden tests fail due to `\e[0m` vs `\e[m`
2. **Color conversion**: Progress bar blend rendering requires manual RGBAColor→Color conversion

## Suggested Fixes
1. **ANSI reset**: Update renderer to output `\e[m` instead of `\e[0m`
2. **Color conversion**: Add `RGBAColor#to_color` method or make `Style#foreground` accept `RGBAColor`