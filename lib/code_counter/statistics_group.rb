module CodeCounter
  class StatisticsGroup
    attr_reader :name, :lines_raw, :lines_code, :classes, :methods,
                :loc_per_method, :is_aggregate

    def initialize(name, is_aggregate = false)
      @name = name
      @is_aggregate = is_aggregate
      @lines_raw = 0
      @lines_code = 0
      @classes = 0
      @methods = 0
    end

    def methods_per_class
      return nil if @is_aggregate

      return (@classes > 0) ? (@methods / @classes) : 0
    end

    def set_loc_per_method(loc_per_method)
      @loc_per_method = loc_per_method
    end

    def add_lines(raw, code)
      @lines_raw += raw
      @lines_code += code
    end

    def add_classes(classes)
      @classes += classes
    end

    def add_methods(methods)
      @methods += methods
    end

    def add_group(group)
      raise "Can only call `#add_group` on aggregates!" unless @is_aggregate

      add_lines(group.lines_raw, group.lines_code)
      add_classes(group.classes)
      add_methods(group.methods)
    end
  end
end
