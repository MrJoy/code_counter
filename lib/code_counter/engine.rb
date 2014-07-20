require 'set'
require 'pathname'

module CodeCounter
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

    def self.enumerate_directory(directory)
      return Dir.entries(directory).
        reject { |dirent| dirent =~ /^\.\.?$/ }.
        map { |dirent| File.join(directory, dirent) }.
        reject { |dirent| !File.directory?(dirent) }
    end


    def self.add_path(key, directory, recursive=true, is_bin_dir=false)
      directory = File.expand_path(directory)
      if File.directory?(directory)
        STATS_DIRECTORIES << [key, directory]
        BIN_DIRECTORIES << directory if is_bin_dir
        if(recursive)
          enumerate_directory(directory).
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
    DEFAULT_PATHS = [
      ["Controllers", "app/controllers"],
      ["Mailers",     "app/mailers"],
      ["Models",      "app/models"],
      ["Views",       "app/views"],
      ["Helpers",     "app/helpers"],
      ["Binaries",    "bin",              true, true],
      ["Binaries",    "script",           true, true],
      ["Binaries",    "scripts",          true, true],
      ["Libraries",   "lib"],
      ["Source",      "source"],
      ["Source",      "src"],
      ["Unit tests",  "test"],
      ["RSpec specs", "spec"],
      ["Features",    "features"],
    ]

    DEFAULT_TEST_GROUPS = [
      "Unit tests",
      "RSpec specs",
      "Features",
    ]

    def self.init!
      DEFAULT_PATHS.each do |path_info|
        add_path(*path_info)
      end

      DEFAULT_TEST_GROUPS.each do |key|
        add_test_group(key)
      end
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
      @pairs.inject({}) do |stats, pair|
        stats[pair.first] = calculate_group_statistics(pair.last)
        stats
      end
    end

    def ignore_file?(file_path)
      @ignore_files.include?(file_path)
    end

    def blank_stats
      return BLANK_STATS_TEMPLATE.dup
    end

    def calculate_group_statistics(directories, pattern = FILTER)
      stats = blank_stats

      directories.each do |directory|
        Dir.foreach(directory) do |file|
          path = Pathname.new(File.join(directory, file))
          next unless is_eligible_file?(path, pattern)

          # Now, go ahead and analyze the file.
          File.open(path) do |fh|
            while line = fh.gets
              next if(line.strip == "") # Ignore purely whitespace lines.
              stats["lines"] += 1
              # TODO: Should we try to count modules?
              stats["classes"] += 1 if line =~ /class [A-Z]/
              # TODO: Incorporate all Cucumber aliases, break out support for
              # TODO: different testing tools into something more
              # TODO: modular/extensible.
              #
              # TODO: Are there alternative syntaxes that this won't pick up
              # TODO: properly?
              stats["methods"] += 1 if line =~ /(def [a-z]|should .* do|test .* do|it .* do|(Given|When|Then) .* do)/
              stats["codelines"] += 1 unless line =~ /^\s*$/ || line =~ /^\s*#/
            end
          end
        end
      end

      return stats
    end

    def is_eligible_file?(path, pattern)
      basename        = path.basename.to_s
      dirname         = path.dirname.to_s

      is_special_dir  = basename =~ /\A\.\.?\Z/
      is_expected_ext = basename =~ pattern
      is_ignored      = ignore_file?(path.to_s)
      is_bin_dir      = @bin_dirs.include?(dirname)

      return false if is_special_dir ||
                      is_ignored ||
                      (!is_expected_ext && is_bin_dir && !is_shell_program?(path)) ||
                      (!is_expected_ext && !is_bin_dir)

      return true
    end

    # Make a stab at determining if the file specified is a shell program by
    # seeing if it has a shebang line.
    def is_shell_program?(path)
      magic_word = File.open(path, "r", { :encoding => "ASCII-8BIT" }) do |fh|
        fh.read(2)
      end
      return magic_word == '#!'
    end

    def calculate_total
      total = blank_stats
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

    # TODO: Make this respond to changes caused by `.add_path` and
    # TODO: `.add_test_group`.
    COL_WIDTHS      = [[22,-1], [7,1], [7,1], [9,1], [9,1], [5,1], [7,1]]
    HEADERS         = ['Name', 'Lines', 'LOC', 'Classes', 'Methods', 'M/C', 'LOC/M']

    HEADER_PATTERN  = '|' + COL_WIDTHS.map { |(w,_)| " %-#{w}s " }.join('|') + "|\n"
    ROW_PATTERN     = '|' + COL_WIDTHS.map { |(w,d)| " %#{w*d}s " }.join('|') + "|\n"
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

      @print_buffer << ROW_PATTERN % pad_elements(arrange_line_data(name, stats))
    end

    def print_code_test_stats
      code  = calculate_code
      tests = calculate_tests
      ratio = (code != 0) ? "#{sprintf("%.1f", tests.to_f/code)}" : "0.0"

      @print_buffer << " Code LOC: #{code}  Test LOC: #{tests}  Code to Test Ratio: 1:#{ratio}\n"
      @print_buffer << "\n"
    end

    private

    def compute_effective_loc_over_m(stats)
      # Ugly hack for subtracting out class/end.  >.<
      loc_over_m  = x_over_y(stats["codelines"], stats["methods"])
      loc_over_m -= 2 if loc_over_m >= 2
      return loc_over_m
    end

    def arrange_line_data(name, stats)
      return [
        name,
        stats['lines'],
        stats['codelines'],
        stats['classes'],
        stats['methods'],
        x_over_y(stats["methods"], stats["classes"]),
        compute_effective_loc_over_m(stats),
      ]
    end

    BLANK_STATS_TEMPLATE = {
      "lines" => 0,
      "codelines" => 0,
      "classes" => 0,
      "methods" => 0,
    }
  end
end
