#!/usr/bin/env crystal

require "file_utils"

def transform_spec_file(path : String)
  content = File.read(path)

  # Replace require paths
  content = content.gsub(/require "\.\.\/spec_helper"/, "require \"./spec_helper\"")

  # Replace component require paths
  content = content.gsub(/require "\.\.\/\.\.\/src\/components\/(\w+)"/) do |_|
    component = $1.downcase
    # Map component name to directory
    # e.g., cursor -> cursor/cursor, text_area -> textarea/textarea
    dir = case component
          when "text_area"
            "textarea/textarea"
          when "text_input"
            "textinput/textinput"
          when "rune_util"
            "internal/runeutil/runeutil"
          when "memoization"
            "internal/memoization/memoization"
          when "table_styles"
            "table/table_styles"
          else
            "#{component}/#{component}"
          end
    %(require "../src/bubbles/#{dir}")
  end

  # Replace describe and references
  content = content.gsub("Tea::Components::", "Bubbles::")

  File.write(path, content)
  puts "Transformed spec #{path}"
end

# Process all spec files
Dir.glob("spec/*.cr") do |path|
  transform_spec_file(path)
end
