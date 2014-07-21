require 'ostruct'
require 'pathname'

module CodeCounter
  class Reporter
    attr_reader :print_buffer

    def report(total, pairs, statistics, cloc, tloc, test_ratio)
      @print_buffer = ''

      calculate_column_widths(pairs, statistics)

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
    COLUMNS = [
      { minimum_width: 20, alignment: -1, header: 'Name',     field: 'group' },
      { minimum_width:  5, alignment:  1, header: 'Lines',    field: 'lines' },
      { minimum_width:  5, alignment:  1, header: 'LOC',      field: 'codelines' },
      { minimum_width:  7, alignment:  1, header: 'Classes',  field: 'classes' },
      { minimum_width:  7, alignment:  1, header: 'Methods',  field: 'methods' },
      { minimum_width:  3, alignment:  1, header: 'M/C',      field: 'm_over_c' },
      { minimum_width:  5, alignment:  1, header: 'LOC/M',    field: 'loc_over_m' },
    ].map { |cfg| OpenStruct.new(cfg) }

    def calculate_column_widths(pairs, statistics)
      COLUMNS.each do |cfg|
        cfg[:width] = max_width_for_field(statistics, cfg)
      end
    end

    def max_width_for_field(statistics, cfg)
      return (statistics.map { |_,stats| stats[cfg.field].to_s.length } + [cfg.minimum_width]).max
    end

    def row_pattern
      @row_pattern ||= '|' + COLUMNS.map { |cfg| " %#{cfg[:width]*cfg[:alignment]}s " }.join('|') + "|\n"
    end

    def header_pattern
      @header_pattern ||= '|' + COLUMNS.map { |cfg| " %-#{cfg[:width]}s " }.join('|') + "|\n"
    end

    def splitter
      @splitter ||= (header_pattern % COLUMNS.map { |cfg| '-' * cfg[:width] }).gsub(/ /, '-')
    end

    def print_header
      print_splitter
      @print_buffer << header_pattern % COLUMNS.map { |cfg| cfg[:header] }
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
