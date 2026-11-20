class ZCL_ENTITYSETS definition
  public
  final
  create public .

public section.
INTERFACES IF_RAP_QUERY_PROVIDER.
protected section.
private section.
ENDCLASS.



CLASS ZCL_ENTITYSETS IMPLEMENTATION.
  METHOD IF_RAP_QUERY_PROVIDER~SELECT.
  data lt_data type table of zmn_entitysets.
     TRY.
        IF io_request->is_data_requested(  ).

          DATA(lo_filter) = io_request->get_filter(  ).
          DATA(lt_params) = io_request->get_parameters(  ).
          DATA(lt_sort_elements)  = io_request->get_sort_elements(  ).

          DATA(lo_paging) = io_request->get_paging(  ).
          DATA(lv_offset) = lo_paging->get_offset(  ).
          DATA(lv_page_size) = lo_paging->get_page_size(  ).
          DATA(linecounter) = 0.

    DATA(lt_service_bindings) = xco_abap_repository=>objects->srvb->all->in( xco_cp_abap=>repository )->get( ).
    LOOP AT lt_service_bindings ASSIGNING FIELD-SYMBOL(<fs_service_binding>).
      DATA(binding) = <fs_service_binding>->name.
      IF binding(1) <> 'Z'.
        CONTINUE.
      ENDIF.

      "       out->write( |Binding {  binding } | ).
      DATA(lo_service_binding) = xco_abap_repository=>object->srvb->for( binding ).
      " Get a list of all the services of the active version of the service binding using
      " the default origin:
      DATA(lt_services) = lo_service_binding->services->all->get( ).
      LOOP AT lt_services ASSIGNING FIELD-SYMBOL(<fs_service>).
        DATA(Service) = <fs_service>->name.
        DATA(lt_service_versions) = xco_abap_repository=>object->srvb->for( binding )->service( service )->versions->all->get( ).
        LOOP AT lt_service_versions ASSIGNING FIELD-SYMBOL(<fs_serviceversion>).
          DATA(service_content) = <fs_serviceversion>->content( )->get( ).
          DATA(service_name) = service_content-service_definition->name.

          TRY.

              DATA(publishedv2) = xco_service_binding=>local_service_endpoint->odata_v2->is_published(
                                      <fs_serviceversion> ).
            CATCH cx_root.
              CLEAR publishedv2.
          ENDTRY.
          TRY.
              DATA(publishedv4) = xco_service_binding=>local_service_endpoint->odata_v4->is_published(
                                      <fs_service_binding> ).
            CATCH cx_root.
              CLEAR publishedv4.
          ENDTRY.
          " TODO: variable is assigned but never used (ABAP cleaner)
          DATA(lo_srvd) = xco_abap_repository=>object->srvd->for( service_name ).
          DATA(v) = ``.
          IF publishedv2 = abap_true.
            v = 'v2'.
          ENDIF.
          IF publishedv4 = abap_true.
            v = 'v4'.
          ENDIF.
          IF v IS NOT INITIAL.
            DATA(ls_srvd_exposurers) = xco_abap_repository=>object->srvd->for( service_name )->exposures->all->get( ).

            LOOP AT ls_srvd_exposurers ASSIGNING FIELD-SYMBOL(<fs_exposure>).
              DATA(alias) = <fs_exposure>->content( )->get_alias( ).
              DATA(entity) = <fs_exposure>->cds_entity.
              SELECT SINGLE FROM dd02b FIELDS strucobjn_raw WHERE strucobjn = @entity INTO @DATA(camelname).

              DATA(ddls) = xco_abap_repository=>object->ddls->for( entity ).

              DATA(t) = ddls->get_type( ).
              CASE t.
                WHEN xco_data_definition=>type->view_entity.
                  data(params) = xco_cds=>view_entity( entity )->parameters->all->get(  ).
*                WHEN xco_data_definition=>type->projection_view.
*                  params = xco_cds=>projection_view( entity )->parameters->all->get(  ).
                WHEN xco_data_definition=>type->custom_entity.
                  params = xco_cds=>custom_entity( entity )->parameters->all->get(  ).
                when xco_data_definition=>type->table_function.
                  params = xco_cds=>table_function( entity )->parameters->all->get(  ).

                when xco_data_definition=>type->abstract_entity.
                  params = xco_cds=>abstract_entity( entity )->parameters->all->get(  ).

                WHEN OTHERS.

              ENDCASE.
              linecounter += 1.
              data(set) = cond string( when lines( params ) > 0 and v = 'v2' then `Set` else ``).
              data(entityset) = cond string( when alias is not initial then alias else camelname ).
              data(launch_url) = 'javascript:alert("hi")'.
    lt_data = value #( base lt_data ( launch_url = launch_url launch = 'Build ZIP file'  binding = binding service = service odata = v entityset = |{ entityset }{ set }| ) ).
              " Name of the underlying CDS Entity
           "   out->write( | Binding { binding }  Service { service_name } { v } Entity { camelname } Alias { alias } { lines( params ) } | ).
            ENDLOOP.
          ENDIF.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
    sort lt_data.
              io_response->set_data( lt_data ).
          io_response->set_total_number_of_records( lines( lt_data ) ).

    endif.
    catch cx_root.
    endtry.
  ENDMETHOD.
ENDCLASS.
