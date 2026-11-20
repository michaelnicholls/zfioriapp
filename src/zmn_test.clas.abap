class ZMN_TEST definition
  public
  final
  create public .

public section.
INTERFACES if_oo_adt_classrun.
protected section.
private section.
ENDCLASS.



CLASS ZMN_TEST IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA(lt_service_bindings) = xco_abap_repository=>objects->srvb->all->in( xco_cp_abap=>repository )->get( ).
    LOOP AT lt_service_bindings ASSIGNING FIELD-SYMBOL(<fs_service_binding>).
      DATA(binding) = <fs_service_binding>->name.
      IF binding(1) = 'Z'.
 "       out->write( |Binding {  binding } | ).
        DATA(lo_service_binding) = xco_abap_repository=>object->srvb->for( binding ).
        " Get a list of all the services of the active version of the service binding using
        " the default origin:
        DATA(lt_services) = lo_service_binding->services->all->get( ).
        LOOP AT lt_services ASSIGNING FIELD-SYMBOL(<fs_service>).
        data(Service) = <fs_service>->name.
 "         out->write( |Service {  service } | ).
          data(lt_service_versions) = xco_abap_repository=>object->srvb->for( binding )->service( service )->versions->all->get(  ).
 " DATA(lo_srvd) = xco_abap_repository=>object->srvd->for(  ).
          loop at lt_service_versions assigning field-symbol(<fs_serviceversion>).
          data(service_content) = <fs_serviceversion>->content(  )->get( ).
          data(service_name) = service_content-service_definition->name.

            try.

            data(publishedv2) = xco_service_binding=>local_service_endpoint->odata_v2->is_published( <fs_serviceversion> ).
            catch cx_root. clear publishedv2. endtry.
            try.
            data(publishedv4) = xco_service_binding=>local_service_endpoint->odata_v4->is_published( <fs_service_binding> ).
            catch cx_root. clear publishedv4. endtry.
          DATA(lo_srvd) = xco_abap_repository=>object->srvd->for( service_name ).
            data(v) = ``.
            if publishedv2 = abap_true. v = 'v2'. endif.
            if publishedv4 = abap_true. v = 'v4'. endif.
            if v is not initial.
          DATA(ls_srvd_exposurers) = xco_abap_repository=>object->srvd->for( service_name )->exposures->all->get( ).
                   out->write( | Binding { binding }  Service { service_name } { v }| ).

          LOOP AT ls_srvd_exposurers assigning field-symbol(<fs_exposure>).
            data(alias) = <fs_exposure>->content(  )->get_alias(  ).
            data(entity) = <fs_exposure>->cds_entity.

            data(stob) = xco_abap_repository=>object->stob->for( 'ZMN_CALC' )->get_data_definition( )."abap_repository=>object->stob->for( 'ZMN_CALC' )->get_data_definition(  ).

            data(b) = 1.
                " Name of the underlying CDS Entity
                out->write( |     Entity { entity } Alias { alias } | ).
        endloop.
        endif.
        data(a) = 1.
          endloop.
        ENDLOOP.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
