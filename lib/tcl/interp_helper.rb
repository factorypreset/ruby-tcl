module Tcl
  module InterpHelper
    def self.included(klass)
      klass.class_eval do
        attr_reader :interp
      end
    end
    
    def _(*args)
      interp.array_to_list(args)
    end
    
    def _!(*args)
      interp.eval(_(*args))
    end
    
    def self.file_content(filenames)
      content = ""
      if not filenames.is_a?(Array)
          filenames = Array(filenames)
      end
      filenames.each do |filename|
          content += IO.read(filename) + "\n"
      end
      content
    end
    
    def method_missing(name, *args, &block)
      if interp.respond_to?(name)
        interp.send(name, *args, &block)
      else
        super
      end
    end
    
  end
end
