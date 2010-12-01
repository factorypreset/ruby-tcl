require 'rubygems'
require 'ffi'

module Tcl
  
  module TclLib
    extend ::FFI::Library

    ffi_lib 'tcl'

    callback :tcl_obj_cmd_proc, [:pointer, :pointer, :int, :pointer], :int
    callback :tcl_cmd_delete_proc, [:pointer], :void
    callback :tcl_free_proc, [:string], :void

    attach_function :Tcl_CreateInterp, [], :pointer
    attach_function :Tcl_CreateObjCommand, [:pointer, :string, :tcl_obj_cmd_proc, :pointer, :tcl_cmd_delete_proc], :pointer
    attach_function :Tcl_Eval, [:pointer, :string], :int
    attach_function :Tcl_GetStringFromObj, [:pointer, :pointer], :pointer
    attach_function :Tcl_Init, [:pointer], :void
    attach_function :Tcl_MakeSafe, [:pointer], :void
    attach_function :Tcl_NewObj, [], :pointer
    attach_function :Tcl_NewStringObj, [:string, :int], :pointer
    attach_function :Tcl_Preserve, [:pointer], :void
    attach_function :Tcl_SetResult, [:pointer, :string, :tcl_free_proc], :void
    attach_function :Tcl_ListObjGetElements, [:pointer, :pointer, :pointer, :pointer], :int
    attach_function :Tcl_ListObjAppendElement, [:pointer, :pointer, :pointer], :void
  
    TCL_OK = 0
    TCL_ERROR = 1

    class Tcl_Interp_Struct < ::FFI::Struct
      layout :result, :string,
             :freeProc, :tcl_free_proc,
             :errorLine, :int
    end
  
    class TwoPtrValue_Struct < ::FFI::Struct
      layout :ptr1, :pointer,
             :ptr2, :pointer
    end

    class PtrAndLongRep_Struct < ::FFI::Struct
      layout :ptr, :pointer,
             :value, :ulong
    end

    class InternalRep_Union < ::FFI::Union
      layout :longValue, :long,
             :doubleValue, :double,
             :otherValuePtr, :pointer,
             :wideValue, :long, # Tcl_WideInt
             :twoPtrValue, TwoPtrValue_Struct,
             :ptrAndLongRep, PtrAndLongRep_Struct
    end

    class Tcl_Obj_Struct < ::FFI::Struct
       layout :refCount, :int,
              :bytes, :string,
              :length, :int,
              :typePtr, :pointer,
              :internalRep, InternalRep_Union
    end
    
    def incr_ref_count(tcl_obj)
      (Tcl_Obj_Struct.new(tcl_obj))[:refCount] += 1
    end
    module_function :incr_ref_count
    
    def decr_ref_count(tcl_obj)
      (Tcl_Obj_Struct.new(tcl_obj))[:refCount] -= 1
    end
    module_function :decr_ref_count
    
    def with_tcl_obj(tcl_obj, &block)
      incr_ref_count(tcl_obj)
      yield(tcl_obj)
      decr_ref_count(tcl_obj)
    end
    module_function :with_tcl_obj
  end

  class Interp
    def initialize
      @interp = TclLib.Tcl_CreateInterp
      @exit_exception = nil

      TclLib.Tcl_Init(@interp)
      TclLib.Tcl_Preserve(@interp)
      
      TclLib.Tcl_CreateObjCommand(@interp, 'interp_send', method(:interp_send), @interp, nil)
    end
    
    def eval(script)
      case TclLib.Tcl_Eval(@interp, script)
      when TclLib::TCL_OK
        interp_result
      when TclLib::TCL_ERROR
        raise Error.new(interp_result) if @exit_exception.nil?
        exit(@exit_exception.status)
      else
        # TODO:
        nil
      end
    end

    def list_to_array(list)
      list_string = TclLib.Tcl_NewStringObj(list.to_s, -1)
      TclLib.incr_ref_count(list_string)

      elements_length = ::FFI::MemoryPointer.new(:int)
      elements = ::FFI::MemoryPointer.new(:pointer)
      if TclLib.Tcl_ListObjGetElements(@interp, list_string, elements_length, elements) != TclLib::TCL_OK
        TclLib.decr_ref_count(list_string)
        return nil
      end

      result = []
      elements_ptr = elements.get_pointer(0)
      if ! elements_ptr.null?
        elements_ptr.get_array_of_pointer(0, elements_length.get_int(0)).each do |element|
          element_length = ::FFI::MemoryPointer.new(:int)
          element_string = TclLib.Tcl_GetStringFromObj(element, element_length)
          result << element_string.get_string(0) unless element.null?
          TclLib.decr_ref_count(element)
        end
      end
      TclLib.decr_ref_count(list_string)
      result
    end

    def array_to_list(array)
      result = nil
      TclLib.with_tcl_obj(TclLib.Tcl_NewObj) do |list|
        array.each do |element|
          TclLib.with_tcl_obj(TclLib.Tcl_NewStringObj(element.to_s, -1)) do |string|
            TclLib.Tcl_ListObjAppendElement(@interp, list, string)
          end
        end
        result = TclLib.Tcl_GetStringFromObj(list, nil).get_string(0)
      end
      result
    end
      
    private

    def interp_send(client_data, interp, objc, objv)
      _objv = objv.get_array_of_pointer(0, objc)
      interp_receive_args = []
      (1...objc).each do |i|
        element_length = ::FFI::MemoryPointer.new(:int)
        element = TclLib.Tcl_GetStringFromObj(_objv[i], element_length)
        interp_receive_args.push(element.get_string(0))
      end

      begin
        res = interp_receive(*interp_receive_args)
        set_interp_result(res.to_s)
        TclLib::TCL_OK
      rescue Exception => e
        set_interp_result(e.message)
        @exit_exception = e if e.kind_of?(SystemExit)
        TclLib::TCL_ERROR
      end
    end

    def interp_result
      (TclLib::Tcl_Interp_Struct.new(@interp))[:result]
    end
    
    def set_interp_result(res)
      TclLib.Tcl_SetResult(@interp, res, nil) 
    end
  end

  class SafeInterp < Interp
    def initialize
      super
      TclLib.Tcl_MakeSafe(@interp)
    end
  end

  class Error < ::StandardError
  end
end

require 'tcl/interp_helper'
require 'tcl/interp'
require 'tcl/proc'
require 'tcl/var'