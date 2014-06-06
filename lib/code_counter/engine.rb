require 'set'
require 'ripper'

module CodeCounter
  module Ruby
    class TreeProcessor
      def initialize(tree)
        @result = process(tree)
      end

      def result
        return @result
      end

      def check_remainder!(kind, remainder)
        return unless remainder && !remainder.empty?
        raise "Expected no remainder for :#{kind} node, got: #{remainder.inspect}!"
      end

      def find_program(tree)
        term      = tree.shift
        children  = tree.shift
        remainder = tree
        check_remainder!(term, remainder)

        return {
          :kind     => term,
          :children => children.map { |child| process(child) }.compact,
        }
      end

      def find_class_or_module(tree)
        term      = tree.shift
        name      = tree.shift
        tree.shift if term == :class # Thing this class inherits from, if any.
        children  = tree.shift
        remainder = tree
        check_remainder!(term, remainder)

        line_numbers = (slurp(name) + slurp(children)).flatten.sort.uniq

        return {
          :kind     => term,
          :name     => process(name),
          :children => children.map { |node| process(node) }.compact,
          :lines    => (line_numbers.min..line_numbers.max),
        }
      end

      def find_method(tree)
        term      = tree.shift
        name      = tree.shift
        params    = tree.shift
        children  = tree.shift
        remainder = tree
        check_remainder!(term, remainder)

        line_numbers = slurp(children).sort.uniq

        return {
          :kind     => term,
          :name     => process(name),
          :children => process(children),
          :lines    => (line_numbers.min..line_numbers.max),
        }
      end

      def slurp(tree)
        return [] unless tree.kind_of?(Array)
        remainder = tree.dup

        return remainder.
          map { |node| is_file_position?(node) ? node.first : slurp(node) }.
          flatten.
          compact
      end

      def is_file_position?(node)
        return node.kind_of?(Array) &&
               node.length == 2 &&
               node.first.kind_of?(Integer) &&
               node.last.kind_of?(Integer)
      end

      def find_name_chain(tree)
        term      = tree.shift
        children  = tree

        valid_children = children.
          map { |child| process(child) }.
          flatten.
          select { |child| child.kind_of?(String) }

        raise "Expected name-like things in node :#{term}, got: #{children.inspect}" unless valid_children.length == children.length

        return valid_children.join('::')
      end

      def find_constant(tree)
        (term, name, position, remainder) = *tree

        check_remainder!(term, remainder)

        return name
      end

      def process(tree)
        return nil if !tree || tree.kind_of?(Symbol)
        return tree unless tree.kind_of?(Array)
        tree = tree.dup # Don't mutate the state, lest someone up the call
                        # chain get surprised...

        case tree[0]
        when :program
          find_program(tree)
        when :class, :module
          find_class_or_module(tree)
        when :def
          find_method(tree)
        when :const_path_ref, :const_ref, :var_ref
          find_name_chain(tree)
        when :@const, :@ident, :class_name_error
          find_constant(tree)
        when Array
          processed = tree.
            select { |node| node.kind_of?(Array) }.
            map { |node| process(node) }.
            compact
          processed = processed.first if processed.length == 1
        end
      end
    end
  end

  class Engine
    BIN_DIRECTORIES = Set.new
    STATS_DIRECTORIES = []
    TEST_TYPES = Set.new

    ###########################################################################
    # Mechanisms for configuring the behavior of this tool
    ###########################################################################
    def self.clear!
      BIN_DIRECTORIES.clear
      STATS_DIRECTORIES.clear
      TEST_TYPES.clear
    end

    def self.add_path(key, directory, recursive=true, is_bin_dir=false)
      directory = File.expand_path(directory)
      if File.directory?(directory)
        STATS_DIRECTORIES << [key, directory]
        BIN_DIRECTORIES << directory if is_bin_dir
        if(recursive)
          Dir.entries(directory).
            reject { |dirent| dirent =~ /^\.\.?$/ }.
            map { |dirent| File.join(directory, dirent) }.
            reject { |dirent| !File.directory?(dirent) }.
            each { |dirent| add_path(key, dirent, recursive, is_bin_dir) }
        end
      end
    end

    def self.add_test_group(key)
      TEST_TYPES << key
    end


    ###########################################################################
    # Default configuration
    ###########################################################################
    def self.init!
      add_path("Controllers", "app/controllers")
      add_path("Mailers", "app/mailers")
      add_path("Models", "app/models")
      add_path("Views", "app/views")
      add_path("Helpers", "app/helpers")
      add_path("Binaries", "bin", true, true)
      add_path("Binaries", "script", true, true)
      add_path("Binaries", "scripts", true, true)
      add_path("Libraries", "lib")
      add_path("Source", "source")
      add_path("Source", "src")
      add_path("Unit tests", "test")
      add_path("RSpec specs", "spec")
      add_path("Features", "features")

      add_test_group("Unit tests")
      add_test_group("RSpec specs")
      add_test_group("Features")
    end
    init!


    ###########################################################################
    # Internals
    ###########################################################################
    FILTER = /.*\.(rb|feature|rake)$/
    attr_reader :print_buffer

    def initialize(ignore_file_globs = [])
      @bin_dirs     = BIN_DIRECTORIES.dup
      @pairs        = STATS_DIRECTORIES.select { |pair| File.directory?(pair[1]) }
      @print_buffer = ""
      @ignore_files = collect_files_to_ignore(ignore_file_globs)

      @pairs = coalesce_pairs(@pairs)

      @statistics  = calculate_statistics
      @total       = (@pairs.length > 1) ? calculate_total : nil
    end

    def coalesce_pairs(pairs)
      groups = {}
      paths_seen = {}
      pairs.each do |pair|
        next if(paths_seen[pair.last])
        paths_seen[pair.last] = true
        (groups[pair.first] ||= Set.new) << pair.last
      end
      return groups
    end

    def collect_files_to_ignore(ignore_file_globs)
      files_to_remove = []
      ignore_file_globs.each do |glob|
        files_to_remove.concat(Dir[glob])
      end
      files_to_remove.map { |filepath| File.expand_path(filepath) }
    end

    def to_s
      @print_buffer = ''
      print_header
      @pairs.each { |pair| print_line(pair.first, @statistics[pair.first]) }
      print_splitter

      if @total
        print_line("Total", @total)
        print_splitter
      end

      print_code_test_stats
      @print_buffer
    end

    private

    def calculate_statistics
      @pairs.inject({}) { |stats, pair| stats[pair.first] = calculate_group_statistics(pair.last); stats }
    end

    def ignore_file?(file_path)
      @ignore_files.include?(file_path)
    end

    # Don't care about these as the line count will be the same either way,
    # and including some of them would just make analysis a smidge more
    # annoying.
    TOKENS_TO_IGNORE = Set.new([
      :on_embdoc_beg, :on_embdoc_end, :on_sp, :on_nl, :on_ignored_nl,
    ])

    # After stripping out the above, the following represent kinds of comments
    # we may see.
    COMMENT_TOKENS = Set.new([:on_comment, :on_embdoc])

    def calculate_group_statistics(directories, pattern = FILTER)
      stats = { "lines" => 0, "codelines" => 0, "classes" => 0, "methods" => 0 }

      class_cache         = {}
      module_cache        = {}

      directories.each do |directory|
        Dir.foreach(directory) do |file_name|
          next if file_name =~ /\A\.\.?\Z/
          is_expected_ext = file_name =~ pattern
          next unless @bin_dirs.include?(directory) || is_expected_ext
          file_path = File.expand_path(File.join(directory, file_name))
          next if ignore_file?(file_path)

          # First, check if a file with an unknown extension is binary...
          next unless is_expected_ext || is_shell_program?(file_path)

          # Now, go ahead and analyze the file.
puts "#{file_name}:"
lines       = []
contents    = File.read(file_path)
in_heredoc  = false
# sexp      = Ripper.sexp_raw(contents, file_path)

Ripper.
  lex(contents, file_path).
  each do |((line_no, col_no), kind, token)|
    lines[line_no-1] ||= []

    # Skip whitespace and other things we don't care about in our filtered
    # version of this data.
    next if TOKENS_TO_IGNORE.include?(kind)
    in_heredoc = true if kind == :on_heredoc_beg
    next if in_heredoc || kind == :on_heredoc_end
    in_heredoc = false

    # Record tokens we DO care about, grouped by line.
    lines[line_no-1] << {
      :line => line_no,
      :pos => lines[line_no-1].length,
      :col => col_no,
      :kind => kind,
      :token => token,
    }
  end
require 'pp'
tree = Ripper.sexp(contents, file_path)
pp tree
puts "------"
pp CodeCounter::Ruby::TreeProcessor.new(tree).result

num_lines           = lines.length
num_comment_lines   = 0
num_inline_comments = 0
num_blended_lines   = 0
lines.
  select { |line| line && line.length > 0 }.
  each do |line|
    comment = line.find { |token| COMMENT_TOKENS.include?(token[:kind]) }
    if comment
      if comment[:pos] == 0
        # Found a whole-line comment.
        num_comment_lines += 1
      else
        # Found a postfix comment.
        num_inline_comments += 1
      end
    end

    class_idx = keyword_index(line, 'class')
    if class_idx
      class_token       = line[class_idx]
      class_name_token  = line[class_idx + 1]
      remainder         = line[(class_idx+1)..-1]
      semi_idx          = semicolon_index(remainder)
      remainder         = semi_idx ? remainder[(semi_idx+1)..-1] : []

      # We have something after the semicolon...
      if remainder.length > 0
        # TODO: Differentiate between intra-class code, and actual method defs.
        num_blended_lines += 1
      end

      (class_cache[class_name_token[:token]] ||= Set.new) << file_path
    end
  end
# puts "Lines: #{num_lines}, Comment Lines: #{num_comment_lines}, Inline Comments: #{num_inline_comments}"
# puts "Blended Lines: #{num_blended_lines}"
puts

          File.open(file_path) do |fh|
            while line = fh.gets
              stats["lines"] += 1
              stats["classes"] += 1 if line =~ /class [A-Z]/
              stats["methods"] += 1 if line =~ /(def [a-z]|should .* do|test .* do|it .* do|(Given|When|Then) .* do)/
              stats["codelines"] += 1 unless line =~ /^\s*$/ || line =~ /^\s*#/
            end
          end
        end
      end
# puts "Classes: #{class_cache.keys.length}, Modules: #{module_cache.keys.length}"
# class_cache.each do |klass, files|
#   puts "  #{klass}: #{files.sort.join(", ")}"
# end

      return stats
    end

    def keyword_index(tokens, keyword)
      return tokens.
        find_index { |t| t[:kind] == :on_kw && t[:token] == keyword }
    end

    def semicolon_index(tokens)
      return tokens.
        find_index { |t| t[:kind] == :on_semicolon }
    end

    def is_shell_program?(path)
      magic_word = File.open(path, "r", { :encoding => "ASCII-8BIT" }) do |fh|
        fh.read(2)
      end
      return magic_word == '#!'
    end

    def calculate_total
      total = { "lines" => 0, "codelines" => 0, "classes" => 0, "methods" => 0 }
      @statistics.each_value { |pair| pair.each { |k, v| total[k] += v } }
      total
    end

    def calculate_code
      calculate_type(false)
    end

    def calculate_tests
      calculate_type(true)
    end

    def calculate_type(test_match)
      type_loc = 0
      @statistics.each { |k, v| type_loc += v['codelines'] if TEST_TYPES.include?(k)==test_match }
      type_loc
    end

    COL_WIDTHS      = [[22,-1], [7,1], [7,1], [9,1], [9,1], [5,1], [7,1]]
    HEADER_PATTERN  = '|' + COL_WIDTHS.map { |(w,_)| "%-#{w}s" }.join('|') + "|\n"
    ROW_PATTERN     = '|' + COL_WIDTHS.map { |(w,d)| "%#{w*d}s" }.join('|') + "|\n"
    HEADERS         = ['Name', 'Lines', 'LOC', 'Classes', 'Methods', 'M/C', 'LOC/M']
    SPLITTER        = HEADER_PATTERN % COL_WIDTHS.map { |(w,_)| '-' * w }

    def pad_elements(list)
      return list.map { |e| " #{e} " }
    end

    def print_header
      print_splitter
      @print_buffer << HEADER_PATTERN % pad_elements(HEADERS)
      print_splitter
    end

    def print_splitter
      @print_buffer << SPLITTER
    end

    def x_over_y(top, bottom)
      return (bottom > 0) ? (top / bottom) : 0
    end

    def print_line(name, stats)
      return if stats['lines'] == 0

      # Ugly hack for subtracting out class/end.  >.<
      loc_over_m  = x_over_y(stats["codelines"], stats["methods"])
      loc_over_m -= 2 if loc_over_m >= 2

      @print_buffer << ROW_PATTERN % pad_elements([
        name,
        stats['lines'],
        stats['codelines'],
        stats['classes'],
        stats['methods'],
        x_over_y(stats["methods"], stats["classes"]),
        loc_over_m,
      ])
    end

    def print_code_test_stats
      code = calculate_code
      tests = calculate_tests

      ratio = if code!=0
        "#{sprintf("%.1f", tests.to_f/code)}"
      else
        "0.0"
      end
      @print_buffer << " Code LOC: #{code}  Test LOC: #{tests}  Code to Test Ratio: 1:#{ratio}\n"
      @print_buffer << "\n"
    end
  end
end
