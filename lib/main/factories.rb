module Main
  def Main.factory(&block)
    Program.factory(&block)
  end

  def Main.create(&block)
    factory(&block)
  end

  def Main.new(*args, &block)
    main_class = factory(&block).build(*args)
    main_class.new()
  end

  def Main.run(*args, &block)
    main_class = factory(&block).build(*args)
    main = main_class.new()
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
