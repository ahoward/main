module Main
  class Program
    module InstanceMethods
    # instance methods
    #
      fattr('main'){ self.class }
      fattr('argv'){ main.argv }
      fattr('env'){ main.env }
      fattr('opts'){ main.opts }
      fattr('stdin'){ main.stdin }
      fattr('stdout'){ main.stdout }
      fattr('stderr'){ main.stderr }
      fattr('logger'){ main.logger }
      fattr('script'){ main.script }
      fattr('params')
      fattr('finalizers')

      %w( 
        program name synopsis description author version
        exit_status exit_success exit_failure exit_warn exit_warning
        logger_level
        usage
      ).each{|a| fattr(a){ self.class.send a}}

      alias_method 'status', 'exit_status'
      alias_method 'status=', 'exit_status='

      %w( parameters param ).each do |dst|
        alias_method "#{ dst }", "params"
        alias_method "#{ dst }=", "params="
        alias_method "#{ dst }?", "params?"
      end

      %w( debug info warn fatal error ).each do |m|
        module_eval <<-code, __FILE__, __LINE__
          def #{ m }(*a, &b)
            logger.#{ m }(*a, &b)
          end
        code
      end

      def pre_initialize() :hook end
      def before_initialize() :hook end
      def main_initialize()
        setup_finalizers
        setup_io_redirection
        setup_logging
      end
      def initialize() :hook end
      def after_initialize() :hook end
      def post_initialize() :hook end

      def setup_finalizers
        @finalizers ||= []
        finalizers = @finalizers
        ObjectSpace.define_finalizer(self) do
          while((f = finalizers.pop)); f.call; end
        end
      end

      def finalize
        @finalizers ||= []
        while((f = @finalizers.pop)); f.call; end
      end

      def setup_io_redirection
        self.stdin = opts['stdin'] || opts[:stdin] || stdin
        self.stdout = opts['stdout'] || opts[:stdout] || stdout
        self.stderr = opts['stderr'] || opts[:stderr] || stderr
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
            else
              if log.is_a?(Array)
                @logger = Logger.new(*log)
              else
                @logger = Logger.new(log)
                @logger.level = logger_level
              end
          end
        end
        @logger
      end

      def setup_io_restoration
        @finalizers ||= []
        [STDIN, STDOUT, STDERR].each do |io|
          dup = io.dup
          @finalizers.push(
            lambda do
              io.reopen(dup)
            end
          )
        end
      end
      
      undef_method 'stdin='
      def stdin= io
        unless(defined?(@stdin) and (@stdin == io))
          @stdin =
            if io.respond_to?('read')
              io
            else
              fd = open(io.to_s, 'r+')
              @finalizers.push(lambda{ fd.close })
              fd
            end
          begin
            STDIN.reopen(@stdin)
          rescue
            $stdin = @stdin
            ::Object.send(:remove_const, 'STDIN')
            ::Object.send(:const_set, 'STDIN', @stdin)
          end
        end
      end

      undef_method 'stdout='
      def stdout= io
        unless(defined?(@stdout) and (@stdout == io))
          @stdout =
            if io.respond_to?('write')
              io
            else
              fd = open(io.to_s, 'w+')
              @finalizers.push(lambda{ fd.close })
              fd
            end
          begin
            STDOUT.reopen(@stdout)
          rescue
            $stdout = @stdout
            ::Object.send(:remove_const, 'STDOUT')
            ::Object.send(:const_set, 'STDOUT', @stdout)
          end
        end
      end

      undef_method 'stderr='
      def stderr= io
        unless(defined?(@stderr) and (@stderr == io))
          @stderr =
            if io.respond_to?('write')
              io
            else
              fd = open(io.to_s, 'w+')
              @finalizers.push(lambda{ fd.close })
              fd
            end
          begin
            STDERR.reopen(@stderr)
          rescue
            $stderr = @stderr
            ::Object.send(:remove_const, 'STDERR')
            ::Object.send(:const_set, 'STDERR', @stderr)
          end
        end
      end
      
      def pre_parse_parameters() :hook end
      def before_parse_parameters() :hook end
      def parse_parameters
        pre_parse_parameters
        before_parse_parameters

        self.class.parameters.parse(self)
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

      def help?
        (params['help'] and params['help'].given?) or argv.first == 'help'
      end

      def shell!
        Pry.hooks.clear_all
        prompt = "#{ name } > "
        Pry.config.prompt = proc{|*a| prompt } 
        binding.pry
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
          if e.respond_to?(:status)
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
        exit_status(( Util.integer(exit_status) rescue(exit_status ? 0 : 1) ))
      end

      def handle_exit(status)
        exit(( Integer(status) rescue 1 ))
      end

      def fcall(object, method, *argv, &block)
        method = object.method(method)
        arity = method.arity
        if arity >= 0
          argv = argv[0, arity]
        else
          arity = arity.abs - 1
          argv = argv[0, arity] + argv[arity .. -1]
        end
        method.call(*argv, &block)
      end

      %w[ before instead after ].each do |which|
        module_eval <<-code, __FILE__, __LINE__
          def error_handler_#{ which }(*argv, &block)
            block.call(*argv)
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

      def main_env(*args, &block)
        self.class.main_env(*args, &block)
      end

      def state_path(&block)
        self.class.state_path(&block)
      end
      alias_method('dotdir', 'state_path')

      def db(&block)
        self.class.db(&block)
      end

      def config(&block)
        self.class.config(&block)
      end

      def input
        @input ||= params[:input].value if params[:input]
      end

      def output
        @output ||= params[:output].value if params[:output]
      end

      def daemon
        @daemon ||= Main::Daemon.new(self)
      end
    end

    include InstanceMethods
  end
end
