require 'code_counter/engine'

describe CodeCounter::Engine do
  include FileUtils

  def run_cli!(fixture, mappings)
    cd File.join('spec', 'fixtures', fixture.to_s) do
      ENV['IGNORE_FILE_GLOBS'] = ''
      ENV['ADDITIONAL_SOURCE_DIRECTORIES'] = (
        (mappings[:source] || []).
          select { |items| items.length == 2}.
          map { |(label,dir)| "#{label}:#{dir}" } +
        (mappings[:source] || []).
          select { |items| items.length == 1}.
          map(&:first)
      ).join(',')

      ENV['ADDITIONAL_SCRIPT_DIRECTORIES'] = (
        (mappings[:scripts] || []).
          select { |items| items.length == 2}.
          map { |(label,dir)| "#{label}:#{dir}" } +
        (mappings[:scripts] || []).
          select { |items| items.length == 1}.
          map(&:first)
      ).join(',')

      CodeCounter::Engine.clear!
      CodeCounter::Engine.init!
      return capture_stdout { load "#{PROJECT_DIR}/bin/code_counter" }
    end
  end

  def run_lib!(fixture, mappings, ignores=[])
    cd File.join('spec', 'fixtures', fixture.to_s) do
      CodeCounter::Engine.clear!
      CodeCounter::Engine.init!
      (mappings[:source] || []).each do |(shorthand, full)|
        CodeCounter::Engine.add_path(shorthand, full)
      end
      (mappings[:scripts] || []).each do |(shorthand, full)|
        CodeCounter::Engine.add_path(shorthand, full, true, true)
      end

      return CodeCounter::Engine.new(ignores).to_s
    end
  end

  let(:fixture_data) do
    {
      :simple => {
        :mappings   => { :source => [['Libraries', 'lib']] },
        :dir_label  => /Libraries/,
        :code_loc   => /Code LOC: 6/,
      },
      :simple_default_labels => {
        :path       => 'simple',
        :mappings   => { :source => [['lib']] },
        :dir_label  => /Libraries/,
        :code_loc   => /Code LOC: 6/,
      },
      :controller => {
        :mappings   => { :source => [] },
        :dir_label  => /Controllers/,
        :code_loc   => /Code LOC: 3/,
      },
      :empty_subdir => {
        :mappings   => { :source => [] },
        :dir_label  => /Controllers/,
        :code_loc   => /Code LOC: 3/,
      },
      :rspec => {
        :mappings   => { :source => [] },
        :test_label => /RSpec specs/,
        :test_loc   => /Test LOC: 6/,
      },
      :rspec_subdir => {
        :mappings   => { :source => [] },
        :test_label => /RSpec specs/,
        :test_loc   => /Test LOC: 3/,
      },
      :rspec_complex => {
        :mappings   => { :source => [] },
        :test_label => /RSpec specs/,
        :test_loc   => /Test LOC: 6/,
      },
      :rspec_shallow => {
        :mappings   => { :source => [] },
        :test_label => /RSpec specs/,
        :test_loc   => /Test LOC: 3/,
      },
      :testunit_complex => {
        :mappings   => { :source => [] },
        :test_label => /Unit tests/,
        :test_loc   => /Test LOC: 6/,
      },
      :testunit_shallow => {
        :mappings   => { :source => [] },
        :test_label => /Unit tests/,
        :test_loc   => /Test LOC: 3/,
      },
      :testunit_shallow => {
        :mappings   => { :source => [['test', File.expand_path('testunit_shallow/test')]] },
        :test_label => /Unit tests/,
        :test_loc   => /Test LOC: 3/,
      },
      :code_to_test_ratio => {
        :mappings   => { :source => [] },
        :code_loc   => /Code LOC: 12/,
        :test_loc   => /Test LOC: 6/,
        :ratio      => /Code to Test Ratio: 1:0.5/,
      },
      :code_to_test_ratio_with_ignores => {
        :path       => 'code_to_test_ratio',
        :mappings   => { :source => [] },
        :ignores    => ['app/controllers/**/*'],
        :code_loc   => /Code LOC: 9/,
        :test_loc   => /Test LOC: 6/,
        :ratio      => /Code to Test Ratio: 1:0.7/,
      },
      :scripts => {
        :mappings   => { :source => [], :scripts => [['Fancy Stuff', 'special']] },
        :dir_label  => { :simple => /Scripts/, :fancy => /Fancy/ },
        :code_loc   => { :simple => /Code LOC: 9/, :fancy => /Code LOC: 20/ },
      },
    }
  end
  let(:mappings)    { fixture_data[fixture][:mappings] }
  let(:ignores)     { fixture_data[fixture][:ignores] }
  let(:dir_label)   { fixture_data[fixture][:dir_label] }
  let(:test_label)  { fixture_data[fixture][:test_label] }
  let(:code_loc)    { fixture_data[fixture][:code_loc] }
  let(:test_loc)    { fixture_data[fixture][:test_loc] }
  let(:ratio)       { fixture_data[fixture][:ratio] }
  let(:path)        { fixture_data[fixture][:path] || fixture.to_s }

  context 'Simple Fixture with Named Directory Mapping' do
    let(:fixture) { :simple }

    describe 'Library' do
      it 'finds passed-in directories' do
        output = run_lib!(path, mappings)

        expect(output).to match(dir_label)
        expect(output).to match(code_loc)
      end
    end

    context 'CLI' do
      it 'finds directories specified with ADDITIONAL_SOURCE_DIRECTORIES env var, and labels them as specified' do
        output = run_cli!(path, mappings)

        expect(output).to match(dir_label)
        expect(output).to match(code_loc)
      end
    end
  end

  context 'Simple Fixture with Default Directory Mapping' do
    context 'CLI' do
      let(:fixture) { :simple_default_labels }

      it 'finds directories specified with ADDITIONAL_SOURCE_DIRECTORIES env var, and labels them using default mappings if no label is given' do
        output = run_cli!(path, mappings)

        expect(output).to match(dir_label)
        expect(output).to match(code_loc)
      end
    end
  end

  context 'Library' do
    let(:fixture) { :simple }

    it "doesn't duplicate passed-in directories with same paths with slashes" do
      output = run_lib!(path, mappings)

      expect(output).to match(dir_label)
      expect(output).to match(code_loc)
    end
  end

  context 'Library' do
    let(:fixture) { :controller }

    it 'finds app controllers directory' do
      output = run_lib!(path, mappings)

      expect(output).to match(dir_label)
      expect(output).to match(code_loc)
    end
  end

  context 'Library' do
    let(:fixture) { :empty_subdir }

    it "doesn't double-count app directory when we have empty sub-directories" do
      output = run_lib!(path, mappings)

      expect(output).to match(dir_label)
      expect(output).to match(code_loc)
    end
  end

  context 'Library' do
    let(:fixture) { :rspec }

    it 'adds spec sub-directories and count as test code' do
      output = run_lib!(path, mappings)

      expect(output).to match(test_label)
      expect(output).to match(test_loc)
    end
  end

  context 'Library' do
    let(:fixture) { :rspec_subdir }

    it 'adds spec sub-sub-directories and count as test code' do
      output = run_lib!(path, mappings)

      expect(output).to match(test_label)
      expect(output).to match(test_loc)
    end
  end

  context 'Library' do
    let(:fixture) { :rspec_complex }

    it 'adds spec sub-sub-directories but add highest level directory with test files and count as test code' do
      output = run_lib!(path, mappings)

      expect(output).to match(test_label)
      expect(output).to match(test_loc)
    end
  end

  context 'Library' do
    let(:fixture) { :rspec_shallow }
    it 'adds spec root directory and count as test code' do
      output = run_lib!(path, mappings)

      expect(output).to match(test_label)
      expect(output).to match(test_loc)
    end
  end

  context 'Library' do
    let(:fixture) { :testunit_complex }

    it 'adds test sub-directories and count as test code' do
      output = run_lib!(path, mappings)

      expect(output).to match(test_label)
      expect(output).to match(test_loc)
    end
  end

  context 'Library' do
    let(:fixture) { :testunit_shallow }

    it 'adds test root directory and count as test code' do
      output = run_lib!(path, mappings)

      expect(output).to match(test_label)
      expect(output).to match(test_loc)
    end
  end

  context 'Library' do
    let(:fixture) { :testunit_shallow }

    it 'counts test directory even if passed in as full path' do
      output = run_lib!(path, mappings)

      expect(output).to match(test_label)
      expect(output).to match(test_loc)
    end
  end

  context 'Library' do
    let(:fixture) { :code_to_test_ratio }

    it 'calculates correct test to code ratio' do
      output = run_lib!(path, mappings)

      expect(output).to match(code_loc)
      expect(output).to match(test_loc)
      expect(output).to match(ratio)
    end
  end

  context 'Library' do
    let(:fixture) { :code_to_test_ratio_with_ignores }

    it 'ignores the specified file globs' do
      output = run_lib!(path, mappings, ignores)

      expect(output).to match(code_loc)
      expect(output).to match(test_loc)
      expect(output).to match(ratio)
    end
  end

  context 'Scripts' do
    let(:fixture) { :scripts }

    context 'Library' do
      it 'finds files without extensions in script directories' do
        output = run_lib!(path, mappings.merge(:scripts => []))

        expect(output).to match(dir_label[:simple])
        expect(output).to match(code_loc[:simple])
      end
    end

    context 'CLI' do
      it 'finds files without extensions in script directories' do
        output = run_cli!(path, mappings.merge(:scripts => []))

        expect(output).to match(dir_label[:simple])
        expect(output).to match(code_loc[:simple])
      end

      it 'allows mapping of script dirs using the ADDITIONAL_SCRIPT_DIRECTORY env var' do
        output = run_cli!(path, mappings)

        expect(output).to match(dir_label[:fancy])
        expect(output).to match(code_loc[:fancy])
      end

    end
  end
end
