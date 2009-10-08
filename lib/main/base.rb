module Main
  class Base
    class << Base
    # class fattrs
    #
      fattr( 'name' ){ File.basename $0 } 
      fattr( 'synopsis' ){ Main::Usage.default_synopsis(self) }
      fattr( 'description' )
      fattr( 'usage' ){ Main::Usage.default_usage self } 
      fattr( 'modes' ){ Main::Mode.list }

      fattr( 'program' ){ File.basename $0 } 
      fattr( 'author' )
      fattr( 'version' )
      fattr( 'stdin' ){ $stdin } 
      fattr( 'stdout' ){ $stdout } 
      fattr( 'stderr' ){ $stderr } 
      fattr( 'logger' ){ Logger.new(stderr) } 
      fattr( 'logger_level' ){ Logger::INFO } 
      fattr( 'exit_status' ){ Main::EXIT_SUCCESS } 
      fattr( 'exit_success' ){ Main::EXIT_SUCCESS } 
      fattr( 'exit_failure' ){ Main::EXIT_FAILURE } 
      fattr( 'exit_warn' ){ Main::EXIT_WARN } 
      fattr( 'parameters' ){ Main::Parameter::List[] }
      fattr( 'can_has_hash' ){ Hash.new }
      fattr( 'mixin_table' ){ Hash.new }

      undef_method 'usage'
      def usage(*args, &block)
        usage! unless defined? @usage 
        return @usage if args.empty? and block.nil?
        key, value, *ignored = args
        value = block.call if block
        @usage[key.to_s] = value.to_s
      end

      def create(*args, &block)
        Factory.new(*args, &block).new()
      end

      class Factory
        def initialize(*args, &block)
          @args, @block = args, block
        end

        def new(*args, &block)
          subclass = Class.new(Base, &@block)
          subclass.default_options!
          subclass.Fattr(:factory => self)
          subclass
        end
      end

      def new(*args, &block)
        argv = (args.shift || ARGV).map{|arg| arg.dup}
        env = (args.shift || ENV).to_hash.dup
        opts = (args.shift || {}).to_hash.dup

        subclass = factory.new

        subclass.module_eval do
          Fattr :argv => argv
          Fattr :env => env
          Fattr :opts => opts

          dynamically_extend_via_commandline_modes!

          instance =
            allocate.instance_eval do
              pre_initialize
              before_initialize
              main_initialize(argv, env, opts)
              initialize
              after_initialize
              post_initialize
              self
            end

          run(&block) if block

          wrap_run!

          instance
        end
      end

# TODO - ambiguous modes

    # extend the class based on modules given in argv
    #
      def dynamically_extend_via_commandline_modes!
        size = modes.size
        depth_first_modes = Array.fields

        loop do
          modes.each do |mode|
            arg = argv.first && %r/^#{ argv.first }/
            if arg and mode.name =~ arg
              argv.shift
              modes.clear
              module_eval(&mode)
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

        self.modes = depth_first_modes
      end

    # wrap up users run method to handle errors, etc
    #
      def wrap_run!
        const_set(:RUN, instance_method(:run))

        module_eval do
          def run *a, &b
            argv.push "--#{ argv.shift }" if argv.first == 'help'

            status =
              catch :exit do
                begin

                  parse_parameters

                  if params['help'] and params['help'].given?
                    print usage.to_s
                    exit
                  end

                  pre_run
                  before_run
                  self.class.const_get(:RUN).bind(self).call(*a, &b)
                  after_run
                  post_run

                  finalize
                rescue Exception => e
                  handle_exception e
                end
                nil
              end

            handle_exit(status)
          end
        end
      end

# TODO
      def fully_qualified_mode
        modes.map{|mode| mode.name}.join(' ')
      end

      def mode_name
        return 'main' if modes.empty?
        fully_qualified_mode
      end

      def run(&b) define_method(:run, &b) end
    end

    extend Main::DSL

    fattr('argv'){ ARGV }
    fattr('env'){ ENV }
    fattr 'params'
    fattr('stdin'){ Main::Base.stdin }
    fattr('stdout'){ Main::Base.stdout }
    fattr('stderr'){ Main::Base.stderr }
    fattr('logger'){ Main::Base.logger }

    %w( 
      program name synopsis description author version
      exit_status exit_success exit_failure exit_warn
      logger_level
      usage
    ).each{|a| fattr(a){ self.class.send a}}

    %w( parameters param ).each do |dst|
      alias_method "#{ dst }", "params"
      alias_method "#{ dst }=", "params="
      alias_method "#{ dst }?", "params?"
    end

    %w( debug info warn fatal error ).each do |m|
      module_eval <<-code
        def #{ m } *a, &b
          logger.#{ m } *a, &b
        end
      code
    end

    def pre_initialize() :hook end
    def before_initialize() :hook end
    def main_initialize argv = ARGV, env = ENV, opts = {}
      @argv, @env, @opts = argv, env, opts
      setup_finalizers
      setup_io_restoration
      setup_io_redirection
      setup_logging
    end
    def initialize() :hook end
    def after_initialize() :hook end
    def post_initialize() :hook end

    def setup_finalizers
      @finalizers = finalizers = []
      ObjectSpace.define_finalizer(self) do
        while((f = finalizers.pop)); f.call; end
      end
    end

    def finalize
      while((f = @finalizers.pop)); f.call; end
    end

    def setup_io_redirection
      self.stdin = @opts['stdin'] || @opts[:stdin] || self.class.stdin
      self.stdout = @opts['stdout'] || @opts[:stdout] || self.class.stdout
      self.stderr = @opts['stderr'] || @opts[:stderr] || self.class.stderr
    end

    def setup_logging
      log = self.class.logger || stderr
      self.logger = log
    end
    undef_method 'logger='
    def logger= log
      unless(defined?(@logger) and @logger == log)
        case log 
          when ::Logger, Logger
            @logger = log
          when IO, StringIO
            @logger = Logger.new log 
            @logger.level = logger_level 
          else
            @logger = Logger.new(*log)
            @logger.level = logger_level 
        end
      end
      @logger
    end

    def setup_io_restoration
      [STDIN, STDOUT, STDERR].each do |io|
        dup = io.dup and @finalizers.push lambda{ io.reopen dup rescue nil }
      end
    end

    undef_method 'stdin='
    def stdin= io
      unless(defined?(@stdin) and (@stdin == io))
        @stdin =
          if io.respond_to? 'read'
            io
          else
            fd = open io.to_s, 'r+'
            @finalizers.push lambda{ fd.close }
            fd
          end
        begin
          STDIN.reopen @stdin
        rescue
          $stdin = @stdin
          ::Object.const_set 'STDIN', @stdin
        end
      end
    end

    undef_method 'stdout='
    def stdout= io
      unless(defined?(@stdout) and (@stdout == io))
        @stdout =
          if io.respond_to? 'write'
            io
          else
            fd = open io.to_s, 'w+'
            @finalizers.push lambda{ fd.close }
            fd
          end
        STDOUT.reopen @stdout rescue($stdout = @stdout)
      end
    end

    undef_method 'stderr='
    def stderr= io
      unless(defined?(@stderr) and (@stderr == io))
        @stderr =
          if io.respond_to? 'write'
            io
          else
            fd = open io.to_s, 'w+'
            @finalizers.push lambda{ fd.close }
            fd
          end
        STDERR.reopen @stderr rescue($stderr = @stderr)
      end
    end
    
    def pre_parse_parameters() :hook end
    def before_parse_parameters() :hook end
    def parse_parameters
      pre_parse_parameters
      before_parse_parameters

      self.class.parameters.parse self
      @params = Parameter::Table.new
      self.class.parameters.each{|p| @params[p.name.to_s] = p}

      after_parse_parameters
      post_parse_parameters
    end
    def after_parse_parameters() :hook end
    def post_parse_parameters() :hook end

    def pre_run() :hook end
    def before_run() :hook end
    def run
      raise NotImplementedError, 'run not defined'
    end
    def after_run() :hook end
    def post_run() :hook end

    fattr 'mode'
    def modes
      self.class.modes
    end

    def help!(status = 0)
      print usage.to_s
      exit(status)
    end

    def abort(message = 'exit')
      raise SystemExit.new(message)
    end

    def handle_exception(e)
      if e.respond_to?(:error_handler_before)
        fcall(e, :error_handler_before, self)
      end

      if e.respond_to?(:error_handler_instead)
        fcall(e, :error_handler_instead, self)
      else
        if e.respond_to? :status
          exit_status(( e.status ))
        end

        if Softspoken === e or SystemExit === e
          quiet = ((SystemExit === e and e.message.respond_to?('abort')) or # see main/stdext.rb
                  (SystemExit === e and e.message == 'exit'))
          stderr.puts e.message unless quiet
        else
          fatal{ e }
        end
      end

      if e.respond_to?(:error_handler_after)
        fcall(e, :error_handler_after, self)
      end

      exit_status(( exit_failure )) if exit_status == exit_success
      exit_status(( Integer(exit_status) rescue(exit_status ? 0 : 1) ))
      exit exit_status
    end

    def handle_exit(status)
      exit(( Integer(status) rescue 0 ))
    end

    def fcall(object, method, *argv, &block)
      method = object.method(method)
      arity = m.arity
      if arity >= 0
        argv = argv[0, arity]
      else
        arity = arity.abs - 1
        argv = argv[0, arity] + argv[arity .. -1]
      end
      method.call(*argv, &block)
    end

    %w[ before instead after ].each do |which|
      module_eval <<-code
        def error_handler_#{ which } *argv, &block
          block.call *argv
        end
      code
    end

    def instance_eval_block(*argv, &block)
      singleton_class =
        class << self
          self
        end
      singleton_class.module_eval{ define_method('__instance_eval_block', &block) }
      fcall(self, '__instance_eval_block', *argv, &block)
    end
  end
end
