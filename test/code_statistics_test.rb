class CodeCounterEngineTest < Test::Unit::TestCase

  include Construct::Helpers

  def setup_code_stats!(paths, ignores)
    CodeCounter::Engine.clear!
    CodeCounter::Engine.init!
    paths.each do |pair|
      CodeCounter::Engine.add_path(pair.first, pair.last)
    end
    @code_stats = CodeCounter::Engine.new(ignores)
  end

  should "find passed in directory" do
    within_construct do |construct|
      lib = construct.directory("lib")
        lib.file("real.rb", "this\nis\nlame\n")
        lib.directory("controllers").
          file("fake.rb", "this\nis\nlame\n")

      setup_code_stats!([['Libraries', 'lib']], [])
      assert @code_stats.to_s.match(/Libraries/)
      assert @code_stats.to_s.match(/Code LOC: 6/)
    end
  end

  should "not duplicate passed in directories with same paths with slashes" do
    within_construct do |construct|
      lib = construct.directory("lib")
        lib.file("real.rb", "this\nis\nlame\n")
        lib.directory("controllers").
          file("fake.rb", "this\nis\nlame\n")

      setup_code_stats!([['Libraries', 'lib'], ["libs", 'lib/']], [])
      assert @code_stats.to_s.match(/Libraries/)
      assert @code_stats.to_s.match(/Code LOC: 6/)
    end
  end

  should "find app controllers directory" do
    within_construct do |construct|
      construct.directory("app").
        directory("controllers").
          file("fake.rb", "this\nis\nlame\n")

      setup_code_stats!([], [])
      assert @code_stats.to_s.match(/Controllers/)
      assert @code_stats.to_s.match(/Code LOC: 3/)
    end
  end

  should "don't double count app directory when empty sub directories directory" do
    within_construct do |construct|
      app = construct.directory("app")
        app.directory("controllers").
          file("fake.rb", "this\nis\nlame\n")
        app.directory("zfolder")

      setup_code_stats!([], [])
      assert @code_stats.to_s.match(/Controllers/)
      assert @code_stats.to_s.match(/Code LOC: 3/)
    end
  end

  should "add spec sub directories and count as test code" do
    within_construct do |construct|
      spec = construct.directory("spec")
        spec.directory("models").
          file("fake.rb", "this\nis\nlame\n")
        spec.directory("controllers").
          file("fake.rb", "this\nis\nlame\n")

      setup_code_stats!([], [])
      assert @code_stats.to_s.match(/RSpec specs/)
      assert @code_stats.to_s.match(/Test LOC: 6/)
    end
  end

  should "add spec sub sub directories and count as test code" do
    within_construct do |construct|
      construct.directory("spec").
        directory("models").
          directory("controllers").
            file("fake.rb", "this\nis\nlame\n")

      setup_code_stats!([], [])
      assert @code_stats.to_s.match(/RSpec specs/)
      assert @code_stats.to_s.match(/Test LOC: 3/)
    end
  end

  should "add spec sub sub directories but add highest level directory with test files and count as test code" do
    within_construct do |construct|
      spec = construct.directory("spec")
        spec.directory("models").
          file("top_fake.rb", "this\nis\nlame\n")
        spec.directory("controllers").
          file("fake.rb", "this\nis\nlame\n")

      setup_code_stats!([], [])
      assert @code_stats.to_s.match(/RSpec specs/)
      assert @code_stats.to_s.match(/Test LOC: 6/)
    end
  end

  should "add spec root directory and count as test code" do
    within_construct do |construct|
      construct.directory("spec").
        file("fake.rb", "this\nis\nlame\n")

      setup_code_stats!([], [])
      assert @code_stats.to_s.match(/RSpec specs/)
      assert @code_stats.to_s.match(/Test LOC: 3/)
    end
  end

  should "add test sub directories and count as test code" do
    within_construct do |construct|
      test = construct.directory("test")
        test.directory("models").
          file("fake.rb", "this\nis\nlame\n")
        test.directory("controllers").
          file("fake.rb", "this\nis\nlame\n")

      setup_code_stats!([], [])
      assert @code_stats.to_s.match(/Unit tests/)
      assert @code_stats.to_s.match(/Unit tests/)
      assert @code_stats.to_s.match(/Test LOC: 6/)
    end
  end

  should "add test root directory and count as test code" do
    within_construct do |construct|
      construct.directory("test").
        file("fake.rb", "this\nis\nlame\n")

      setup_code_stats!([], [])
      assert @code_stats.to_s.match(/Unit tests/)
      assert @code_stats.to_s.match(/Test LOC: 3/)
    end
  end

  should "count test directory even if passed in as full path" do
    within_construct do |construct|
      test = construct.directory("test")
        test.file("fake.rb", "this\nis\n\lame\n")

      setup_code_stats!([['test', test.to_s]], [])
      assert @code_stats.to_s.match(/Unit tests/)
      assert @code_stats.to_s.match(/Test LOC: 3/)
    end
  end

  should "calculate correct test to code ratio" do
    within_construct do |construct|
      app = construct.directory("app")
        app.directory("models").
          file("fake.rb", "this\n"*9)
        app.directory("controllers").
          file("fake.rb", "this\nis\nlame\n")
      test = construct.directory("test")
        test.directory("models").
          file("fake.rb", "this\nis\nlame\n")
        test.directory("controllers").
          file("fake.rb", "this\nis\nlame\n")

      setup_code_stats!([], [])
      assert @code_stats.to_s.match(/Code LOC: 12/)
      assert @code_stats.to_s.match(/Test LOC: 6/)
      assert @code_stats.to_s.match(/Code to Test Ratio: 1:0.5/)
    end
  end

  should "ignore the expected file globs" do
    within_construct do |construct|
      app = construct.directory("app")
        app.directory("models").
          file("fake.rb", "this\n"*9)
        app.directory("controllers").
          file("fake.rb", "this\nis\nlame\n")
      test = construct.directory("test")
        test.directory("models").
          file("fake.rb", "this\nis\nlame\n")
        test.directory("controllers").
          file("fake.rb", "this\nis\nlame\n")

      setup_code_stats!([], ['app/controllers/**/*'])
      assert @code_stats.to_s.match(/Code LOC: 9/)
      assert @code_stats.to_s.match(/Test LOC: 6/)
      assert @code_stats.to_s.match(/Code to Test Ratio: 1:0.7/)
    end
  end
end
