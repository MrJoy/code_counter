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
      directory = Pathname.new(directory) unless(directory.kind_of?(Pathname))

      return directory.children.
        select(&:directory?).
        map(&:expand_path).
        map(&:to_s)
    end

    def self.is_allowed_file_type(fname, allowed_extensions)
      fname = Pathname.new(fname) unless(fname.kind_of?(Pathname))

      return false if fname.basename.to_s =~ /\A\.\.?\Z/
      return false unless (allowed_extensions.include?(fname.extname))
      return false if fname.directory?

      return true
    end

    # Make a stab at determining if the file specified is a shell program by
    # seeing if it has a shebang line.
    def self.is_shell_program?(path)
      magic_word = File.open(path, "r", { :encoding => "ASCII-8BIT" }) do |fh|
        fh.read(2)
      end
      return magic_word == '#!'
    end
  end
end
