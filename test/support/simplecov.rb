if(ENV['USING_COVERAGE'].to_i > 0)
  BASE_DIR = File.expand_path(File.join(__FILE__, '../../..'))
  def expand_path(p, recursive)
    path = File.expand_path(File.join(BASE_DIR, p))
    results = Dir[File.join(path, '*.{rb,rake}')]
    results += Dir[File.join(path, '**/*.{rb,rake}')] if(recursive)
    return results.sort.uniq
  end
  PATHS = {
    bin: expand_path("bin", true),
    lib: expand_path("lib", true),
    test: expand_path("test", true),
  }

  def only_included_in(src_file, allowed_paths)
    in_expected_set = PATHS[allowed_paths].detect { |p| p.include?(src_file) }
    in_other_sets = PATHS.
      reject { |key, paths| key == allowed_paths }.
      map { |(_, paths)| paths }.
      flatten.
      detect { |p| p.include?(src_file) }
    return in_expected_set && !in_other_sets
  end

  require 'simplecov'
  SimpleCov.start do
    add_group "Bin" do |context|
      only_included_in(context.filename, :bin)
    end
    add_group "Lib" do |context|
      only_included_in(context.filename, :lib)
    end
    add_group "Test" do |context|
      only_included_in(context.filename, :test)
    end
  end
end
