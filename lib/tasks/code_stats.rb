stats_directories = [
  %w(Libraries lib/),
  %w(Source source/),
  %w(Src src/),
].collect { |name, dir| [ name, "#{Dir.pwd}/#{dir}" ] }.select { |name, dir| File.directory?(dir) }

if ENV['DIRECTORIES_TO_CALCULATE']
  user_defined_dirs = ENV['DIRECTORIES_TO_CALCULATE'].split(',')
  user_defined_dirs.each do |dir|
    if File.directory?(dir)
      stats_directories << [dir.capitalize, "#{Dir.pwd}/#{dir}"]
    end
  end
end

desc "Report code statistics (KLOCs, etc) from the application"
task :stats do
  require File.join(File.dirname(__FILE__), '..', 'code_statistics', 'code_statistics')
  puts CodeStatistics::CodeStatistics.new(*stats_directories).to_s
end

#this is for apps that already had a stats task, but want to use the newer features of this gem
desc "Report code statistics (KLOCs, etc) from the application"
task :code_stats do
  require File.join(File.dirname(__FILE__), '..', 'code_statistics', 'code_statistics')
  puts CodeStatistics::CodeStatistics.new(*stats_directories).to_s
end
