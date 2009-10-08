module Main
  def Main.factory(&block)
    Base.factory(&block)
  end

  def Main.create(&block)
    Base.factory(&block)
  end

  def Main.new(*args, &block)
    create(&block).new(*args)
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
