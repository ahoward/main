module Main
# top level constants
#
  Main::VERSION = '6.2.2' unless
    defined? Main::VERSION
  def Main.version() Main::VERSION end

  def Main.description
    'a class factory and dsl for generating command line programs real quick'
  end

  Main::LIBDIR = File.join(File.dirname(File.expand_path(__FILE__)), self.name.downcase, '') unless
    defined? Main::LIBDIR
  def self.libdir() Main::LIBDIR end

  Main::EXIT_SUCCESS = 0 unless defined? Main::EXIT_SUCCESS
  Main::EXIT_FAILURE = 1 unless defined? Main::EXIT_FAILURE
  Main::EXIT_WARN = 42 unless defined? Main::EXIT_WARN
  Main::EXIT_WARNING = 42 unless defined? Main::EXIT_WARNING

## deps
#
  def Main.dependencies
    {
      'chronic'     => [ 'chronic', '~> 0.6', '>= 0.6.2' ] ,
      'fattr'       => [ 'fattr', '~> 2.2', '>= 2.2.0' ] ,
      'arrayfields' => [ 'arrayfields', '~> 4.7', '>= 4.7.4' ] ,
      'map'         => [ 'map', '~> 6.1', '>= 6.1.0' ] ,
    }
  end

  def Main.libdir(*args, &block)
    @libdir ||= File.expand_path(__FILE__).sub(/\.rb$/,'')
    args.empty? ? @libdir : File.join(@libdir, *args)
  ensure
    if block
      begin
        $LOAD_PATH.unshift(@libdir)
        block.call()
      ensure
        $LOAD_PATH.shift()
      end
    end
  end

  def Main.load(*libs)
    libs = libs.join(' ').scan(/[^\s+]+/)
    Main.libdir{ libs.each{|lib| Kernel.load(lib) } }
  end
end




# built-in
#
  require 'logger'
  require 'enumerator'
  require 'set'
  require 'uri'
  require 'time'
  require 'date'

# use gems to pick up dependancies
#
  begin
    require 'rubygems'
  rescue LoadError
    42
  end

  if defined?(gem)
    Main.dependencies.each do |lib, dependency|
      gem(*dependency)
      require(lib)
    end
  end

# main's own libs
#
  Main.load %w[
    stdext.rb
    softspoken.rb
    util.rb
    logger.rb
    usage.rb
    cast.rb
    parameter.rb
    getoptlong.rb
    mode.rb
    program.rb
    factories.rb
    daemon.rb
  ]
