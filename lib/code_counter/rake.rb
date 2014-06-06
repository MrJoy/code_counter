# This is for apps that already had a stats task, but want to use the newer
# features of this gem.
task :code_counter do
  if ENV['IGNORE_FILE_GLOBS']
    user_ignored_dirs = ENV['IGNORE_FILE_GLOBS'].split(',')
  else
    user_ignored_dirs = []
  end
  puts CodeCounter::Engine.new(user_ignored_dirs).to_s
end

unless(Rake::Task.task_defined?(:stats))
  desc "Report code statistics (KLOCs, etc) from the application."
  task :stats => :code_counter
end
