code_outside_class

def method_outside_class
  intra_method_statement
end

class Foo
  intra_class_statement

  def foo
    intra_method_statement
  end

  class Bar
    more_intra_class_statements

    def foo
      intra_method_statement
    end
  end
end
