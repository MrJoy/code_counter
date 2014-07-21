require 'pathname'

module CodeCounter
  module FSHelpers
    # Returns the full path to the directory, or nil if it's not a directory.
    def canonicalize_directory(directory)
      directory = directory.expand_path
      directory = directory.directory? ? directory : nil
      return directory
    end

    # Given a directory, returns all directories that are immediate children
    # of that directory -- excluding special directories `.` and `..`.
    def enumerate_directories(directory)
      return directory.
        children.
        select(&:directory?).
        map(&:expand_path)
    end

    # Given a directory, returns all files that are immediate children
    # of that directory -- excluding directories.
    def enumerate_files(directory)
      return directory.
        children.
        reject(&:directory?).
        map(&:expand_path)
    end


    def is_allowed_file_type(fname, allowed_extensions)
      return false if fname.basename.to_s =~ /\A\.\.?\Z/
      return false unless allowed_extensions.include?(fname.extname)
      return false if fname.directory?

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
  end
end
