require 'pathname'
require 'set'

module CodeCounter
  class Engine
    BIN_DIRECTORIES = Set.new
    STATS_DIRECTORIES = []
    TEST_TYPES = []

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
      @ignore_files.include?(File.expand_path(file_path))
    end

    def calculate_group_statistics(directories, pattern = FILTER)
      stats = { "lines" => 0, "codelines" => 0, "classes" => 0, "methods" => 0 }

      directories.each do |directory|
        Dir.foreach(directory) do |file_name|
          next if file_name =~ /\A\.\.?\Z/
          next unless @bin_dirs.include?(directory) || file_name =~ pattern
          file_path = File.join(directory, file_name)
          next if ignore_file?(file_path)

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

      return stats
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
