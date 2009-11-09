#todo for both spec and test look through top level add any directory seperately
#get rid of the hard coded test/units / etc in this file and the lib file.
stats_directories = [
  %w(Controllers app/controllers),
  %w(Helpers app/helpers),
  %w(Models app/models),
  %w(Libraries lib/),
  %w(APIs app/apis),
  %w(Integration\ tests test/integration),
  %w(Functional\ tests test/functional),
  %w(Unit\ tests test/unit),
  %w(Model\ specs spec/models), 
  %w(View\ specs spec/views),
  %w(Controller\ specs spec/controllers),
  %w(Helper\ specs spec/helpers),
  %w(Library\ specs spec/lib),
  %w(Routing\ specs spec/routing),
  %w(Integration\ specs spec/integration),
  %w(Public\ specs spec/public),
  %w(Semipublic\ specs spec/semipublic)
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
  CodeStatistics::CodeStatistics.new(*stats_directories).to_s
end
