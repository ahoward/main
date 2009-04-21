require 'main'

ARGV.replace %w( foo=40 foo=2 bar=false ) if ARGV.empty?

Main {
  keyword('foo'){
    required  # by default keywords are not required
    arity 2
    cast :float
  }
  keyword('bar'){
    cast :bool
  }

  def run
    p params['foo'].given?
    p params['foo'].values
    p params['bar'].given?
    p params['bar'].value
  end
}
