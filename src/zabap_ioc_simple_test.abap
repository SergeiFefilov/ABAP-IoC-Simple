report zabap_ioc_simple_test.

class lcx_ioc_base definition inheriting from cx_static_check.
endclass.

class lcx_interface_required definition inheriting from lcx_ioc_base.
endclass.

class lcx_impl_is_not_registered definition inheriting from lcx_ioc_base.
endclass.

class lcx_impl_already_initialized definition inheriting from lcx_ioc_base.
endclass.

class lcx_impl_already_registered definition inheriting from lcx_ioc_base.
endclass.

interface lif_ioc_container.
  methods:
    register importing io_implementation type ref to object
             raising   lcx_ioc_base,

    resolve exporting eo_implementation type any
            raising   lcx_ioc_base.
endinterface.

* simple implementation
* different instances with shared interface implementation are not allowed
* e.g. one interface must be tightly coupled with only one implementation
class lcl_ioc_container definition.
  public section.
    interfaces:
      lif_ioc_container.

  private section.
    types:
      begin of ts_instance,
        interface  type abap_compname,
        o_instance type ref to object,
      end of ts_instance,

      tt_instance type hashed table of ts_instance with unique key interface.

    methods:
      resolve_interface exporting eo_object     type any
                        returning value(r_type) type string
                        raising   lcx_interface_required,

      check_interface importing i_interface        type abap_compname
                      returning value(r_interface) type abap_compname
                      raising   lcx_impl_already_registered.

    data:
      mt_instance type tt_instance.
endclass.

class lcl_bad_type definition.
endclass.

class lcl_ioc_container implementation.

  method lif_ioc_container~register.
    data lo_desc type ref to cl_abap_objectdescr.
    lo_desc ?= cl_abap_objectdescr=>describe_by_object_ref( io_implementation ).

    if lo_desc->interfaces is initial.
      raise exception type lcx_interface_required.
    endif.

    insert lines of value tt_instance( for <ls_int> in lo_desc->interfaces
      ( interface = check_interface( <ls_int>-name ) o_instance = io_implementation ) )
      into table mt_instance.
    assert sy-subrc = 0.
  endmethod.

  method lif_ioc_container~resolve.
    if eo_implementation is not initial.
      raise exception type lcx_impl_already_initialized.
    endif.

    eo_implementation ?= value #( mt_instance[
      interface = resolve_interface( importing eo_object = eo_implementation ) ]-o_instance optional ).

    if eo_implementation is initial.
      raise exception type lcx_impl_is_not_registered.
    endif.
  endmethod.

  method resolve_interface.
    data: l_dummy type string,
          l_type  type string.

    assert eo_object is initial.

    try.
        eo_object ?= new lcl_bad_type( ).
      catch cx_sy_move_cast_error into data(lx_mce).
        l_type = lx_mce->target_typename.
    endtry.

    clear eo_object.

    split l_type at '\INTERFACE=' into l_dummy r_type.

    if r_type is initial.
      raise exception type lcx_interface_required.
    endif.
  endmethod.

  method check_interface.
    if line_exists( mt_instance[ interface = i_interface ] ).
      raise exception type lcx_impl_already_registered.
    endif.

    r_interface = i_interface.
  endmethod.

endclass.

class lcl_test_impl definition.
  public section.
    interfaces: if_workflow.
endclass.

class lcl_test_impl implementation.

  METHOD bi_persistent~find_by_lpor.

  ENDMETHOD.

  METHOD bi_persistent~lpor.

  ENDMETHOD.

  METHOD bi_persistent~refresh.

  ENDMETHOD.

  METHOD bi_object~default_attribute_value.

  ENDMETHOD.

  METHOD bi_object~execute_default_method.

  ENDMETHOD.

  METHOD bi_object~release.

  ENDMETHOD.

endclass.

end-of-selection.
  try.

*     firstly create and register all dependencies in some context before
      data(lo_ioc_container) = new lcl_ioc_container( ).
      lo_ioc_container->lif_ioc_container~register( new lcl_test_impl( ) ).

*     somewhere else in code (a way how to discover IoC containers depends on the implementation)
      data lo_tst type ref to if_workflow.
      lo_ioc_container->lif_ioc_container~resolve( importing eo_implementation = lo_tst ).

      write: / 'resolved as:', cl_abap_objectdescr=>describe_by_object_ref( lo_tst )->get_relative_name( ).

    catch cx_root into data(lx_root).
      write: / cl_abap_objectdescr=>describe_by_object_ref( lx_root )->get_relative_name( ), lx_root->get_text( ).
  endtry.