module Main
  class Daemon
    require 'fileutils'
    require 'ostruct'
    require 'rbconfig'
    require 'pathname'
    require 'yaml'

    %w(

      main
      script
      dotdir

      dirname
      basename
      script_dir
      daemon_dir
      lock_file
      log_file
      pid_file
      started_at

    ).each{|a| attr(a)}

    def initialize(main)
      @main = main
      @script = @main.script
    end

    def setup!
      @dotdir = @main.dotdir

      @dirname = File.expand_path(File.dirname(@script))
      @basename = File.basename(@script)
      @script_dir = File.expand_path(File.dirname(@script))

      @daemon_dir = File.join(@dotdir, 'daemon')

      @lock_file = File.join(@daemon_dir, 'lock')
      @log_file = File.join(@daemon_dir, 'log')
      @pid_file = File.join(@daemon_dir, 'pid')
      @stdin_file = File.join(@daemon_dir, 'stdin')
      @stdout_file = File.join(@daemon_dir, 'stdout')
      @stderr_file = File.join(@daemon_dir, 'stderr')

      FileUtils.mkdir_p(@daemon_dir) rescue nil

      %w( lock log pid stdin stdout stderr ).each do |which|
        file = instance_variable_get("@#{ which }_file")
        FileUtils.touch(file)
      end

      @started_at = Time.now

      @ppid = Process.pid

      STDOUT.sync = true
      STDERR.sync = true

      self
    end

    def cmd(cmd, &block)
      setup!

      process_cmd!(cmd)
    end

    def process_cmd!(cmd)
      case cmd.to_s
        when /USAGE/i
          cmd_usage

        when /INFO/i
          cmd_info

        when /RESTART/i
          cmd_restart

        when /START/i
          cmd_start

        when /STOP/i
          cmd_stop

        when /PING/i
          cmd_ping

        when /RUN/i
          cmd_run

        when /PID/i
          cmd_pid

        when /SIGNAL/i
          cmd_signal

        when /LOG/i
          cmd_log

        when /DIR/i
          cmd_dir

        when /TAIL/i
          cmd_tail

        else
          cmd_usage
      end
    end

    def Daemon.commands
      instance_methods.map{|method| method.to_s =~ /\Acmd_(.*)/ && $1}.compact
    end

    def commands
      Daemon.commands
    end

    def usage
      "#{ main.program } daemon #{ commands.join('|') }"
    end

    def cmd_usage
      STDERR.puts usage
      exit(42)
    end

    def cmd_info
      info =
        {
          'main'      => @main.program,
          'script'    => @script,
          'dotdir'    => @dotdir
        }

      %w[
        daemon_dir

        lock_file
        log_file
        pid_file
        stdin_file
        stdout_file
        stderr_file
      ].each do |key|
        value = instance_variable_get("@#{ key }")
        info[key] = value
      end

      STDERR.puts(info.to_yaml)

      exit(42)
    end

    def cmd_start
      lock!(:complain => true)

      daemonize!{|pid| puts(pid)}

      redirect_io!

      pid!

      log!

      exec!
    end

    def cmd_stop
      pid = Integer(IO.read(@pid_file)) rescue nil

      if pid
        alive = true

        %w( QUIT TERM ).each do |signal|
          begin
            Process.kill(signal, pid)
          rescue Errno::ESRCH
            nil
          end

          42.times do
            begin
              Process.kill(0, pid)
              sleep(rand)
            rescue Errno::ESRCH
              alive = false
              puts(pid)
              exit(0)
            end
          end
        end

        if alive
          begin
            Process.kill(-9, pid)
            sleep(rand)
          rescue Errno::ESRCH
            nil
          end

          begin
            Process.kill(0, pid)
          rescue Errno::ESRCH
            puts(pid)
            exit(0)
          end
        end
      end
      
      exit(1)
    ensure
      unless alive?
        begin
          FileUtils.rm_f(@pid_file) rescue nil
        rescue Object
        end
      end
    end

    def cmd_restart
      42.times do
        begin
          cmd_stop
          break
        rescue Object => e
          if alive?
            sleep(rand)
          else
            break
          end
        end
      end

      abort("could not stop #{ @script }!") if alive?

      sleep(rand)

      cmd_start
    end

    def cmd_pid
      pid = Integer(IO.read(@pid_file)) rescue nil

      if pid
        begin
          Process.kill(0, pid)
          puts(pid)
          exit(0)
        rescue Errno::ESRCH
          exit(1)
        end
      else
        exit(1)
      end

      exit(1)
    end

    def cmd_ping
      pid = Integer(IO.read(@pid_file)) rescue nil

      if pid
        signaled = false

        begin
          Process.kill('SIGALRM', pid)
          signaled = true
        rescue Object
          nil
        end

        if signaled
          STDOUT.puts(pid)
          exit
        end
      end
    end

    def cmd_run
      lock!(:complain => true)

      pid!

      log!

      exec!
    end

    def cmd_signal
      pid = Integer(IO.read(@pid_file)) rescue nil
      if pid
        signal = ARGV.shift || 'SIGALRM'
        Process.kill(signal, pid)
        puts(pid)
        exit(0)
      end
      exit(42)
    end

    def cmd_log
      puts(@log_file)
      exit(42)
    end

    def cmd_dir
      puts(@daemon_dir)
      exit(42)
    end

    def cmd_tail
      system("tail -F #{ @stdout_file.inspect } #{ @stderr_file.inspect } #{ @log_file.inspect }")
      exit(42)
    end

    def lock!(options = {})
      complain = options['complain'] || options[:complain]
      fd = open(@lock_file, 'r+')
      status = fd.flock(File::LOCK_EX|File::LOCK_NB)

      unless status == 0
        if complain
          pid = Integer(IO.read(@pid_file)) rescue '?'
          warn("instance(#{ pid }) is already running!")
        end
        exit(42)
      end
      @lock = fd # prevent garbage collection from closing the file!
      at_exit{ unlock! }
    end

    def unlock!
      @lock.flock(File::LOCK_UN|File::LOCK_NB) if @lock
    end

    def pid!
      open(@pid_file, 'w+') do |fd|
        fd.puts(Process.pid)
      end
      at_exit{ FileUtils.rm_f(@pid_file) }
    end

    def exec!
      ::Kernel.exec(script_start_command)
    end

    def script_start_command
      argv = @main.argv.dup
      argv.shift if argv.first == "--"
      "#{ which_ruby } #{ @script.inspect } #{ argv.map{|arg| arg.inspect}.join(' ') }"
    end

    def log!
      logger.info("DAEMON START - #{ Process.pid }")

      at_exit do
        logger.info("DAEMON STOP - #{ Process.pid }") rescue nil
      end
    end

    def alive?
      pid = Integer(IO.read(@pid_file)) rescue nil
      alive = !!pid

      if pid
        alive =
          begin
            Process.kill(0, pid)
            true
          rescue Errno::ESRCH
            false 
          end
      end

      alive
    end

    def which_ruby
      c = ::RbConfig::CONFIG
      ruby = File::join(c['bindir'], c['ruby_install_name']) << c['EXEEXT']
      raise "ruby @ #{ ruby } not executable!?" unless test(?e, ruby)
      ruby
    end

    def logger
      @logger ||= (
        require 'logger' unless defined?(Logger)

        if @log_file
          number_rolled = 7
          megabytes     = 2 ** 20
          max_size      = 42 * megabytes

          ::Logger.new(@log_file, number_rolled, max_size)
        else
          ::Logger.new(STDERR)
        end
      )
    end

    def logger=(logger)
      @logger = logger
    end

  # daemonize{|pid| puts "the pid of the daemon is #{ pid }"}
  #

    def daemonize!(options = {}, &block)
    # optional directory and umask
    #
      chdir = options[:chdir] || options['chdir'] || @daemon_dir || '.'
      umask = options[:umask] || options['umask'] || 0

    # drop to the background avoiding the possibility of zombies..
    #
      detach!(&block)

    # close all open io handles *except* these ones
    #
      keep_ios(STDIN, STDOUT, STDERR, @lock)

    # sane directory and umask
    #
      Dir::chdir(chdir)
      File::umask(umask)

    # global daemon flag
    #
      $DAEMON = true
    end

    def detach!(&block)
    # setup a pipe to relay the grandchild pid through
    #
      a, b = IO.pipe

    # in the parent we wait for the pid, wait on our child to avoid zombies, and
    # then exit
    #
      if fork
        b.close
        pid = Integer(a.read.strip)
        a.close
        block.call(pid) if block
        Process.waitall
        exit!
      end

    # the child simply exits so it can be reaped - avoiding zombies.  the pipes
    # are inherited in the grandchild
    #
      if fork
        exit!
      end

    # finally, the grandchild sends it's pid back up the pipe to the parent is
    # aware of the pid
    #
      a.close
      b.puts(Process.pid)
      b.close

    # might as well nohup too...
    #
      Process::setsid rescue nil
    end

    def redirect_io!(options = {})
      stdin = options[:stdin] || @stdin_file
      stdout = options[:stdout] || @stdout_file
      stderr = options[:stderr] || @stderr_file

      {
        STDIN => stdin, STDOUT => stdout, STDERR => stderr
      }.each do |io, file|
        opened = false

        fd =
          case
            when file.is_a?(IO)
              file
            when file.to_s == 'null'
              opened = true
              open('/dev/null', 'ab+')
            else
              opened = true
              open(file, 'ab+')
          end

        begin
          fd.sync = true rescue nil
          fd.truncate(0) rescue nil
          io.reopen(fd)
        ensure
          fd.close rescue nil if opened
        end
      end
    end

    def keep_ios(*ios)
      filenos = []

      ios.flatten.compact.each do |io|
        begin
          fileno = io.respond_to?(:fileno) ? io.fileno : Integer(io)
          filenos.push(fileno)
        rescue Object
          next
        end
      end

      ObjectSpace.each_object(IO) do |io|
        begin
          fileno = io.fileno
          next if filenos.include?(fileno)
          io.close unless io.closed?
        rescue Object
          next
        end
      end
    end
  end
end
