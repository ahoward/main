    def parameter(*a, &b)
      (parameters << Parameter.create(:parameter, self, *a, &b)).last
    end

    def argument(*a, &b)
      (parameters << Parameter.create(:argument, self, *a, &b)).last
    end
    alias_method 'arg', 'argument'

    def option(*a, &b)
      (parameters << Parameter.create(:option, self, *a, &b)).last
    end
    alias_method 'opt', 'option'
    alias_method 'switch', 'option'

    def keyword(*a, &b)
      (parameters << Parameter.create(:keyword, self, *a, &b)).last
    end
    alias_method 'kw', 'keyword'

    def environment(*a, &b)
      (parameters << Parameter.create(:environment, self, *a, &b)).last
    end
    alias_method 'env', 'environment'

    def default_options!
      option 'help', 'h' unless parameters.has_option?('help', 'h')
    end

    def mode(name, &block)
      name = name.to_s
      modes[name] = block
      block.fattr(:name => name)
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
