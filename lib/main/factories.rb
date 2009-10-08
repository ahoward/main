module Main
  def Main.create(*args, &block)
    klass = Base.create(Base, *args, &block)
  end

  def Main.new *a, &b
    create(::Main::Base, &b).new(*a)
  end

  def Main.run(*args, &block)
    create(&block).new(*args, &block).run()
  end
end

module ::Kernel
private
  def Main(argv = ARGV, env = ENV, opts = {}, &block)
    ::Main.run(argv, env, opts, &block)
  end
  alias_method 'main', 'Main'
end
