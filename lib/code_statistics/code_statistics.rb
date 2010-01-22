module CodeStatistics
  class CodeStatistics #:nodoc:

    attr_reader :print_buffer

    def initialize(pairs, ignore_file_globs = [])
      @pairs        = pairs
      @test_types   = []
      @print_buffer = "" 
      directory     = Dir.pwd
      @ignore_files = collect_files_to_ignore(ignore_file_globs)

      directories_to_search = ['app','test','spec','merb','features', 'bin']
      recursively_add_directories(directories_to_search)

      @pairs.each do |key, dir_path|
        add_test_type(key) if dir_path.match(/^test/) || dir_path.match(/^spec/) || dir_path.match(/^features/)
      end

      @statistics  = calculate_statistics
      @total       = calculate_total if pairs.length > 1
    end

    def recursively_add_directories(dirs)
      dirs.each do |dir|
        if File.directory?(dir)
          entries = Dir.entries(dir)
          entries = entries.reject{ |entry| entry=='.' || entry=='..' }
          has_directories = false
          entries.each do |entry|
            entry_path = File.join(dir,entry)
            if File.directory?(entry_path) 
              @pairs << [entry_path, entry_path]
              has_directories = true
            end
          end
          @pairs << [dir, dir] unless has_directories
        end
      end
    end

    def collect_files_to_ignore(ignore_file_globs)
      files_to_remove = []
      ignore_file_globs.each do |glob|
        files_to_remove.concat(Dir[glob])
      end
      files_to_remove.map{ |filepath| File.expand_path(filepath)}
    end
    
    def to_s
      @print_buffer = ''
      print_header
      @pairs.each { |pair| print_line(pair.first, @statistics[pair.first]) }
      print_splitter
      
      if @total
        print_line("Total", @total)
        print_splitter
      end
      
      print_code_test_stats
      @print_buffer
    end
    
    private
    def calculate_statistics
      @pairs.inject({}) { |stats, pair| stats[pair.first] = calculate_directory_statistics(pair.last); stats }
    end

    def local_file_exists?(dir,filename)
      File.exist?(File.join(dir,filename))
    end

    def test_types
      @test_types.uniq
    end

    def add_test_type(test_type)
      @test_types << test_type
    end
    
    def ignore_file?(file_path)
      @ignore_files.include?(File.expand_path(file_path))
    end

    def calculate_directory_statistics(directory, pattern = /.*\.rb$/)
      stats = { "lines" => 0, "codelines" => 0, "classes" => 0, "methods" => 0 }

      Dir.foreach(directory) do |file_name|
        if File.stat(directory + "/" + file_name).directory? and (/^\./ !~ file_name)
          newstats = calculate_directory_statistics(File.join(directory,file_name), pattern)
          stats.each { |k, v| stats[k] += newstats[k] }
        end
        
        next unless file_name =~ pattern
        file_path = File.join(directory, file_name)
        next if ignore_file?(file_path)
        
        f = File.open(file_path)
        
        while line = f.gets
          stats["lines"] += 1
          stats["classes"] += 1 if line =~ /class [A-Z]/
          stats["methods"] += 1 if line =~ /def [a-z]/
          stats["codelines"] += 1 unless line =~ /^\s*$/ || line =~ /^\s*#/
        end
      end
      
      stats
    end
    
    def calculate_total
      total = { "lines" => 0, "codelines" => 0, "classes" => 0, "methods" => 0 }
      @statistics.each_value { |pair| pair.each { |k, v| total[k] += v } }
      total
    end
    
    def calculate_code
      code_loc = 0
      @statistics.each { |k, v| code_loc += v['codelines'] unless test_types.include? k }
      code_loc
    end
    
    def calculate_tests
      test_loc = 0
      @statistics.each { |k, v| test_loc += v['codelines'] if test_types.include? k }
      test_loc
    end
    
    def print_header
      print_splitter
      @print_buffer << "| Name".ljust(22)+" "+
        "| Lines".ljust(8)+
        "| LOC".ljust(8)+
        "| Classes".ljust(10)+
        "| Methods".ljust(10)+
        "| M/C".ljust(6)+
        "| LOC/M".ljust(6)+
        " |\n"
      print_splitter
    end
    
    def print_splitter
      @print_buffer << "+----------------------+-------+-------+---------+---------+-----+-------+\n"
    end
    
    def print_line(name, statistics)
      m_over_c = (statistics["methods"] / statistics["classes"]) rescue m_over_c = 0
      loc_over_m = (statistics["codelines"] / statistics["methods"]) - 2 rescue loc_over_m = 0
      
      start = if test_types.include? name
                "| #{name.ljust(20)} "
              else
                "| #{name.ljust(20)} "
              end
      
      if (statistics['lines']!=0)
        @print_buffer << start +
          "| #{statistics["lines"].to_s.rjust(5)} " +
          "| #{statistics["codelines"].to_s.rjust(5)} " +
          "| #{statistics["classes"].to_s.rjust(7)} " +
          "| #{statistics["methods"].to_s.rjust(7)} " +
          "| #{m_over_c.to_s.rjust(3)} " +
          "| #{loc_over_m.to_s.rjust(5)} |\n"
      end
    end
    
    def print_code_test_stats
      code = calculate_code
      tests = calculate_tests
      
      ratio = if code!=0
        "#{sprintf("%.1f", tests.to_f/code)}"
      else
        "0.0"
      end
      @print_buffer << " Code LOC: #{code}  Test LOC: #{tests}  Code to Test Ratio: 1:#{ratio}\n"
      @print_buffer << "\n"
    end
  end
end
