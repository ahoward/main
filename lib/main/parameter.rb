module Main
  class Parameter
    class Error < StandardError
      include Softspoken
      fattr 'wrapped'
    end
    class Arity < Error; end
    class NotGiven < Arity; end
    class InValid < Error; end
    class NoneSuch < Error; end
    class AmbigousOption < Error; end
    class NeedlessArgument < Error; end
    class MissingArgument < Error; end
    class InvalidOption < Error; end

    class << self
      def wrapped_error w
        e = Error.new "(#{ w.message } (#{ w.class }))"
        e.wrapped = w
        e.set_backtrace(w.backtrace || [])
        e
      end

      def wrap_errors
        begin
          yield
        rescue => e
          raise wrapped_error(e)
        end
      end

      Types = [ Parameter ]
      def inherited other
        Types << other
      end

      def sym
        @sym ||= name.split(%r/::/).last.downcase.to_sym
      end

      def class_for(type)
        sym = type.to_s.downcase.to_sym
        c = Types.detect{|t| t.sym == sym}
        raise ArgumentError, type.inspect unless c
        c
      end

      def create(type, main, *a, &b)
        c = class_for(type)
        obj = c.allocate
        obj.type = c.sym
        obj.main = main
        obj.instance_eval{ initialize(*a, &b) }
        obj
      end
    end

    fattr 'main'
    fattr 'type'
    fattr 'names'
    fattr 'abbreviations'
    fattr 'argument'
    fattr 'given'
    fattr 'cast'
    fattr 'validate'
    fattr 'description'
    fattr 'synopsis'
    fattr('values'){ [] }
    fattr('defaults'){ [] }
    fattr('examples'){ [] }

    fattr 'arity' => 1
    fattr 'required' => false

    fattr 'error_handler_before'
    fattr 'error_handler_instead'
    fattr 'error_handler_after'

    def initialize(name, *names, &block)
      @names = Cast.list_of_string(name, *names)

      @names.map! do |name|
        if name =~ %r/^-+/
          name.gsub! %r/^-+/, ''
        end

        if name =~ %r/=.*$/
          argument( name =~ %r/=\s*\[.*$/ ? :optional : :required )
          name.gsub! %r/=.*$/, ''
        end

        name
      end
      @names = @names.sort_by{|name| name.size}.reverse
      @names[1..-1].each do |name|
        raise ArgumentError, "only one long name allowed (#{ @names.inspect })" if
          name.size > 1
      end

      DSL.evaluate(self, &block) if block
      sanity_check!
    end

    def sanity_check!
      raise Arity, "#{ name } with arity -1 (zero or more args) cannot be required" if(arity == -1 and required?)
    end

    def name
      names.first
    end

    def default(*values)
      defaults(values) unless values.empty?
      defaults.first
    end

    def default=(value)
      default(value)
    end

    def typename
      prefix = '--' if type.to_s =~ %r/option/
      "#{ type }(#{ prefix }#{ name })"
    end

    def add_value value
      given true
      values << value
    end

    def value
      values.first
    end

    def argument_none?
      argument.nil?
    end

    def argument_required?
      argument and 
        argument.to_s.downcase.to_sym == :required
    end
    def argument_optional?
      argument and
        argument.to_s.downcase.to_sym == :optional
    end

    def optional?
      not required?
    end
    def optional= bool 
      self.required !bool
    end

=begin
    def setup!
      return false unless given?
      adding_handlers do
        check_arity
        apply_casting
        check_validation
      end
      true
    end
=end

    def setup!
      adding_handlers do
        check_arity
        apply_casting
        check_validation
      end
    end

    def check_arity 
      return true if not given? and optional?

      ex = values.size == 0 ? NotGiven : Arity

      (raise ex, "#{ typename })" if values.size.zero? and argument_required?) unless arity == -1

      if arity >= 0
        min = arity
        sign = ''
      else
        min = arity.abs - 1
        sign = '-'
      end

      arity = min

      if values.size < arity
        if argument_optional?
          raise ex, "#{ typename }) #{ values.size }/#{ sign }#{ arity }" if(values.size < arity and values.size > 0)
        elsif argument_required? or argument_none?
          raise ex, "#{ typename }) #{ values.size }/#{ sign }#{ arity }" if(values.size < arity)
        end
      end
    end

    def apply_casting 
      if cast?
        op = cast.respond_to?('call') ? cast : Cast[cast]
        case op.arity
          when -1
            replacement = Parameter.wrap_errors{ op.call(*values) }
            values.replace(replacement)
          else
            values.map! do |val|
              Parameter.wrap_errors{ op.call val }
            end
        end
      end
    end

    def check_validation 
      if validate?
        values.each do |value|
          validate[value] or 
            raise InValid, "invalid: #{ typename }=#{ value.inspect }"
        end
      end
    end

    def add_handlers e
      esc = 
        class << e
          self
        end

      this = self

      %w[ before instead after ].each do |which|
        getter = "error_handler_#{ which }"
        query = "error_handler_#{ which }?"
        if send(query)
          handler = send getter 
          esc.module_eval do
            define_method(getter) do |main|
              main.instance_eval_block self, &handler
            end
          end
        end
      end
    end

    def adding_handlers
      begin
        yield
      rescue Exception => e
        add_handlers e
        raise
      end
    end

    def remove
      main.parameters.delete(self)
    end
    alias_method('remove!', 'remove')
    alias_method('ignore', 'remove')
    alias_method('ignore!', 'ignore')

    class Argument < Parameter
      fattr 'required' => true

      fattr 'synopsis' do
        label = name
        op = required ? "->" : "~>"
        value = defaults.size > 0 ? "#{ name }=#{ defaults.join ',' }" : name 
        value = "#{ cast }(#{ value })" if(cast and not cast.respond_to?(:call))
        "#{ label } (#{ arity } #{ op } #{ value })"
      end
    end

    class Option < Parameter
      fattr 'required' => false
      fattr 'arity' => 0

      fattr 'synopsis' do
        long, *short = names
        value = cast || name 
        rhs = argument ? (argument == :required ? "=#{ name }" : "=[#{ name }]") : nil 
        label = ["--#{ long }#{ rhs }", short.map{|s| "-#{ s }"}].flatten.join(", ")
        unless argument_none?
          op = required ? "->" : "~>"
          value = defaults.size > 0 ? "#{ name }=#{ defaults.join ',' }" : name 
          value = "#{ cast }(#{ value })" if(cast and not cast.respond_to?(:call))
          "#{ label } (#{ arity } #{ op } #{ value })"
        else
          label
        end
      end
    end

    class Keyword < Parameter
      fattr 'required' => false
      fattr 'argument' => :required 

      fattr 'synopsis' do
        label = "#{ name }=#{ name }"
        op = required ? "->" : "~>"
        value = defaults.size > 0 ? "#{ name }=#{ defaults.join ',' }" : name 
        value = "#{ cast }(#{ value })" if(cast and not cast.respond_to?(:call))
        "#{ label } (#{ arity } #{ op } #{ value })"
      end
    end

    class Environment < Parameter
      fattr 'argument' => :required 

      fattr 'synopsis' do
        label = "env[#{ name }]=#{ name }"
        op = required ? "->" : "~>"
        value = defaults.size > 0 ? "#{ name }=#{ defaults.join ',' }" : name 
        value = "#{ cast }(#{ value })" if(cast and not cast.respond_to?(:call))
        "#{ label } (#{ arity } #{ op } #{ value })"
      end
    end

    class List < ::Array
      fattr :main
      fattr :argv
      fattr :env

      def parse main
        @main, @argv, @env = main, main.argv, main.env

        ignore, stop = [], argv.index('--')

        if stop
          ignore = argv[stop .. -1]
          (argv.size - stop).times{ argv.pop }
        end

        argv.push "--#{ argv.shift }" if argv.first == 'help'

        parse_options argv

        return 'help' if detect{|p| p.name.to_s == 'help' and p.given?}

        parse_keywords argv
        parse_arguments argv
        parse_environment env

        defaults!
        validate!

        argv.push(*ignore[1..-1]) unless ignore.empty? 

        return self
      ensure
        @main, @argv, @env = nil
      end

      def parse_options argv, params = nil
        params ||= options 

        spec, h, s = [], {}, {}

        params.each do |p|
          head, *tail = p.names
          long = "--#{ head }"
          shorts = tail.map{|t| "-#{ t }"}
          type =
            if p.argument_required? then GetoptLong::REQUIRED_ARGUMENT
            elsif p.argument_optional? then GetoptLong::OPTIONAL_ARGUMENT
            else GetoptLong::NO_ARGUMENT
            end
          a = [ long, shorts, type ].flatten
          spec << a 
          h[long] = p 
          s[long] = a 
        end

        begin
          GetoptLong.new(argv, *spec).each do |long, value|
            value =
              case s[long].last
                when GetoptLong::NO_ARGUMENT
                  value.empty? ? true : value
                when GetoptLong::OPTIONAL_ARGUMENT
                  value.empty? ? true : value
                when GetoptLong::REQUIRED_ARGUMENT
                  value
              end
            p = h[long]
            p.add_value value
          end
        rescue GetoptLong::AmbigousOption, GetoptLong::NeedlessArgument,
               GetoptLong::MissingArgument, GetoptLong::InvalidOption => e
          c = Parameter.const_get e.class.name.split(/::/).last
          ex = c.new e.message
          ex.set_backtrace e.backtrace
          ex.extend Softspoken
          raise ex
        end

=begin
        params.each do |p|
          p.setup!
        end
=end
      end

      def parse_arguments argv, params=nil
        params ||= select{|p| p.type == :argument}

        params.each do |p|
          if p.arity >= 0
            p.arity.times do
              break if argv.empty?
              value = argv.shift
              p.add_value value
            end
          else
            arity = p.arity.abs - 1
            arity.times do
              break if argv.empty?
              value = argv.shift
              p.add_value value
            end
            argv.size.times do
              value = argv.shift
              p.add_value value
            end
          end
        end

=begin
        params.each do |p|
          p.setup!
        end
=end
      end

      def parse_keywords argv, params=nil
        params ||= select{|p| p.type == :keyword}

        replacements = {}

        params.each do |p|
          names = p.names
          name = names.sort_by{|n| [n.size,n]}.last

          kre = %r/^\s*(#{ names.join '|' })\s*=/
          opt = "--#{ name }"
          i = -1 

          argv.each_with_index do |a, idx|
            i += 1
            b = argv[idx + 1]
            s = "#{ a }#{ b }"
            m, key, *ignored = kre.match(s).to_a
            if m
              replacements[i] ||= a.gsub %r/^\s*#{ key }/, opt
              next
            end
=begin
            abbrev = name.index(key) == 0
            if abbrev
              replacements[i] ||= a.gsub %r/^\s*#{ key }/, opt
            end
=end
          end
        end

        replacements.each do |i, r|
          argv[i] = r
        end

        parse_options argv, params
      end
      
      def parse_environment env, params=nil
        params ||= select{|p| p.type == :environment}

        params.each do |p|
          names = p.names
          name = names.first
          value = env[name]
          next unless value
          p.add_value value
        end

=begin
        params.each do |p|
          p.setup!
        end
=end
      end

      def defaults!
        each do |p|
          if(p.defaults? and (not p.given?)) 
            p.defaults.each do |default|
              p.values << (default.respond_to?('to_proc') ? main.instance_eval(&default) : default) # so as NOT to set 'given?'
            end
          end
        end
      end

      def validate!
        each do |p|
          #p.adding_handlers do
            #next if p.arity == -1
            #raise NotGiven, "#{ p.typename } not given" if(p.required? and (not p.given?))
          #end
          p.setup!
        end
      end

      [:parameter, :option, :argument, :keyword, :environment].each do |m| 
        define_method("#{ m }s"){ select{|p| p.type == m or m == :parameter} }

        define_method("has_#{ m }?") do |name, *names|
          catch :has do
            names = Cast.list_of_string name, *names
            send("#{ m }s").each do |param|
              common = Cast.list_of_string(param.names) & names 
              throw :has, true unless common.empty?
            end
            false
          end
        end
      end

      def delete name, *names
        name, *names = name.names if Parameter === name
        names = Cast.list_of_string name, *names
        keep = []
        each do |param|
          common = Cast.list_of_string(param.names) & names 
          keep << param if common.empty?
        end
        replace keep
      end

      def <<(*a)
        delete(*a)
        super
      end

      def [](*index)
        first = index.first
        if(index.size == 1 and (first.is_a?(String) or first.is_a?(Symbol)))
          first = first.to_s
          return detect{|param| param.name == first}
        end
        return super
      end
    end

    class DSL
      def self.evaluate param, &block
        new(param).instance_eval(&block)
      end

      attr 'param'

      def initialize param
        @param = param
      end

      def fattr a = nil, &block
        name = param.name
        a ||= name
        b = fattr_block_for(name, &block)
        @param.main.module_eval{ fattr(*a, &b) }
      end
      alias_method 'attribute', 'fattr'

      def fattr_block_for name, &block
        block ||= lambda{|param| [0,1].include?(param.arity) ? param.value : param.values }
        lambda{|*args| block.call(self.param[name]) }
      end

      def attr(*a, &b)
        fattr(*a, &b)
      end

      def example *list
        list.flatten.compact.each do |elem|
          param.examples << elem.to_s
        end
      end
      alias_method "examples", "example"


      def type *sym
        sym.size == 0 ? param.type : (param.type = sym.first)
      end
      def type?
        param.type?
      end

      def synopsis *arg 
        arg.size == 0 ? param.synopsis : (param.synopsis arg.first)
      end

      def argument arg 
        param.argument arg 
      end
      def argument_required bool = true
        if bool
          param.argument :required
        else
          param.argument false 
        end
      end
      def argument_required?
        param.argument_required?
      end

      def argument_optional bool = true
        if bool
          param.argument :optional
        else
          param.argument false 
        end
      end
      def argument_optional?
        param.argument_optional?
      end

      def required bool = true 
        param.required = bool 
      end
      def required?
        param.required?
      end

      def optional bool = true 
        if bool 
          param.required !bool  
        else
          param.required bool  
        end
      end
      def optional?
        param.optional?
      end

      def cast sym=nil, &b 
        param.cast = sym || b 
      end
      def cast?
        param.cast?
      end

      def validate sym=nil, &b 
        param.validate = sym || b 
      end
      def validate?
        param.validate?
      end

      def description s 
        param.description = s.to_s
      end
      def description?
        param.description?
      end
      alias_method 'desc', 'description'

      def default *values, &block
        if block.nil? and values.empty?
          raise ArgumentError, 'no default'
        end
        unless values.empty?
          param.defaults.push(*values)
        end
        unless block.nil?
          param.defaults.push block
        end
        param.defaults
      end
      alias_method 'defaults', 'default'
      def defaults?
        param.defaults?
      end

      def arity value
        raise Arity if value.nil?
        value = -1 if value.to_s == '*'
        value = Integer value
        raise Arity if value.zero?
        param.arity = value
        if param.arity == -1
          optional true
        end
        value
      end
      def arity?
        param.arity?
      end

      def error which = :instead, &block
        param.send "error_handler_#{ which }=", block
      end
    end

    class Table < ::Array
      def initialize
        super()
        self.fields = []
        extend BoundsCheck
      end

      def to_options
        (hash = self.to_hash ).keys.each { |key| hash[key] = hash[key].value }
        return hash
      end

      module BoundsCheck
        def [] *a, &b
          p = super
        ensure
          raise NoneSuch, a.join(',') unless p 
        end
      end
    end
  end
end
