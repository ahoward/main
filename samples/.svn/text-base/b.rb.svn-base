require 'main'

ARGV.replace %w( 40 1 1 ) if ARGV.empty?

Main {
  argument('foo'){
    arity 3                             # foo will given three times
    cast :int                           # value cast to Fixnum
    validate{|foo| [40,1].include? foo} # raises error in failure case 
    description 'the foo param'         # shown in --help
  }

  def run
    p params['foo'].given?
    p params['foo'].values
  end
}
