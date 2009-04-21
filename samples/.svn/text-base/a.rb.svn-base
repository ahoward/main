require 'main'

ARGV.replace %w( 42 ) if ARGV.empty?

Main {
  argument('foo'){
    required                    # this is the default
    cast :int                   # value cast to Fixnum
    validate{|foo| foo == 42}   # raises error in failure case 
    description 'the foo param' # shown in --help
  }

  def run
    p params['foo'].given?
    p params['foo'].value
  end
}
