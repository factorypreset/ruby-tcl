require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

class SafeInterpTest < Test::Unit::TestCase
  def setup
    @interp = Tcl::SafeInterp.new
  end
  
  def test_eval_some_command_should_raise_an_error
    assert_raises(Tcl::Error) { @interp.eval('exit') }
    this_file = File.expand_path(__FILE__)
    assert_raises(Tcl::Error) { @interp.eval("open #{this_file}") }
  end
end
