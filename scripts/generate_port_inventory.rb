#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require_relative 'parity_inventory_lib'

options = {
  root_dir: Dir.pwd,
  out: nil,
  source_path: ENV['PORT_SOURCE_DIR'],
  language: ENV['PORT_LANGUAGE'] || 'go',
  parser: ENV['PORT_PARSER'] || 'auto',
  force_overwrite: ENV['PORT_FORCE_OVERWRITE'] == '1',
  example_dir: ENV['PORT_EXAMPLE_DIR'],
  example_target: ENV['PORT_EXAMPLE_TARGET'],
  example_ext: ENV['PORT_EXAMPLE_EXT'],
  example_target_ext: ENV['PORT_EXAMPLE_TARGET_EXT']
}

OptionParser.new do |opts|
  opts.banner = 'Usage: generate_port_inventory.rb [options]'
  opts.on('--root DIR', 'Project root (default: pwd)') { |v| options[:root_dir] = v }
  opts.on('--out FILE', 'Output TSV path') { |v| options[:out] = v }
  opts.on('--source PATH', 'Source path (absolute or relative to root)') { |v| options[:source_path] = v }
  opts.on('--language LANG', 'Language: go|rust|crystal|java|ruby') { |v| options[:language] = v }
  opts.on('--parser MODE', 'Parser: auto|regex|tree-sitter') { |v| options[:parser] = v }
  opts.on('--force-overwrite', 'Allow overwriting an existing port inventory file') { options[:force_overwrite] = true }
  opts.on('--example-dir DIR', 'Source example directory (e.g., vendor/rig/rig-core/examples)') do |v|
    options[:example_dir] = v
  end
  opts.on('--example-target DIR', 'Target example directory (e.g., examples)') { |v| options[:example_target] = v }
  opts.on('--example-ext EXT', 'Source example extension (e.g., .rs)') { |v| options[:example_ext] = v }
  opts.on('--example-target-ext EXT', 'Target example extension (e.g., .cr)') { |v| options[:example_target_ext] = v }
end.parse!

language = options[:language]
out = options[:out] || File.join(options[:root_dir], "plans/inventory/#{language}_port_inventory.tsv")

if File.exist?(out) && !options[:force_overwrite]
  warn "Refusing to overwrite existing inventory: #{out}"
  warn 'Use check_port_inventory.sh for drift checks and update statuses manually.'
  warn 'If you intentionally want to reset, rerun with --force-overwrite or PORT_FORCE_OVERWRITE=1.'
  exit 1
end

base, items = ParityInventory.discover_items(
  root_dir: options[:root_dir],
  source_path: options[:source_path],
  language: language,
  parser_mode: options[:parser]
)

# Add example file items if example parameters are provided
if options[:example_dir] && options[:example_target]
  example_items = ParityInventory.discover_example_items(
    root_dir: options[:root_dir],
    source_path: options[:source_path],
    example_dir: options[:example_dir],
    example_target: options[:example_target],
    language: language,
    example_ext: options[:example_ext],
    example_target_ext: options[:example_target_ext]
  )
  items += example_items
  items = ParityInventory.dedupe_items(items)
end

if items.empty?
  warn "No #{language} items found under #{base}"
  exit 1
end

ParityInventory.write_inventory(out, items)
count = items.length
puts "Generated #{out} (#{count} items) from #{base}."
