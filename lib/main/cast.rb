module Main
  module Cast
    def self.export m
      module_function m
      public m
    end

    List = []

    def self.cast m, &b
      define_method m, &b
      export m
      List << m.to_s
    end

    cast :boolean do |obj|
      case obj.to_s
        when %r/^(true|t|1)$/ 
          true
        when %r/^(false|f|0)$/ 
          false
        else
          !!obj
      end
    end

    cast :integer do |obj|
      Float(obj).to_i
    end

    cast :float do |obj|
      Float obj
    end

    cast :number do |obj|
      Float obj rescue Integer obj
    end

    cast :string do |obj|
      String obj
    end

    cast :symbol do |obj|
      String(obj).to_sym
    end

    cast :uri do |obj|
      require 'uri' unless defined?(::URI)
      ::URI.parse obj.to_s
    end

    cast :time do |obj|
      require 'time'
      ::Time.parse obj.to_s
    end

    cast :date do |obj|
      require 'date' unless defined?(::Date)
      ::Date.parse obj.to_s
    end

    cast :pathname do |obj|
      require 'pathname' unless defined?(::Pathname)
      Pathname.new(obj.to_s)
    end

    cast :path do |obj|
      File.expand_path(obj.to_s)
    end

    stdin = proc do |obj| 
      require 'fattr' unless defined?(Fattr)
      case obj.to_s
        when '-', 'stdin'
          io = STDIN.dup
          io.fattr(:path){ '/dev/stdin' }
          io
        else
          io = open(obj.to_s, 'r+')
          at_exit{ io.close }
          io
      end
    end
    cast(:stdin, &stdin)
    cast(:input, &stdin)

    stdout = proc do |obj|
      require 'fattr' unless defined?(Fattr)
      case obj.to_s
        when '-', 'stdout'
          io = STDOUT.dup
          io.fattr(:path){ '/dev/stdout' }
          io
        else
          io = open(obj.to_s, 'w+')
          at_exit{ io.close }
          io
      end
    end
    cast(:stdout, &stdout)
    cast(:output, &stdout)

    cast :slug do |obj|
      string = [obj].flatten.compact.join('-')
      words = string.to_s.scan(%r/\w+/)
      words.map!{|word| word.gsub %r/[^0-9a-zA-Z_-]/, ''}
      words.delete_if{|word| word.nil? or word.strip.empty?}
      String(words.join('-').downcase)
    end

    cast :list do |*objs|
      [*objs].flatten.join(',').split(/[\n,]/).map{|item| item.strip}.delete_if{|item| item.strip.empty?}
    end

# add list_of_xxx methods
#
    List.dup.each do |type|
      next if type.to_s =~ %r/list/ 
      %W" list_of_#{ type } list_of_#{ type }s ".each do |m|
        define_method m do |*objs|
          list(*objs).map{|obj| send type, obj}
        end
        export m 
        List << m
      end
    end

# add list_of_xxx_from_file
#
    List.dup.each do |type|
      next if type.to_s =~ %r/list/ 
      %W" list_of_#{ type }_from_file list_of_#{ type }s_from_file ".each do |m|
        define_method m do |*args|
          buf = nil
          if args.size == 1 and args.first.respond_to?(:read)
            buf = args.first.read
          else
            open(*args){|io| buf = io.read}
          end
          send(m.sub(/_from_file/, ''), buf)
        end
        export m
        List << m
      end
    end

    def self.[] sym
      prefix = sym.to_s.downcase.to_sym
      candidates = List.select{|m| m =~ %r/^#{ prefix }/i}
      m = candidates.shift
      raise ArgumentError, "unsupported cast: #{ sym.inspect } (#{ List.join ',' })" unless
        m
      raise ArgumentError, "ambiguous cast: #{ sym.inspect } (#{ List.join ',' })" unless
        candidates.empty? or m.to_s == sym.to_s
      this = self
      lambda{|obj| method(m).call obj}
    end

    def Cast.cast(which, *args, &block)
      Cast.send(which, *args, &block)
    end
  end
end
