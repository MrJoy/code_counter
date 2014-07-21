require 'code_counter/fs_helpers'

describe CodeCounter::FSHelpers do
  class FSHelperTestClass
    include CodeCounter::FSHelpers
  end

  subject { FSHelperTestClass.new }

  describe '#canonicalize_directory' do
    it 'returns nil if given a path to a file' do
      result = subject.canonicalize_directory(PROJECT_DIR + 'Gemfile')

      expect(result).to be nil
    end

    it 'returns a full path when given a relative path to a directory' do
      result = subject.canonicalize_directory(Pathname.new('lib'))

      expect(result).to eq (PROJECT_DIR + 'lib')
    end
  end

  describe '#enumerate_directories' do
    let(:example_path) { Pathname.new('spec/fixtures/rspec/spec') }
    let(:example_result) do
      [
        'controllers',
        'models',
      ].map do |dir|
        PROJECT_DIR + example_path + dir
      end
    end
    it 'returns the child directories of the specified dir, excluding `.` and `..`' do
      result = subject.enumerate_directories(example_path)

      expect(result).to eq(example_result)
    end
  end


  describe '#enumerate_files' do
    let(:example_path) { Pathname.new('spec/fixtures/scripts/bin') }
    let(:example_result) do
      [
        'actual_binary',
        'dummy',
      ].map do |fname|
        PROJECT_DIR + example_path + fname
      end
    end
    it 'returns the children of the specified dir, excluding directories' do
      result = subject.enumerate_files(example_path)

      expect(result).to eq(example_result)
    end
  end

  describe '#is_allowed_file_type' do
    it 'does not allow the magic directory `.`' do
      result = subject.is_allowed_file_type(Pathname.new('.'), [''])

      expect(result).to be false
    end

    it 'does not allow the magic directory `..`' do
      result = subject.is_allowed_file_type(Pathname.new('..'), [''])

      expect(result).to be false
    end

    it 'does not allow files with incorrect extensions' do
      result = subject.is_allowed_file_type(Pathname.new('foo.py'), ['.rb', '.rake'])

      expect(result).to be false
    end

    it 'does allows files with correct extensions' do
      result = subject.is_allowed_file_type(Pathname.new('foo.rb'), ['.rb', '.rake'])

      expect(result).to be true
    end

    it 'does not allow directories' do
      result = subject.is_allowed_file_type(Pathname.new('bin'), [''])

      expect(result).to be false
    end
  end
end
