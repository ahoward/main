module Main
  def Main.factory(&block)
    Program.factory(&block)
  end

  def Main.create(&block)
    factory(&block)
  end

  def Main.new(*args, &block)
    factory(&block).build(*args).new()
  end

  def Main.run(*args, &block)
    new(*args, &block).run()
  end
end

module Kernel
private
  def Main(*args, &block)
    Main.run(*args, &block)
  end

  alias_method 'main', 'Main'
end
