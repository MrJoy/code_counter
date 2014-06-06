code_outside_class :a
flippity floppy boop

def method_outside_class
  intra_method_statement
rescue SomeError => se
rescue SomeOtherError
rescue YAError1, YAError2
rescue YAError3, YAError4 => yae
ensure
  whatever
end

class Foo < Meh
  intra_class_statement

  def foo
    intra_method_statement

    class WibblyWobbly
    end
  end

  protected

  def self.self_bar; end

  def Foo.self_foo; end

  def bar; end

  private def baz; puts "OY"; end

  public

  class Bar
    more_intra_class_statements

    def foo
      intra_method_statement
    end
  end
end

class A::B
end

module Alpha
  module Beta
    class Delta::Gamma
    end
  end
end

module One::Two
end
