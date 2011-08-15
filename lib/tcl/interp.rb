module Tcl
  class Interp
    include InterpHelper
    
    class << self
      def load_from_file(filenames)
        file_content = ""
        if not filenames.kind_of?(Array)
            filenames = Array(filenames)
        end
        filenames.each do |filename|
            file_content += IO.read(filename) + "\n"
        end
        interp = new
        interp.eval(file_content)
        interp
      end
    end
    
    def interp
      self
    end
    
    def interp_receive(method, *args)
      send("tcl_#{method}", *args)
    end
  
    def expose(name)
      _!(:interp, :alias, nil, name, nil, :interp_send, name)
    end

    def proc(name)
      Tcl::Proc.new(self, name)
    end
    
    def var(name)
      Tcl::Var.find(self, name)
    end

    def procs
      list_to_array _!(:info, :procs)
    end
    
    def vars
      list_to_array _!(:info, :vars)
    end
    
    def to_tcl
      %w( var proc ).inject([]) do |lines, type|
        send("#{type}s").sort.each do |name|
          object = send(type, name)
          lines << object.to_tcl unless object.builtin?
        end
        lines
      end.join("\n")
    end
  end
end
