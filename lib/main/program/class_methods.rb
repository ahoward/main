module Main
  class Program
    module ClassMethods
      fattr('name'){ File.basename($0) }
      fattr('program'){ File.basename($0) }
      fattr('synopsis'){ Main::Usage.default_synopsis(self) }
      fattr('description')
      fattr('usage'){ Main::Usage.default_usage(self) }
      fattr('modes'){ Main::Mode.list }
      fattr('depth_first_modes'){ Main::Mode.list }
      fattr('breadth_first_modes'){ Main::Mode.list }

      fattr('author')
      fattr('version')
      fattr('stdin'){ $stdin }
      fattr('stdout'){ $stdout }
      fattr('stderr'){ $stderr }
      fattr('logger'){ Logger.new(stderr) }
      fattr('logger_level'){ Logger::INFO }
      fattr('exit_status'){ nil }
      fattr('exit_success'){ Main::EXIT_SUCCESS }
      fattr('exit_failure'){ Main::EXIT_FAILURE }
      fattr('exit_warn'){ Main::EXIT_WARN }
      fattr('parameters'){ Main::Parameter::List[] }
      fattr('can_has_hash'){ Hash.new }
      fattr('mixin_table'){ Hash.new }

      fattr('factory')
      fattr('argv')
      fattr('env')
      fattr('opts')

      def factory(&block)
        Factory.new(&block)
      end
      alias_method 'create', 'factory'

      class Factory
        def initialize(&block)
          @block = block || lambda{}
        end

        def to_proc
          @block
        end

        def build(*args, &block)
          argv = (args.shift || ARGV).map{|arg| arg.dup}
          env = (args.shift || ENV).to_hash.dup
          opts = (args.shift || {}).to_hash.dup

          factory = self

          program = Class.new(Program)

          program.factory = factory
          program.argv = argv
          program.env = env
          program.opts = opts

          program.module_eval(&factory)

          program.module_eval do
            dynamically_extend_via_commandline_modes!
            program.set_default_options!
            define_method(:run, &block) if block
            wrap_run!
          end
          program
        end

      end

      def new()
        instance = allocate
        instance.instance_eval do
          pre_initialize()
          before_initialize()
          main_initialize()
          initialize()
          after_initialize()
          post_initialize()
        end
        instance
      end

      def evaluate(&block)
        module_eval(&block)
      end

      def set_default_options!
        option('help', 'h') unless parameters.has_option?('help', 'h')
      end

# TODO - ambiguous modes

    # extend the class based on modules given in argv
    #
      def dynamically_extend_via_commandline_modes!
        self.breadth_first_modes = modes.dup
        size = modes.size

        loop do
          modes.each do |mode|
            arg = argv.first && %r/^#{ argv.first }/
            if arg and mode.name =~ arg
              argv.shift
              modes.clear()
              breadth_first_modes.clear()
              evaluate(&mode)
              self.breadth_first_modes = modes.dup
              depth_first_modes[mode.name] = mode
              break
            end
          end

          arg = argv.first && %r/^#{ argv.first }/
          more_modes = (
            !modes.empty? and modes.any?{|mode| arg && mode.name =~ arg}
          )

          break unless more_modes
        end

        self.modes = depth_first_modes.dup
      end

    # wrap up users run method to handle errors, etc
    #
      def wrap_run!
        evaluate do
          alias_method 'run!', 'run'

          def run()
            exit_status =
              catch :exit do
                begin
                  parse_parameters

                  if help?
                    puts(usage.to_s)
                    exit
                  end

                  pre_run
                  before_run
                  run!
                  after_run
                  post_run

                  finalize
                rescue Object => exception
                  self.exit_status ||= exception.status if exception.respond_to?(:status)
                  handle_exception(exception)
                end
                nil
              end

            self.exit_status ||= (exit_status || exit_success)
            handle_exit(self.exit_status)
          end
        end
      end

# TODO
      def fully_qualified_mode
        modes.map{|mode| mode.name}
      end

      def mode_name
        return 'main' if modes.empty?
        fully_qualified_mode.join(' ')
      end

      undef_method 'usage'
      def usage(*args, &block)
        usage! unless defined? @usage 
        return @usage if args.empty? and block.nil?
        key, value, *ignored = args
        value = block.call if block
        @usage[key.to_s] = value.to_s
      end

      def parameter(*a, &b)
        (parameters << Parameter.create(:parameter, self, *a, &b)).last
      end

      def argument(*a, &b)
        (parameters << Parameter.create(:argument, self, *a, &b)).last
      end

      def option(*a, &b)
        (parameters << Parameter.create(:option, self, *a, &b)).last
      end

      def keyword(*a, &b)
        (parameters << Parameter.create(:keyword, self, *a, &b)).last
      end

      def environment(*a, &b)
        (parameters << Parameter.create(:environment, self, *a, &b)).last
      end

      def default_options!
        option 'help', 'h' unless parameters.has_option?('help', 'h')
      end

      def mode(name, &block)
        name = name.to_s
        block.fattr(:name => name)
        modes[name] = block
        breadth_first_modes[name] = block
        block
      end

      def can_has(ptype, *a, &b)
        key = a.map{|s| s.to_s}.sort_by{|s| -s.size }.first
        can_has_hash.update key => [ptype, a, b]
        key
      end

      def has(key, *keys)
        keys = [key, *keys].flatten.compact.map{|k| k.to_s}
        keys.map do |key|
          ptype, a, b = can_has_hash[key]
          abort "yo - can *not* has #{ key.inspect }!?" unless(ptype and a and b)
          send ptype, *a, &b
          key
        end
      end

      def mixin(name, *names, &block)
        names = [name, *names].flatten.compact.map{|name| name.to_s}
        if block
          names.each do |name|
            mixin_table[name] = block
          end
        else
          names.each do |name|
            module_eval(&mixin_table[name])
          end
        end
      end

## TODO - for some reason these hork the usage!

      %w[ examples samples api ].each do |chunkname|
        module_eval <<-code
          def #{ chunkname } *a, &b 
            txt = b ? b.call : a.join("\\n")
            usage['#{ chunkname }'] = txt
          end
        code
      end
      alias_method 'example', 'examples'
      alias_method 'sample', 'samples'

      def run(&block)
        block ||= lambda{}
        define_method(:run, &block) if block
      end
    end

    extend ClassMethods
  end
end
