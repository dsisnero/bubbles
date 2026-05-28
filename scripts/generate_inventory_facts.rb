#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"

options = { inventory: nil, source: nil, tests: nil, rules: nil }

OptionParser.new do |opts|
  opts.banner = "Usage: generate_inventory_facts.rb --inventory FILE [--source FILE] [--tests FILE] [--rules FILE]"
  opts.on("--inventory FILE", "Port inventory TSV") { |v| options[:inventory] = v }
  opts.on("--source FILE", "Source parity TSV") { |v| options[:source] = v }
  opts.on("--tests FILE", "Test parity TSV") { |v| options[:tests] = v }
  opts.on("--rules FILE", "Conversion rules TSV") { |v| options[:rules] = v }
end.parse!

abort "--inventory is required" unless options[:inventory]

def q(value)
  value = value.to_s
  value = "-" if value.empty?
  "'#{value.gsub("\\", "\\\\\\").gsub("'", "\\\\'")}'"
end

def rows(path, min_cols)
  return [] unless path && File.file?(path)

  File.readlines(path, chomp: true).filter_map do |line|
    next if line.strip.empty? || line.start_with?("#")
    cols = line.split("\t", -1)
    raise "Malformed row in #{path}: #{line}" if cols.size < min_cols
    cols
  end
end

rows(options[:inventory], 5).each do |id, kind, status, refs, notes|
  puts "inventory_item(#{q(id)}, #{q(kind)}, #{q(status)}, #{q(refs)}, #{q(notes)})."
  puts "status(#{q(id)}, #{q(status)})."
  puts "missing_item(#{q(id)})." if status == "missing"
  puts "partial_item(#{q(id)})." if status == "partial"
  puts "ported_item(#{q(id)})." if status == "ported"
  puts "intentional_divergence(#{q(id)}, #{q(notes)})." if status == "intentional_divergence"
end

rows(options[:source], 4).each do |id, status, refs, notes|
  puts "source_api(#{q(id)}, #{q(status)}, #{q(refs)}, #{q(notes)})."
end

rows(options[:tests], 4).each do |id, status, refs, notes|
  puts "source_test(#{q(id)}, #{q(status)}, #{q(refs)}, #{q(notes)})."
end

rows(options[:rules], 5).each do |from_language, to_language, upstream_kind, crystal_kind, notes|
  puts "conversion_rule(#{q(from_language)}, #{q(to_language)}, #{q(upstream_kind)}, #{q(crystal_kind)}, #{q(notes)})."
end
