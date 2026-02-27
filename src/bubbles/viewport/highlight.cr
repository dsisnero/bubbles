require "textseg"
require "uniwidth"

module Bubbles
  module Viewport
    # HighlightInfo represents a highlight range that may span multiple lines.
    struct HighlightInfo
      # in which line this highlight starts and ends
      property line_start : Int32
      property line_end : Int32

      # the grapheme highlight ranges for each of these lines
      property lines : Hash(Int32, Tuple(Int32, Int32))

      def initialize(@line_start = 0, @line_end = 0, @lines = Hash(Int32, Tuple(Int32, Int32)).new)
      end

      # coords returns the line x column of this highlight.
      def coords : Tuple(Int32, Int32, Int32)
        (line_start..line_end).each do |i|
          if hl = @lines[i]?
            return {i, hl[0], hl[1]}
          end
        end
        {line_start, 0, 0}
      end
    end

    # parse_matches converts the given matches into highlight ranges.
    #
    # Assumptions:
    # - matches are measured in bytes, e.g. what regex.FindAllStringIndex would return
    # - matches were made against the given content
    # - matches are in order
    # - matches do not overlap
    # - content is line terminated with \n only
    #
    # We'll then convert the ranges into HighlightInfos, which hold the starting
    # line and the grapheme positions.
    def self.parse_matches(content : String, matches : Array(Array(Int32))) : Array(HighlightInfo)
      return [] of HighlightInfo if matches.empty?

      line = 0
      grapheme_pos = 0
      previous_lines_offset = 0
      byte_pos = 0

      highlights = [] of HighlightInfo
      stripped = Ansi.strip(content)
      iterator = TextSegment.each_grapheme(stripped)

      matches.each do |match|
        byte_start, byte_end = match[0], match[1]

        # highlight for this match:
        highlight_info = HighlightInfo.new
        highlight_info.lines = Hash(Int32, Tuple(Int32, Int32)).new

        # find the beginning of this byte range, setup current line and
        # grapheme position.
        while byte_start > byte_pos
          cluster = iterator.next
          break if cluster.is_a?(Iterator::Stop)

          if content[byte_pos] == '\n'
            previous_lines_offset = grapheme_pos + 1
            line += 1
          end

          grapheme_pos += Math.max(1, UnicodeCharWidth.width(cluster.str))
          byte_pos += cluster.str.bytesize
        end

        highlight_info.line_start = line
        highlight_info.line_end = line

        grapheme_start = grapheme_pos

        # loop until we find the end
        while byte_end > byte_pos
          cluster = iterator.next
          break if cluster.is_a?(Iterator::Stop)

          # if it ends with a new line, add the range, increase line, and continue
          if content[byte_pos] == '\n'
            colstart = Math.max(0, grapheme_start - previous_lines_offset)
            colend = Math.max(grapheme_pos - previous_lines_offset + 1, colstart) # +1 its \n itself

            if colend > colstart
              highlight_info.lines[line] = {colstart, colend}
              highlight_info.line_end = line
            end

            previous_lines_offset = grapheme_pos + 1
            line += 1
          end

          grapheme_pos += Math.max(1, UnicodeCharWidth.width(cluster.str))
          byte_pos += cluster.str.bytesize
        end

        # we found it!, add highlight and continue
        if byte_pos == byte_end
          colstart = Math.max(0, grapheme_start - previous_lines_offset)
          colend = Math.max(grapheme_pos - previous_lines_offset, colstart)

          if colend > colstart
            highlight_info.lines[line] = {colstart, colend}
            highlight_info.line_end = line
          end
        end

        highlights << highlight_info
      end

      highlights
    end

    # make_highlight_ranges returns lipgloss ranges for the given line.
    def self.make_highlight_ranges(
      highlights : Array(HighlightInfo),
      line : Int32,
      style : Lipgloss::Style,
    ) : Array(Lipgloss::Range)
      result = [] of Lipgloss::Range
      highlights.each do |highlight|
        lihi = highlight.lines[line]?
        next unless lihi
        # In Go: if lihi == [2]int{} { continue }
        # Empty tuple (0,0) is not added
        if lihi[0] == 0 && lihi[1] == 0
          next
        end
        result << Lipgloss.new_range(lihi[0], lihi[1], style)
      end
      result
    end
  end
end
