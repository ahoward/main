#!/usr/bin/env ruby
require 'main'

Main {
  mode( :foo ) {
    argument( :bar ) {
      required
      default 42
    }
    run {
      puts "Doing something with #{params['bar'].value}"
    }
  }
}
