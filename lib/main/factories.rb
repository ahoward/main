module Main
  def Main.create(&block)
    factory(&block)
  end

  def Main.factory(&block)
    Program.factory(&block)
  end

  def Main.new(*args, &block)
    program = factory(&block).build(*args)
    program.new()
  end

  def Main.run(*args, &block)
    program = factory(&block).build(*args)
    main = program.new()
    main.run()
  end
end

module Kernel
private
  def Main(*args, &block)
    Main.run(*args, &block)
  end
  alias_method 'main', 'Main'
end
