# Bubble Tea Issue: Tea::Key missing text field for multi-character input parity with Go

**Issue ID:** bubbletea.1
**Priority:** High
**Component:** `lib/bubbletea/src/tea/key.cr`
**Related to:** Text input component parity with Go implementation

## Problem Description

The Crystal `Tea::Key` struct is missing a `text` field that exists in Go's `tea.KeyPressMsg`. This breaks parity for multi-character input (IME input, composed characters, etc.) and causes the textinput component to fail for non-ASCII or multi-character input.

## Current State

**Go implementation (`vendor/bubbles/textinput/textinput.go`):**
- `tea.KeyPressMsg` has a `Text string` field (line 647: `m.insertRunesFromUserInput([]rune(msg.Text))`)
- The `Text` field can contain multiple runes for IME input, composed characters, etc.

**Crystal implementation (`lib/bubbletea/src/tea/key.cr`):**
- `Tea::Key` only has `rune : Char?` (single character)
- Missing `text : String` field
- `convert_uv_key` method in `tea.cr` only extracts single rune when `uv_key.text.size == 1`

**Impact:**
- Textinput component can't handle multi-character input (Chinese, Japanese, Korean IME input)
- Breaks exact logic parity with Go implementation
- Causes `insert_runes_from_user_input` to only receive single characters

## Root Cause Analysis

1. **Ultraviolet library has correct structure:** `Ultraviolet::Key` has `text : String` field (line 182 in `lib/ultraviolet/src/ultraviolet/key.cr`)
2. **Conversion loses data:** `convert_uv_key` method in `tea.cr:674-676` only extracts single rune:
   ```crystal
   if !uv_key.text.empty? && uv_key.text.size == 1
     rune = uv_key.text[0]
   end
   ```
3. **Missing field:** `Tea::Key` struct doesn't have `text` field to store the full string

## Required Changes

### 1. Update `Tea::Key` struct (`lib/bubbletea/src/tea/key.cr`):
```crystal
struct Key
  include Msg

  property type : KeyType
  property text : String      # NEW: For multi-character input
  property rune : Char?       # Keep for backward compatibility
  property modifiers : KeyMod
  property? is_repeat : Bool = false
  property alternate : KeyType?

  def initialize(
    @type : KeyType,
    @text : String = "",      # NEW
    @rune : Char? = nil,
    @modifiers : KeyMod = 0,
    @is_repeat : Bool = false,
    @alternate : KeyType? = nil,
  )
  end

  # Update string method to use text field
  def string : String
    if !@text.empty?
      @text
    elsif @rune
      @rune.to_s
    else
      keystroke
    end
  end
end
```

### 2. Update `convert_uv_key` method (`lib/bubbletea/src/tea.cr:670-684`):
```crystal
private def convert_uv_key(uv_key : Ultraviolet::Key) : Key
  key_type = map_uv_key_type(uv_key)
  rune = nil
  if !uv_key.text.empty? && uv_key.text.size == 1
    rune = uv_key.text[0]
  end
  Key.new(
    type: key_type,
    text: uv_key.text,        # NEW: Pass full text
    rune: rune,
    modifiers: convert_uv_modifiers(uv_key.mod),
    is_repeat: uv_key.is_repeat?,
    alternate: nil
  )
end
```

### 3. Update textinput component (`src/bubbles/textinput.cr:892-894`):
```crystal
else
  # Input one or more regular characters.
  if !msg.text.empty?
    insert_runes_from_user_input(msg.text.chars)
  elsif rune = msg.rune
    insert_runes_from_user_input([rune])
  end
end

## Test Cases

1. **Multi-character IME input:** Test with Chinese/Japanese/Korean input methods
2. **Composed characters:** Test with accented characters (é, ñ, etc.)
3. **Backward compatibility:** Ensure single-character input still works
4. **Go parity:** Verify output matches Go textinput behavior exactly

## Dependencies

- Requires `Ultraviolet::Key` to have `text` field (already exists)
- No changes to ultraviolet library needed

## Notes

- This is critical for textinput component parity with Go implementation
- The `rune` field should be kept for backward compatibility
- The `text` field should be primary for character input
- All existing tests should pass after this change