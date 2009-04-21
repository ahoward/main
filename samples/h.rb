require 'main'

# block-defaults are instance_eval'd in the main instance and be combined with
# mixins
#
# ./h.rb   #=> forty-two
# ./h.rb a #=> 42 
# ./h.rb b #=> 42.0 
#

Main {
  fattr :default_for_foobar => 'forty-two' 

  option(:foobar) do
    default{ default_for_foobar }
  end

  mixin :foo do
    fattr :default_for_foobar => 42
  end

  mixin :bar do
    fattr :default_for_foobar => 42.0
  end


  run{ p params[:foobar].value }

  mode :a do
    mixin :foo
  end

  mode :b do
    mixin :bar
  end
}
