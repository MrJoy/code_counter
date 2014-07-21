require 'code_counter/fs_helpers'

describe CodeCounter::FSHelpers do
  subject { CodeCounter::FSHelpers }

  PROJECT_DIR = Pathname.new(File.expand_path(Dir.pwd))

  describe '.canonicalize_directory' do
    it 'returns nil if given a path to a file' do
      result = subject.canonicalize_directory((PROJECT_DIR + 'Gemfile').to_s)

      expect(result).to be nil
    end

    it 'returns a full path when given a relative path to a directory' do
      result = subject.canonicalize_directory('lib')

      expect(result).to eq (PROJECT_DIR + 'lib').to_s
    end
  end

  describe '.enumerate_directories' do
    let(:example_path) { 'spec/fixtures/rspec/spec' }
    let(:example_result) do
      [
        "controllers",
        "models",
      ].map do |dir|
        PROJECT_DIR + example_path + dir
      end
    end
    it 'returns the child directories of the specified dir, excluding `.` and `..`' do
      result = subject.enumerate_directories(example_path)

      expect(result).to eq(example_result)
    end
  end


  describe '.enumerate_files' do
    let(:example_path) { 'spec/fixtures/binaries/bin' }
    let(:example_result) do
      [
        "actual_binary",
        "dummy",
      ].map do |fname|
        PROJECT_DIR + example_path + fname
      end
    end
    it 'returns the children of the specified dir, excluding directories' do
      result = subject.enumerate_files(example_path)

      expect(result).to eq(example_result)
    end
  end

  describe '.is_allowed_file_type' do
    it 'does not allow the magic directory `.`' do
      result = subject.is_allowed_file_type('.', [''])

      expect(result).to be false
    end

    it 'does not allow the magic directory `..`' do
      result = subject.is_allowed_file_type('..', [''])

      expect(result).to be false
    end

    it 'does not allow files with incorrect extensions' do
      result = subject.is_allowed_file_type('foo.py', ['.rb', '.rake'])

      expect(result).to be false
    end

    it 'does allows files with correct extensions' do
      result = subject.is_allowed_file_type('foo.rb', ['.rb', '.rake'])

      expect(result).to be true
    end

    it 'does not allow directories' do
      result = subject.is_allowed_file_type('bin', [''])

      expect(result).to be false
    end
  end
end
