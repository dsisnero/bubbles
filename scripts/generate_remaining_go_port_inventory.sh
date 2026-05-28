#!/usr/bin/env bash
set -euo pipefail

# Heuristic reducer for active projects that started without parity tracking.
# It infers "already started" by matching Go symbol names against Crystal src
# definitions and Crystal naming conventions.
#
# IMPORTANT: This is not exact. Treat output as triage assistance, then review.
# Prefer authoritative status updates in go_source_parity.tsv/go_test_parity.tsv.
#
# Usage:
#   generate_remaining_go_port_inventory.sh [ROOT_DIR] [INVENTORY] [SRC_DIR] [OUT]
# Defaults:
#   ROOT_DIR=<cwd>
#   INVENTORY=<ROOT_DIR>/plans/inventory/go_port_inventory.tsv
#   SRC_DIR=<ROOT_DIR>/src
#   OUT=<ROOT_DIR>/plans/inventory/go_port_remaining_heuristic.tsv

ROOT_DIR="${1:-$(pwd)}"
INVENTORY="${2:-${ROOT_DIR}/plans/inventory/go_port_inventory.tsv}"
SRC_DIR="${3:-${ROOT_DIR}/src}"
OUT="${4:-${ROOT_DIR}/plans/inventory/go_port_remaining_heuristic.tsv}"

if [[ ! -f "${INVENTORY}" ]]; then
  echo "Missing inventory: ${INVENTORY}" >&2
  exit 1
fi

if [[ ! -d "${SRC_DIR}" ]]; then
  echo "Missing src directory: ${SRC_DIR}" >&2
  exit 1
fi

mkdir -p "$(dirname "${OUT}")"

ruby - "${INVENTORY}" "${SRC_DIR}" "${OUT}" <<'RUBY'
require 'set'
inv = ARGV[0]
src_dir = ARGV[1]
out = ARGV[2]

def snake(s)
  s = s.gsub(/([A-Z]+)([A-Z][a-z])/,'\\1_\\2')
  s = s.gsub(/([a-z\d])([A-Z])/,'\\1_\\2')
  s.tr('-', '_').downcase
end

def upper_snake(s)
  snake(s).upcase
end

def add_name_variants(target_set, name)
  return if name.nil? || name.empty?
  target_set << name
  target_set << snake(name)
  target_set << upper_snake(name)
end

defs = Set.new
props = Set.new
consts = Set.new
types = Set.new

Dir.glob(File.join(src_dir, '**/*.cr')).each do |f|
  File.foreach(f) do |line|
    if line =~ /^\s*def\s+(?:self\.)?([a-zA-Z0-9_!?]+)/
      add_name_variants(defs, $1)
    end

    if line =~ /^\s*(?:class|struct|module|enum)\s+([A-Z][A-Za-z0-9_]*)/
      types << $1
      types << snake($1)
    end

    if line =~ /^\s*([A-Z][A-Za-z0-9_]*)\s*=/
      add_name_variants(consts, $1)
    end

    if line =~ /^\s*(?:getter|property|property\?)\s+(.+)$/
      names_part = $1
      names_part.split(',').each do |chunk|
        name = chunk.strip
        name = name.sub(/^@/, '')
        name = name.split(':', 2).first.strip
        name = name.sub(/\?$/, '')
        add_name_variants(props, name)
      end
    end
  end
end

remaining_rows = []
inferred_started = 0

File.foreach(inv).with_index do |line, idx|
  next if idx == 0 || line.strip.empty? || line.start_with?('#')
  go_id, kind, status, refs, notes = line.chomp.split("\t", 5)
  _file, _k, sym = go_id.split('::', 3)
  sym ||= ''

  started = false
  inferred_by = nil

  case kind
  when 'func'
    candidates = [sym, snake(sym)]
    started = candidates.any? { |c| defs.include?(c) }
    inferred_by = 'func_name' if started
  when 'method'
    meth = sym.split('.', 2)[1] || sym
    candidates = [meth, snake(meth)]
    started = candidates.any? { |c| defs.include?(c) || props.include?(c) }
    inferred_by = 'method_or_property_name' if started
  when 'struct', 'type'
    type_name = sym.split('.', 2).last.to_s
    candidates = [type_name, snake(type_name)]
    started = candidates.any? { |c| types.include?(c) }
    inferred_by = 'type_name' if started
  when 'const'
    candidates = [sym, upper_snake(sym), snake(sym)]
    started = candidates.any? { |c| consts.include?(c) }
    inferred_by = 'const_name_variant' if started
  when 'test'
    started = false
  end

  current = status
  if status == 'missing' && started
    current = 'inferred_started'
    inferred_started += 1
  end

  if %w[missing in_progress partial].include?(current)
    note = notes.to_s
    if note.empty? || note == 'auto-generated'
      note = 'heuristic-filter'
    end
    note = "#{note}; inferred_by=#{inferred_by}" if inferred_by
    remaining_rows << [go_id, kind, current, refs || '', note]
  end
end

File.open(out, 'w') do |f|
  f.puts "# go_id\tkind\tstatus\tcrystal_refs\tnotes"
  remaining_rows.each { |r| f.puts r.join("\t") }
end

warn "Generated #{out} (#{remaining_rows.size} remaining rows; inferred_started=#{inferred_started})."
RUBY

echo "Wrote heuristic remaining inventory: ${OUT}"
