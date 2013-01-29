stats_directories = [
  %w(Libraries lib/),
  %w(Source source/),
  %w(Src src/),
  %w(Features features/),
].collect { |name, dir| [ name, "#{Dir.pwd}/#{dir}" ] }.select { |name, dir| File.directory?(dir) }

if ENV['DIRECTORIES_TO_CALCULATE']
  user_defined_dirs = ENV['DIRECTORIES_TO_CALCULATE'].split(',')
  user_defined_dirs.each do |dir|
    if File.directory?(dir)
      stats_directories << [dir.capitalize, "#{Dir.pwd}/#{dir}"]
    end
  end
end

if ENV['IGNORE_FILE_GLOBS']
  user_ignored_dirs = ENV['IGNORE_FILE_GLOBS'].split(',')
else
  user_ignored_dirs = []
end

def report_stats(stats_directories, user_ignored_dirs)
  require File.join(File.dirname(__FILE__), '..', 'code_statistics', 'code_statistics')
  puts CodeStatistics::CodeStatistics.new(stats_directories, user_ignored_dirs).to_s
end

# This is for apps that already had a stats task, but want to use the newer
# features of this gem.
task :code_statistics do
  report_stats(stats_directories, user_ignored_dirs)
end

if(Rake::Task[:stats].nil?)
  desc "Report code statistics (KLOCs, etc) from the application"
  task :stats => :code_statistics
end
