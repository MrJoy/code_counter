require 'set'
require 'code_counter/fs_helpers'
require 'code_counter/reporter'
require 'code_counter/statistics_group'

module CodeCounter
  class Engine
    include CodeCounter::MathHelpers
    include CodeCounter::FSHelpers
    extend CodeCounter::FSHelpers

    SCRIPT_DIRECTORIES = Set.new
    STATS_DIRECTORIES = []
    TEST_TYPES = Set.new
    EXTENSIONS = Set.new
    BARE_FILES = Set.new

    ###########################################################################
    # Mechanisms for configuring the behavior of this tool
    ###########################################################################
    def self.clear!
      SCRIPT_DIRECTORIES.clear
      STATS_DIRECTORIES.clear
      TEST_TYPES.clear
      EXTENSIONS.clear
      BARE_FILES.clear
    end

    def self.add_path(key, directory, recursive = true, is_script_dir = false)
      directory = Pathname.new(directory) unless directory.kind_of?(Pathname)

      directory = canonicalize_directory(directory)
      if directory
        STATS_DIRECTORIES << [key, directory]
        SCRIPT_DIRECTORIES << directory if is_script_dir
        if recursive
          enumerate_directories(directory).
            each { |dirent| add_path(key, canonicalize_directory(dirent), recursive, is_script_dir) }
        end
      end
    end

    def self.add_test_group(key)
      TEST_TYPES << key
    end

    def self.add_bare_file(filename)
      filename = Pathname.new(filename) unless filename.kind_of?(Pathname)

      BARE_FILES << filename.expand_path
    end

    def self.add_extension(extension)
      EXTENSIONS << extension
    end


    ###########################################################################
    # Default configuration
    ###########################################################################
    DEFAULT_PATHS = [
      ['Controllers', 'app/controllers'],
      ['Mailers',     'app/mailers'],
      ['Models',      'app/models'],
      ['Views',       'app/views'],
      ['Helpers',     'app/helpers'],
      ['Scripts',     'bin',              true, true],
      ['Scripts',     'script',           true, true],
      ['Scripts',     'scripts',          true, true],
      ['Libraries',   'lib'],
      ['Source',      'source'],
      ['Source',      'src'],
      ['Unit tests',  'test'],
      ['RSpec specs', 'spec'],
      ['Features',    'features'],
    ]

    DEFAULT_TEST_GROUPS = [
      "Unit tests",
      "RSpec specs",
      "Features",
    ]

    DEFAULT_BARE_FILES = [
      'Gemfile',
      'Rakefile',
      'rakefile',
    ]

    DEFAULT_EXTENSIONS = [
      '.feature',
      '.gemspec',
      '.rake',
      '.rb',
      '.ru',
    ]

    def self.init!
      DEFAULT_PATHS.each do |path_info|
        add_path(*path_info)
      end

      DEFAULT_TEST_GROUPS.each do |key|
        add_test_group(key)
      end

      DEFAULT_BARE_FILES.each do |file_info|
        add_bare_file(file_info)
      end

      DEFAULT_EXTENSIONS.each do |file_info|
        add_extension(file_info)
      end

    end
    # TODO: THis is janky.  Move this to relevant locations for clarity.
    init!


    ###########################################################################
    # Internals
    ###########################################################################
    def initialize(ignore_file_globs = [])
      @reporter     = CodeCounter::Reporter.new

      @script_dirs     = SCRIPT_DIRECTORIES.dup
      @pairs        = STATS_DIRECTORIES.
        map { |pair| [pair.first, canonicalize_directory(pair.last)] }.
        compact { |pair| pair.last }
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
      files_to_remove.map { |filepath| Pathname.new(filepath).expand_path }
    end

    def to_s
      code  = calculate_code
      tests = calculate_tests
      test_ratio = "1:%.1f" % safe_div(tests.to_f, code)

      @reporter.report(@total, @pairs, @statistics, code, tests, test_ratio)
    end

    protected

    def calculate_statistics
      @pairs.inject({}) do |stats, pair|
        stats[pair.first] = calculate_group_statistics(pair.first, pair.last)
        stats
      end
    end

    def ignore_file?(file_path)
      @ignore_files.include?(file_path)
    end

    def calculate_group_statistics(group_name, directories, allowed_extensions = EXTENSIONS)
      stats = CodeCounter::StatisticsGroup.new(group_name)

      directories.each do |directory|
        enumerate_files(directory).each do |path|
          next unless is_eligible_file?(path, allowed_extensions)

          # Now, go ahead and analyze the file.
          lines = File.readlines(path)
          # TODO: Should we try to count modules?
          classes = lines.select { |line| line =~ /class [A-Z]/ }.length
          # TODO: Incorporate all Cucumber aliases, break out support for
          # TODO: different testing tools into something more
          # TODO: modular/extensible.
          #
          # TODO: Are there alternative syntaxes that this won't pick up
          # TODO: properly?
          methods = lines.select { |line| line =~ /(def [a-z]|should .* do|test .* do|it .* do|(Given|When|Then) .* do)/ }.length
          blanks = lines.select { |line| line =~ /^\s*(#.*)?$/ }.length

          stats.add_lines(lines.length, lines.length - blanks)
          stats.add_classes(classes)
          stats.add_methods(methods)
        end
      end

      stats.set_loc_per_method(compute_effective_loc_over_m(stats))

      return stats
    end

    def is_eligible_file?(path, allowed_extensions)
      is_allowed_kind = is_allowed_file_type(path, allowed_extensions)
      is_ignored      = ignore_file?(path)
      is_script_dir      = @script_dirs.include?(path.dirname)

      return false if path.directory? ||
                      is_ignored ||
                      (!is_allowed_kind && is_script_dir && !is_shell_program?(path)) ||
                      (!is_allowed_kind && !is_script_dir)

      return true
    end

    def calculate_total
      total = CodeCounter::StatisticsGroup.new("Total", true)
      @statistics.each_value do |stats|
        total.add_group(stats)
      end
      return total
    end

    def calculate_code
      calculate_type(false)
    end

    def calculate_tests
      calculate_type(true)
    end

    def calculate_type(test_match)
      return @statistics.
        select { |group, _| TEST_TYPES.include?(group) == test_match }.
        map { |_, stats| stats.lines_code }.
        inject(0) { |sum, loc| sum + loc }
    end

    def compute_effective_loc_over_m(stats)
      # Ugly hack for subtracting out class/end.  >.<
      loc_over_m  = safe_div(stats.lines_code, stats.methods)
      loc_over_m -= 2 if loc_over_m >= 2
      return loc_over_m
    end
  end
end
