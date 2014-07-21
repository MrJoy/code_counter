require 'pathname'

module CodeCounter
  class Reporter
    attr_reader :print_buffer

    def report(total, pairs, statistics, cloc, tloc, test_ratio)
      @print_buffer = ''
      print_header
      pairs.each do |pair|
        print_line(pair.first, statistics[pair.first])
      end
      print_splitter

      if total
        print_line("Total", total)
        print_splitter
      end

      print_code_test_stats(cloc, tloc, test_ratio)

      return @print_buffer
    end


    protected


    # TODO: Make this respond to changes caused by `.add_path` and
    # TODO: `.add_test_group`.
    COL_WIDTHS      = [[22,-1], [7,1], [7,1], [9,1], [9,1], [5,1], [7,1]]
    HEADERS         = ['Name', 'Lines', 'LOC', 'Classes', 'Methods', 'M/C', 'LOC/M']

    def row_pattern
      @row_pattern ||= '|' + COL_WIDTHS.map { |(w,d)| " %#{w*d}s " }.join('|') + "|\n"
    end

    def header_pattern
      @header_pattern ||= '|' + COL_WIDTHS.map { |(w,_)| " %-#{w}s " }.join('|') + "|\n"
    end

    def splitter
      @splitter ||= (header_pattern % COL_WIDTHS.map { |(w,_)| '-' * w }).gsub(/ /, '-')
    end

    def print_header
      print_splitter
      @print_buffer << header_pattern % HEADERS
      print_splitter
    end

    def print_splitter
      @print_buffer << splitter
    end

    def print_line(name, stats)
      return if stats['lines'] == 0

      @print_buffer << row_pattern % arrange_line_data(name, stats)
    end

    def print_code_test_stats(cloc, tloc, test_ratio)
      @print_buffer << " Code LOC: #{cloc}  Test LOC: #{tloc}  Code to Test Ratio: #{test_ratio}\n\n"
    end

    def arrange_line_data(name, stats)
      return [
        name,
        stats['lines'],
        stats['codelines'],
        stats['classes'],
        stats['methods'],
        stats['m_over_c'],
        stats['loc_over_m'],
      ]
    end
  end
end
