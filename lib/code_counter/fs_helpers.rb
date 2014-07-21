require 'pathname'

module CodeCounter
  class FSHelpers
    # Returns the full path to the directory, or nil if it's not a directory.
    def self.canonicalize_directory(directory)
      directory = File.expand_path(directory)
      directory = File.directory?(directory) ? directory : nil
      return directory
    end

    # Given a directory, returns all directories that are immediate children
    # of that directory -- excluding special directories `.` and `..`.
    def self.enumerate_directory(directory)
      return Dir.entries(directory).
        reject { |dirent| dirent =~ /^\.\.?$/ }.
        map { |dirent| File.join(directory, dirent) }.
        select { |dirent| File.directory?(dirent) }

    def self.is_allowed_file_type(fname, allowed_extensions)
      fname = Pathname.new(fname) unless(fname.kind_of?(Pathname))

      return false if fname.basename.to_s =~ /\A\.\.?\Z/
      return false unless (allowed_extensions.include?(fname.extname))

      return true
    end
  end
end
