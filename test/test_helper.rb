require 'rubygems'
require 'bundler'
Bundler.setup(:default, :test)
require 'test/unit'
require 'shoulda'
require 'construct'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require_relative './support/simplecov'

require 'code_counter/engine'

class Test::Unit::TestCase
end
