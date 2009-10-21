
module Main
  class << Main
    def test(options = {}, &block)
#    at_exit{ exit! }
      opts = {}
      options.each do |key, val|
        opts[key.to_s.to_sym] = val
      end
      options.replace(opts)

      argv = options[:argv]
      env = options[:env]
      logger = options[:logger]
      stdin = options[:stdin]
      stdout = options[:stdout]
      stderr = options[:stderr]

      Main.push_ios!

      factory = Main.factory(&block)

      program = factory.build(argv, env)

      main = program.new

      program.evaluate do
        define_method :handle_exception do |exception|
          if exception.respond_to?(:status)
            main.status = exception.status
          else
            raise(exception)
          end
        end

        define_method :handle_exit do |status|
          main.status = status
        end
      end

      keys = [:logger, :stdin, :stdout, :stderr]
      keys.each do |key|
        if options.has_key?(key)
          val = options[key]
          main.send("#{ key }=", val) if options.has_key?(key)
        end
      end

      run = main.method(:run)

      singleton_class =
        class << main
          self
        end

      singleton_class.module_eval do
        define_method(:run) do
          begin
            run.call()
          ensure
            Main.pop_ios!
          end
        end
      end

      main
    end

    def push_ios!
      @ios ||= []
      @ios.push({
        :STDIN => STDIN.dup, :STDOUT => STDOUT.dup, :STDERR => STDERR.dup
      })
    end

    def pop_ios!
      @ios ||= []
      (@ios.pop||{}).each do |const, dup|
        dst = eval(const.to_s)
        begin
          dst.reopen(dup)
        rescue
          ::Object.send(:remove_const, const)
          ::Object.send(:const_set, const, dup)
        end
      end
    end
  end
end
