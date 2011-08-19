module Tcl
  class Interp
    include InterpHelper
    
    def self.load_from_file(filenames)
      # Static factory method. Returns instance of Tcl::Interp.
      content = InterpHelper::file_content filenames
      interp = new
      interp.eval content
      interp
    end
    
    def load_from_file(filenames)
      # Operates on existing instance of Tcl::Interp
      content = InterpHelper::file_content filenames
      interp.eval content
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
    
    def stub_proc(params)
      # Creates a simple proc for use as a test stub
      name = params[:name] || ""
      args = params[:args] || ""
      body = params[:body] || ""
      interp.eval "proc #{name} { #{args} } { #{body} }"
      proc name
    end
    
    def stub_var(params)
      # Creates a simple var for use as a test stub
      name = params[:name]
      value = params[:value] || ""
      if value.is_a?(String)
        interp.eval "set #{name} \"#{value}\""
      else
        interp.eval "set #{name} #{value}"
      end
      var name
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
