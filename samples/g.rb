require 'main'

ARGV.replace %w( 42 ) if ARGV.empty?

Main {
  argument( 'foo' )
  option( 'bar' )

  run { puts "This is what to_options produces: #{params.to_options.inspect}" }
}
