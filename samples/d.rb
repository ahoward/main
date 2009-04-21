require 'main'

ARGV.replace %w( --foo=40 -f2 ) if ARGV.empty?

Main {
  option('foo', 'f'){
    required  # by default options are not required, we could use 'foo=foo'
              # above as a shortcut
    argument_required
    arity 2
    cast :float
  }

  option('bar=[bar]', 'b'){  # note shortcut syntax for optional args
    # argument_optional      # we could also use this method
    cast :bool
    default false
  }

  def run
    p params['foo'].given?
    p params['foo'].values
    p params['bar'].given?
    p params['bar'].value
  end
}
