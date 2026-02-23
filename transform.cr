#!/usr/bin/env crystal

require "file_utils"

def transform_file(path : String)
  content = File.read(path)

  # Replace module definition
  content = content.gsub(/require "\.\.\/tea"\n\nmodule Tea\n  module Components\n    (module|class) (\w+)/) do |_|
    type = $1
    name = $2
    "#{type} Bubbles::#{name}"
  end

  # Replace closing ends (remove two extra 'end' lines)
  # This is hacky but works for our structure
  content = content.gsub(/\n    end\n  end\nend\n\z/, "\nend\n")
  content = content.gsub(/\n      end\n    end\n  end\nend\n\z/, "\n    end\nend\n")

  # Replace Tea::Components:: references
  content = content.gsub("Tea::Components::", "Bubbles::")

  File.write(path, content)
  puts "Transformed #{path}"
end

# Process all .cr files in src/bubbles
Dir.glob("src/bubbles/**/*.cr") do |path|
  transform_file(path)
end
