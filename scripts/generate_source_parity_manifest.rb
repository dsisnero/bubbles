#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require_relative "parity_inventory_lib"

options = {
  root_dir: Dir.pwd,
  out: nil,
  source_path: ENV["PORT_SOURCE_DIR"],
  language: ENV["PORT_LANGUAGE"] || "go",
  parser: ENV["PORT_PARSER"] || "auto",
  notes_overrides: nil,
  force_overwrite: ENV["PORT_FORCE_OVERWRITE"] == "1"
}

OptionParser.new do |opts|
  opts.banner = "Usage: generate_source_parity_manifest.rb [options]"
  opts.on("--root DIR", "Project root (default: pwd)") { |v| options[:root_dir] = v }
  opts.on("--out FILE", "Output TSV path") { |v| options[:out] = v }
  opts.on("--source PATH", "Source path (absolute or relative to root)") { |v| options[:source_path] = v }
  opts.on("--language LANG", "Language: go|rust|crystal|java|ruby") { |v| options[:language] = v }
  opts.on("--parser MODE", "Parser: auto|regex|tree-sitter") { |v| options[:parser] = v }
  opts.on("--notes-overrides FILE", "Optional TSV file: source_api_id<TAB>notes") { |v| options[:notes_overrides] = v }
  opts.on("--force-overwrite", "Allow overwriting an existing source parity file") { options[:force_overwrite] = true }
end.parse!

language = options[:language]
out = options[:out] || File.join(options[:root_dir], "plans/inventory/#{language}_source_parity.tsv")
notes_overrides_path = options[:notes_overrides] || File.join(options[:root_dir], "plans/inventory/#{language}_source_notes.tsv")

if File.exist?(out) && !options[:force_overwrite]
  warn "Refusing to overwrite existing source parity manifest: #{out}"
  warn "Use check_source_parity.sh for drift checks."
  warn "If you intentionally want to reset, rerun with --force-overwrite or PORT_FORCE_OVERWRITE=1."
  exit 1
end

base, items = ParityInventory.discover_items(
  root_dir: options[:root_dir],
  source_path: options[:source_path],
  language: language,
  parser_mode: options[:parser]
)

source_items = items.select { |item| item.scope == "source" }
if source_items.empty?
  warn "No #{language} source API items found under #{base}"
  exit 1
end

notes_overrides = ParityInventory.load_notes_overrides(notes_overrides_path)
ParityInventory.write_scope_manifest(
  out,
  source_items,
  scope: "source",
  header_id: "source_api_id",
  notes_overrides: notes_overrides
)
puts "Generated #{out} (#{source_items.length} source API items) from #{base}."
