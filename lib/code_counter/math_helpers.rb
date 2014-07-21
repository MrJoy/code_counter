module CodeCounter
  module MathHelpers
    def safe_div(x, y)
      return (y != 0) ? (x / y) : 0
    end
  end
end
