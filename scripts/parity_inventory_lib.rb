#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

module ParityInventory
  SUPPORTED_LANGUAGES = %w[go rust crystal java ruby typescript].freeze

  Item = Struct.new(:id, :kind, :scope, :file, :name, keyword_init: true)

  module_function

  def resolve_base(root_dir, source_path)
    root = Pathname(root_dir).expand_path
    if source_path && !source_path.strip.empty?
      candidate = Pathname(source_path)
      return candidate.expand_path if candidate.absolute?

      return (root + candidate).expand_path
    end

    vendor = root + 'vendor'
    vendor.exist? ? vendor : root
  end

  # Check if tree-sitter parsing is available, trying:
  # 1. Crystal discovery binary (preferred — supports 10 languages, query patterns, non-blocking)
  # 2. Ruby tree_sitter gem (legacy fallback)
  def detect_treesitter(language)
    return false unless SUPPORTED_LANGUAGES.include?(language)

    # Crystal binary is the preferred tree-sitter backend since it uses
    # tree-sitter Query API with language-specific S-expression patterns
    # and supports non-blocking concurrent file processing.
    return true if detect_crystal_discovery_binary

    # Fallback: Ruby tree_sitter gem
    begin
      require 'tree_sitter'
      possible = [
        "tree_sitter/#{language}",
        "tree_sitter_#{language}",
        "tree-sitter-#{language}"
      ]
      possible.any? do |lib|
        require lib
        true
      rescue LoadError
        false
      end
    rescue LoadError
      false
    end
  end

  # Detect the Crystal discovery binary (chiasmus-discover or equivalent).
  # Returns binary invocation string or nil.
  def detect_crystal_discovery_binary
    @detect_crystal_discovery_binary ||= begin
      # Check for compiled binary first
      candidates = [
        File.join(__dir__, '..', 'bin', 'chiasmus-discover'),
        File.join(__dir__, '..', 'bin', 'chiasmus_discover'),
      ]
      found = candidates.find { |p| File.executable?(p) }
      unless found
        # Try crystal run as fallback
        src = File.join(__dir__, '..', 'src', 'chiasmus_discover.cr')
        found = "crystal run #{src} --" if File.exist?(src)
      end
      found
    end
  end

  def discover_items(root_dir:, source_path:, language:, parser_mode: 'auto')
    raise ArgumentError, "Unsupported language: #{language}" unless SUPPORTED_LANGUAGES.include?(language)

    base = resolve_base(root_dir, source_path)
    raise ArgumentError, "Source directory does not exist: #{base}" unless base.directory?

    parser = effective_parser(language, parser_mode)
    if parser_mode == 'tree-sitter' && parser != 'tree-sitter'
      warn "tree-sitter parser unavailable for #{language}; falling back to regex"
    end

    items = if parser == 'tree-sitter'
              result = discover_with_crystal_discovery(base, language)
              unless result.empty?
                result.each { |item| item[:parser_mode] = 'tree-sitter' }
              end
              result
            else
              discover_with_regex(base, language)
            end

    [base, dedupe_items(items)]
  end

  # Delegate to Crystal discovery binary for tree-sitter-backed parsing.
  # Falls back to regex if binary unavailable or fails.
  def discover_with_crystal_discovery(base, language)
    discover_bin = detect_crystal_discovery_binary
    unless discover_bin
      warn "Crystal discovery binary not found; falling back to regex"
      return discover_with_regex(base, language)
    end

    begin
      output = IO.popen([discover_bin, '--language', language, '--dir', base.to_s, '--parser', 'tree-sitter'], &:read)
      items = []
      output.each_line do |line|
        next if line.start_with?('#') || line.strip.empty?
        cols = line.split("\t", -1)
        next unless cols.length >= 2

        source_id = cols[0].strip
        kind = cols[1].strip
        parts = source_id.split('::', 3)
        next unless parts.length >= 3

        file = parts[0]
        item_kind = parts[1]
        name = parts[2]
        scope = item_kind == 'test' ? 'test' : 'source'

        items << Item.new(
          id: source_id,
          kind: kind,
          scope: scope,
          file: file,
          name: name
        )
      end
      items
    rescue => e
      warn "Crystal discovery failed: #{e.message}; falling back to regex"
      discover_with_regex(base, language)
    end
  end

  def effective_parser(language, parser_mode)
    mode = parser_mode.to_s
    return 'regex' if mode.empty? || mode == 'regex'
    return detect_treesitter(language) ? 'tree-sitter' : 'regex' if mode == 'tree-sitter'
    return detect_treesitter(language) ? 'tree-sitter' : 'regex' if mode == 'auto'

    raise ArgumentError, "Invalid parser mode: #{parser_mode} (expected auto|regex|tree-sitter)"
  end

  def dedupe_items(items)
    seen = Set.new
    items.select do |item|
      key = [item.id, item.kind, item.scope]
      next false if seen.include?(key)

      seen << key
      true
    end.sort_by(&:id)
  end

  def discover_with_regex(base, language)
    entries = files_for_language(base, language)
    source_items = []
    test_items = []

    entries.each do |path, rel|
      begin
        content = File.read(path, encoding: 'UTF-8')
      rescue Encoding::InvalidByteSequenceError, ArgumentError => e
        # Skip binary or invalid encoding files (like AppleDouble ._ files)
        warn "Skipping file with encoding issues: #{rel} (#{e.message})"
        next
      end
      src, test = case language
                  when 'go' then extract_go(rel, content)
                  when 'rust' then extract_rust(rel, content)
                  when 'crystal' then extract_crystal(rel, content)
                  when 'java' then extract_java(rel, content)
                  when 'ruby' then extract_ruby(rel, content)
                  when 'typescript' then extract_typescript(rel, content)
                  else [[], []]
                  end
      source_items.concat(src) unless test_file_for_language?(language, rel)
      test_items.concat(test)
    end

    source_items + test_items
  end

  def files_for_language(base, language)
    files = Dir.glob('**/*', File::FNM_DOTMATCH, base: base.to_s)
               .reject do |f|
      f.start_with?('.') ||
        f.include?('/.git/') ||
        f.end_with?('/.git') ||
        appledouble_path?(f)
    end

    selected = files.select do |rel|
      full = base + rel
      next false unless full.file?

      case language
      when 'go'
        rel.end_with?('.go')
      when 'rust'
        rel.end_with?('.rs')
      when 'crystal'
        rel.end_with?('.cr')
      when 'java'
        rel.end_with?('.java')
      when 'ruby'
        rel.end_with?('.rb')
      when 'typescript'
        rel.end_with?('.ts', '.js')
      else
        false
      end
    end

    selected.sort.map { |rel| [(base + rel).to_s, rel] }
  end

  def appledouble_path?(path)
    path.split('/').any? { |segment| segment.start_with?('._') }
  end

  def emit_source(rel, kind, name)
    Item.new(id: "#{rel}::#{kind}::#{name}", kind: kind, scope: 'source', file: rel, name: name)
  end

  def emit_test(rel, name)
    Item.new(id: "#{rel}::test::#{name}", kind: 'test', scope: 'test', file: rel, name: name)
  end

  def test_file_for_language?(language, rel)
    case language
    when 'go'
      rel.end_with?('_test.go')
    when 'crystal'
      rel.end_with?('_spec.cr') || rel.start_with?('spec/')
    when 'java'
      rel.include?('/test/') || rel.end_with?('Test.java')
    when 'ruby'
      rel.end_with?('_spec.rb', '_test.rb') || rel.start_with?('spec/') || rel.start_with?('test/')
    when 'typescript'
      rel.end_with?('.test.ts', '.spec.ts', '.test.js', '.spec.js') || rel.include?('/test/') || rel.include?('/tests/')
    else
      false
    end
  end

  def extract_go(rel, text)
    source = []
    tests = []

    in_const_block = false

    text.each_line do |line|
      stripped = line.strip

      if stripped.match?(/^const\s*\(/)
        in_const_block = true
        next
      end

      if in_const_block
        if stripped == ')'
          in_const_block = false
        elsif (m = stripped.match(/^([A-Z][A-Za-z0-9_]*)\b/))
          source << emit_source(rel, 'const', m[1])
        end
        next
      end

      if (m = stripped.match(/^const\s+([A-Z][A-Za-z0-9_]*)\b/))
        source << emit_source(rel, 'const', m[1])
      end

      if (m = stripped.match(/^type\s+([A-Z][A-Za-z0-9_]*)\b/))
        kind = stripped.include?(' struct') || stripped.end_with?('struct{') || stripped.end_with?('struct {') ? 'struct' : 'type'
        source << emit_source(rel, kind, m[1])
      end

      if (m = stripped.match(/^func\s+([A-Z][A-Za-z0-9_]*)\s*\(/))
        source << emit_source(rel, 'func', m[1])
      end

      if (m = stripped.match(/^func\s+\(([^)]+)\)\s+([A-Z][A-Za-z0-9_]*)\s*\(/))
        recv = m[1].split.last.to_s.delete('*')
        source << emit_source(rel, 'method', "#{recv}.#{m[2]}") unless recv.empty?
      end

      if (m = stripped.match(/^func\s+(Test[A-Za-z0-9_]*)\s*\(/))
        tests << emit_test(rel, m[1])
      end
    end

    [source, tests]
  end

  def extract_rust(rel, text)
    source = []
    tests = []

    pub_impl = nil
    pending_test_attr = false

    text.each_line do |line|
      stripped = line.strip

      if (m = stripped.match(/^pub\s+const\s+([A-Z][A-Za-z0-9_]*)\b/))
        source << emit_source(rel, 'const', m[1])
      end
      if (m = stripped.match(/^pub\s+struct\s+([A-Z][A-Za-z0-9_]*)\b/))
        source << emit_source(rel, 'struct', m[1])
      end
      if (m = stripped.match(/^pub\s+enum\s+([A-Z][A-Za-z0-9_]*)\b/))
        source << emit_source(rel, 'enum', m[1])
      end
      if (m = stripped.match(/^pub\s+trait\s+([A-Z][A-Za-z0-9_]*)\b/))
        source << emit_source(rel, 'trait', m[1])
      end
      if (m = stripped.match(/^pub\s+type\s+([A-Z][A-Za-z0-9_]*)\b/))
        source << emit_source(rel, 'type', m[1])
      end
      if (m = stripped.match(/^pub\s+fn\s+([a-zA-Z_][A-Za-z0-9_]*)\s*\(/))
        source << emit_source(rel, 'func', m[1])
      end

      if (m = stripped.match(/^impl(?:<[^>]+>)?\s+([A-Z][A-Za-z0-9_:]*)/))
        pub_impl = m[1]
      elsif stripped.start_with?('}')
        pub_impl = nil
      elsif pub_impl && (m = stripped.match(/^pub\s+fn\s+([a-zA-Z_][A-Za-z0-9_]*)\s*\(/))
        source << emit_source(rel, 'method', "#{pub_impl}.#{m[1]}")
      end

      pending_test_attr = true if stripped.start_with?('#[test]')
      if pending_test_attr && (m = stripped.match(/^fn\s+([a-zA-Z_][A-Za-z0-9_]*)\s*\(/))
        tests << emit_test(rel, m[1])
        pending_test_attr = false
      end
    end

    [source, tests]
  end

  def extract_crystal(rel, text)
    source = []
    tests = []

    namespace = []

    text.each_line do |line|
      stripped = line.strip

      if (m = stripped.match(/^(class|module|struct|enum)\s+([A-Z][A-Za-z0-9_:]*)/))
        kind = m[1]
        name = m[2]
        source << emit_source(rel, kind, name)
        namespace << name
        next
      end

      if stripped == 'end'
        namespace.pop unless namespace.empty?
        next
      end

      if (m = stripped.match(/^([A-Z][A-Z0-9_]*)\s*=/))
        source << emit_source(rel, 'const', m[1])
      end

      if (m = stripped.match(/^def\s+(self\.)?([a-z_][A-Za-z0-9_!?=]*)\b/))
        recv = namespace.last
        name = m[2]
        kind = m[1] ? 'func' : 'method'
        id_name = recv ? "#{recv}.#{name}" : name
        source << emit_source(rel, kind, id_name)
      end

      if (m = stripped.match(/^it\s+"([^"]+)"/))
        tests << emit_test(rel, m[1])
      end
    end

    if rel.end_with?('_spec.cr')
      text.each_line do |line|
        stripped = line.strip
        if (m = stripped.match(/^describe\s+([A-Za-z0-9_:"'. ]+)/))
          tests << emit_test(rel, m[1])
        end
      end
    end

    [source, tests]
  end

  def extract_java(rel, text)
    source = []
    tests = []

    current_type = nil
    pending_test_attr = false

    text.each_line do |line|
      stripped = line.strip

      if (m = stripped.match(/^public\s+(class|interface|enum|record)\s+([A-Z][A-Za-z0-9_]*)\b/))
        source << emit_source(rel, m[1], m[2])
        current_type = m[2]
      end

      if (m = stripped.match(/^public\s+static\s+final\s+[A-Za-z0-9_<>, ?\[\]]+\s+([A-Z][A-Z0-9_]*)\b/))
        source << emit_source(rel, 'const', m[1])
      end

      if (m = stripped.match(/^public\s+(?:static\s+)?[A-Za-z0-9_<>, ?\[\]]+\s+([a-zA-Z_][A-Za-z0-9_]*)\s*\(/))
        next if %w[if for while switch catch].include?(m[1])

        source << if current_type && m[1] == current_type
                    emit_source(rel, 'ctor', "#{current_type}.#{m[1]}")
                  elsif current_type
                    emit_source(rel, 'method', "#{current_type}.#{m[1]}")
                  else
                    emit_source(rel, 'func', m[1])
                  end
      end

      pending_test_attr = true if stripped == '@Test'
      if pending_test_attr && (m = stripped.match(/^(public\s+)?void\s+([a-zA-Z_][A-Za-z0-9_]*)\s*\(/))
        tests << emit_test(rel, m[2])
        pending_test_attr = false
      end
    end

    [source, tests]
  end

  def extract_ruby(rel, text)
    source = []
    tests = []

    namespace = []

    text.each_line do |line|
      stripped = line.strip

      if (m = stripped.match(/^(class|module)\s+([A-Z][A-Za-z0-9_:]*)/))
        source << emit_source(rel, m[1], m[2])
        namespace << m[2]
        next
      end

      if stripped == 'end'
        namespace.pop unless namespace.empty?
        next
      end

      if (m = stripped.match(/^([A-Z][A-Z0-9_]*)\s*=/))
        source << emit_source(rel, 'const', m[1])
      end

      if (m = stripped.match(/^def\s+(self\.)?([a-z_][A-Za-z0-9_!?=]*)/))
        recv = namespace.last
        name = m[2]
        kind = m[1] ? 'func' : 'method'
        source << emit_source(rel, kind, recv ? "#{recv}.#{name}" : name)
      end

      if (m = stripped.match(/^def\s+(test_[A-Za-z0-9_]+)/))
        tests << emit_test(rel, m[1])
      end
      if (m = stripped.match(/^it\s+["'](.+?)["']/))
        tests << emit_test(rel, m[1])
      end
      if (m = stripped.match(/^test\s+["'](.+?)["']/))
        tests << emit_test(rel, m[1])
      end
    end

    [source, tests]
  end
  def extract_typescript(rel, text)
    source = []
    tests = []

    namespace = []
    in_interface = false
    in_type_alias = false

    text.each_line do |line|
      stripped = line.strip

      # Handle export keyword
      stripped = stripped.sub('export ', '').strip if stripped.start_with?('export ')

      # Class definitions
      if (m = stripped.match(/^(abstract\s+)?class\s+([A-Z][A-Za-z0-9_$]*)/))
        source << emit_source(rel, 'class', m[2])
        namespace << m[2]
        next
      end

      # Interface definitions
      if (m = stripped.match(/^interface\s+([A-Z][A-Za-z0-9_$]*)/))
        source << emit_source(rel, 'interface', m[1])
        in_interface = true
        next
      end

      # Type alias definitions
      if (m = stripped.match(/^type\s+([A-Z][A-Za-z0-9_$]*)\s*=/))
        source << emit_source(rel, 'type', m[1])
        in_type_alias = true
        next
      end

      # Function definitions
      if (m = stripped.match(/^function\s+([a-z_][A-Za-z0-9_$]*)/))
        source << emit_source(rel, 'function', m[1])
        next
      end

      # Method definitions in classes
      # Check if this looks like a method (not a function call)
      if (m = stripped.match(/^([a-z_][A-Za-z0-9_$]*)\s*\(/)) && !namespace.empty? && !stripped.start_with?('if ', 'for ',
                                                                                                            'while ', 'switch ', 'return ', 'throw ')
        source << emit_source(rel, 'method', "#{namespace.last}.#{m[1]}")
      end

      # Arrow functions (const/let/var assignments)
      if (m = stripped.match(/^(const|let|var)\s+([a-z_][A-Za-z0-9_$]*)\s*=\s*(async\s*)?\(/))
        source << emit_source(rel, 'function', m[2])
      end

      # Constant declarations
      if (m = stripped.match(/^(const|let|var)\s+([A-Z][A-Z0-9_$]*)\s*=/))
        source << emit_source(rel, 'const', m[2])
      end

      # Test functions (describe, it, test)
      if (m = stripped.match(/^describe\s*\(\s*["'](.+?)["']/))
        tests << emit_test(rel, m[1])
      end
      if (m = stripped.match(/^it\s*\(\s*["'](.+?)["']/))
        tests << emit_test(rel, m[1])
      end
      if (m = stripped.match(/^test\s*\(\s*["'](.+?)["']/))
        tests << emit_test(rel, m[1])
      end

      # End of interface or type alias
      if stripped == '}' && (in_interface || in_type_alias)
        in_interface = false
        in_type_alias = false
      end

      # End of class
      namespace.pop if stripped == '}' && !namespace.empty?
    end

    [source, tests]
  end

  def write_inventory(path, items)
    FileUtils.mkdir_p(File.dirname(path))
    File.open(path, 'w') do |f|
      f.puts "# source_id\tkind\tstatus\tcrystal_refs\tnotes"
      items.each do |item|
        f.puts "#{item.id}\t#{item.kind}\tmissing\t-\tauto-generated"
      end
    end
  end

  def write_scope_manifest(path, items, scope:, header_id:, notes_overrides: {})
    FileUtils.mkdir_p(File.dirname(path))
    File.open(path, 'w') do |f|
      f.puts "# #{header_id}\tstatus\tcrystal_refs\tnotes"
      items.select { |item| item.scope == scope }
           .sort_by(&:id)
           .each do |item|
        notes = notes_overrides[item.id] || 'baseline'
        f.puts "#{item.id}\tmissing\t-\t#{notes}"
      end
    end
  end

  def load_notes_overrides(path)
    return {} unless path && File.file?(path)

    overrides = {}
    File.readlines(path, chomp: true).each_with_index do |line, idx|
      next if line.start_with?('#') || line.strip.empty?

      cols = line.split("\t", -1)
      if cols.length < 2
        raise "Malformed notes override row #{idx + 1} in #{path}: expected 2 columns (source_api_id\\tnotes)"
      end

      source_id = cols[0].to_s.strip
      note = cols[1].to_s.strip
      next if source_id.empty?

      overrides[source_id] = note.empty? ? '-' : note
    end
    overrides
  end

  def load_manifest_rows(path, min_cols:)
    rows = []
    File.readlines(path, chomp: true).each_with_index do |line, idx|
      next if line.start_with?('#') || line.strip.empty?

      cols = line.split("\t", -1)
      raise "Malformed manifest row #{idx + 1} in #{path}: expected >= #{min_cols} columns" if cols.length < min_cols

      rows << cols
    end
    rows
  end
end
