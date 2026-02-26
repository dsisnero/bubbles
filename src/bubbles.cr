# Bubbles provides components for Bubble Tea applications.
# This is a Crystal port of charmbracelet/bubbles (v2-exp branch).
module Bubbles
  VERSION = "0.1.0"
end

# Require all component modules
require "./bubbles/key"
require "./bubbles/textinput"
require "./bubbles/filepicker"
require "./bubbles/help"
require "./bubbles/list"
require "./bubbles/list/defaultitem"
require "./bubbles/paginator"
require "./bubbles/progress"
require "./bubbles/spinner"
require "./bubbles/stopwatch"
require "./bubbles/table"
require "./bubbles/textarea"
require "./bubbles/timer"
require "./bubbles/viewport"
require "./bubbles/internal/runeutil"
require "./bubbles/internal/memoization"
