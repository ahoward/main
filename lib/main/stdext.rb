class Object
  def singleton_class(object = self, &block)
    singleton_class =
      class << object
        self
      end
    block ? singleton_class.module_eval(&block) : singleton_class
  end
end

module Kernel
private
  undef_method 'abort'
  def abort(message = nil)
    if message
      message = message.to_s
      message.singleton_class{ fattr 'abort' => true }
      STDERR.puts message
    end
    exit 1
  end
end

module Process
  class << Process
    undef_method 'abort'
    def abort(message = nil)
      if message
        message = message.to_s
        message.singleton_class{ fattr 'abort' => true }
        STDERR.puts message
      end
      exit 1
    end
  end
end
