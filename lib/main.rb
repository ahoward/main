module Main
#
# top level constants
#
  Main::VERSION = '4.2.0' unless
    defined? Main::VERSION
  def self.version() Main::VERSION end

  Main::LIBDIR = File.join(File.dirname(File.expand_path(__FILE__)), self.name.downcase, '') unless
    defined? Main::LIBDIR
  def self.libdir() Main::LIBDIR end

  Main::EXIT_SUCCESS = 0 unless defined? Main::EXIT_SUCCESS
  Main::EXIT_FAILURE = 1 unless defined? Main::EXIT_FAILURE
  Main::EXIT_WARN = 42 unless defined? Main::EXIT_WARN
#
# built-in
#
  require 'logger'
  require 'enumerator'
  require 'set'
#
# use gems to pick up dependancies
#
  begin
    require 'rubygems'
  rescue LoadError
    42
  end

  require 'fattr'
  require 'arrayfields'
#
# main's own libs
#
  require libdir + 'stdext'
  require libdir + 'softspoken'
  require libdir + 'util'
  require libdir + 'logger'
  require libdir + 'usage'
  require libdir + 'cast'
  require libdir + 'parameter'
  require libdir + 'getoptlong'
  require libdir + 'mode'
  require libdir + 'program'
  require libdir + 'factories'
end
