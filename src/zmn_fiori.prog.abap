*&---------------------------------------------------------------------*
*& Report ZMN_FIORI
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ZMN_FIORI.
class lcl_process DEFINITION.
  PUBLIC SECTION.
  methods doit
  IMPORTING template type string
    appname type string
    binding type string
      service type string
      entity type string
      title type string
      desc type string
    RETURNING VALUE(content) type string_table.
  endclass.
  class lcl_process IMPLEMENTATION.
    method doit.
      write: / |Processing { TEMPLATE } |.

      DATA: lv_url     TYPE string VALUE '/SAP/PUBLIC/zz_' ,
      lv_content TYPE xstring,
      lv_mime    TYPE string,
      lo_mr_api  TYPE REF TO if_mr_api.

" 1. Get the MIME Repository API instance
lo_mr_api = cl_mime_repository_api=>get_api( ).

" 2. Read the object content
lo_mr_api->get(
  EXPORTING
    i_url                  = lv_url && template
    i_check_authority      = abap_false " Set to abap_false to bypass folder auth checks
  IMPORTING
    e_content              = lv_content
    e_mime_type            = lv_mime
  EXCEPTIONS
    parameter_missing      = 1
    error_occured          = 2
    not_found              = 3
    permission_failure     = 4
    OTHERS                 = 5 ).

IF sy-subrc = 0.
data(lv_string) = cl_abap_codepage=>convert_from(
                  source   = LV_CONTENT
                  codepage = 'UTF-8' ).
split lv_string AT cl_abap_char_utilities=>newline into table CONTENT.
loop at content ASSIGNING FIELD-SYMBOL(<fs_content>).

  <fs_content> = replace( val = <FS_CONTENT> sub = 'AAAAAA' with = APPNAME ).
  <fs_content> = replace( val = <FS_CONTENT> sub = 'SSSSSS' with = SERVICE ).
    <fs_content> = replace( val = <FS_CONTENT> sub = 'BBBBBB' with = BINDING ).
    <fs_content> = replace( val = <FS_CONTENT> sub = 'VVVVVV' with = entity ).
      <fs_content> =  replace( val = <FS_CONTENT> sub = 'ssssss' with = to_lower( service ) ).
     <fs_content> =   replace( val = <FS_CONTENT> sub = 'bbbbbb' with = to_lower( binding ) ).
     <fs_content> =   replace( val = <FS_CONTENT> sub = 'TTTTTT' with = TITLE ).
    <fs_content> =    replace( val = <FS_CONTENT> sub = 'DDDDDD' with = DESC ).






  endloop.

ENDIF.
      ENDMETHOD.
      ENDCLASS.
PARAMETERS: appname type string LOWER CASE default 'zappname',
binding type char30  as listbox visible length 30  USER-COMMAND b_sel , "DEFAULT 'Z_BINDING_XX',

    entity type char60  as listbox visible length 60 LOWER CASE,
    title type string LOWER CASE default 'My app',
    desc type string LOWER CASE default 'App description',
    pa_simpl as CHECKBOX.

data: lv_desktop type string,
lv_binding type string,
lv_service type string,
lv_entity type string,
lv_version type string,
lv_rc type i,
lt_data type STANDARD TABLE OF string,
lt_entitysets type table of zmn_entitysets.
  data gt_list type vrm_values.
data gt_elist type vrm_values.

AT SELECTION-SCREEN OUTPUT.
  CLEAR gt_list.

  CLEAR gt_elist.

  CLEAR lt_entitysets.
  TRY.
      DATA(lt_service_bindings) = xco_abap_repository=>objects->srvb->all->in( xco_cp_abap=>repository )->get( ).
      LOOP AT lt_service_bindings ASSIGNING FIELD-SYMBOL(<fs_service_binding>).
        DATA(t_binding) = <fs_service_binding>->name.
        IF t_binding(1) <> 'Z' AND t_binding(1) <> 'Y'.
          CONTINUE.
        ENDIF.
        DATA(lo_service_binding) = xco_abap_repository=>object->srvb->for( t_binding ).
        " Get a list of all the services of the active version of the service binding using
        " the default origin:
        DATA(lt_services) = lo_service_binding->services->all->get( ).
        LOOP AT lt_services ASSIGNING FIELD-SYMBOL(<fs_service>).
          DATA(Service) = <fs_service>->name.
          DATA(lt_service_versions) = xco_abap_repository=>object->srvb->for( t_binding )->service( service )->versions->all->get( ).
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
            DATA(v) = ``.
            IF publishedv2 = abap_true.
              v = 'V2'.
            ENDIF.
            IF publishedv4 = abap_true.
              v = 'V4'.
            ENDIF.
            IF v IS INITIAL.
              CONTINUE.
            ENDIF.

            gt_list = VALUE #( BASE gt_list
                               ( key =  |{ t_binding } - { v } | text = |{ t_binding } - { v } | ) ).
            DATA(ls_srvd_exposurers) = xco_abap_repository=>object->srvd->for( service_name )->exposures->all->get( ).

            LOOP AT ls_srvd_exposurers ASSIGNING FIELD-SYMBOL(<fs_exposure>).
              DATA(alias) = <fs_exposure>->content( )->get_alias( ).
              DATA(entity) = <fs_exposure>->cds_entity.
              SELECT SINGLE FROM dd02b FIELDS strucobjn_raw WHERE strucobjn = @entity INTO @DATA(camelname).

              DATA(ddls) = xco_abap_repository=>object->ddls->for( entity ).

              DATA(t) = ddls->get_type( ).
              CASE t.
                WHEN xco_data_definition=>type->view_entity.
                  " TODO: variable is assigned but never used (ABAP cleaner)
                  DATA(desc) = xco_cds=>view_entity( entity )->content( )->get_short_description( ).
                  DATA(params) = xco_cds=>view_entity( entity )->parameters->all->get( ).
                WHEN xco_data_definition=>type->projection_view.
                  desc = xco_cds=>projection_view( entity )->content( )->get_short_description( ).
*                  params = xco_cds=>projection_view( entity )->parameters->all->get(  ).
                WHEN xco_data_definition=>type->custom_entity.
                  desc = xco_cds=>custom_entity( entity )->content( )->get_short_description( ).
                  params = xco_cds=>custom_entity( entity )->parameters->all->get( ).
                WHEN xco_data_definition=>type->table_function.
                  desc = xco_cds=>table_function( entity )->content( )->get_short_description( ).
                  params = xco_cds=>table_function( entity )->parameters->all->get( ).

                WHEN xco_data_definition=>type->abstract_entity.
                  desc = xco_cds=>abstract_entity( entity )->content( )->get_short_description( ).
                  params = xco_cds=>abstract_entity( entity )->parameters->all->get( ).

                WHEN OTHERS.
                  desc = 'unknown'.
              ENDCASE.
              DATA(set) = COND string( WHEN lines( params ) > 0 AND v = 'V2' THEN `Set` ELSE `` ).
              DATA(entityset) = COND string( WHEN alias IS NOT INITIAL THEN alias ELSE camelname ).
*                  DATA(prompt) = |bsp=prompt("BSP app name","{ binding }_BSP");|.
*                  DATA(url) = |https://michaelnicholls.github.io/simpleFiori/makeZip.html?b={ binding }&s={ service }&e={ entityset }{ set }&v={ v }&d={ desc }| &&
*                   |&i={ to_lower( lv_protocol ) }://{ lv_host }:{ lv_port }&c={ sy-mandt }&bsp=|.
*                  DATA(launch_url) = |javascript:{ prompt }window.open("{ url }"+bsp,"mypopup","popup,width=1000,height=450")|.
              LT_ENTItysets = VALUE #( BASE LT_Entitysets
                                       ( binding   = t_binding
                                         service   = service
                                         odata     = v
                                         entityset = |{ entityset }{ set }| ) ).
              "            ENDLOOP.
            ENDLOOP.
          ENDLOOP.
        ENDLOOP.

      ENDLOOP.
    CATCH cx_root INTO DATA(cx_error).
      " TODO: variable is assigned but never used (ABAP cleaner)
      DATA(a) = cx_error->get_longtext( ).
      " TODO: variable is assigned but never used (ABAP cleaner)
      DATA(b) = 10.
  ENDTRY.
  SORT gt_list.
  CALL FUNCTION 'VRM_SET_VALUES'

    EXPORTING id     = 'BINDING'
              values = gt_list.

 at SELECTION-SCREEN.
  lv_binding = substring_before( val = binding sub = ` ` ).
  lv_version = substring_after( val = BINDING sub = `- ` ).
 if sy-ucomm = 'B_SEL'.
  clear entity.


  clear gt_elist.
   loop at LT_ENTITYSETS into data(lv_entityset) where binding = lv_binding.
     gt_elist = value #( base gt_elist (
     key = |{ lv_entityset-service }/{ LV_ENTITYSET-entityset }|
      text = |{ lv_entityset-service }/{ LV_ENTITYSET-entityset } | ) ).
     endloop.
     call FUNCTION 'VRM_SET_VALUES'

 EXPORTING id = 'ENTITY' values = gt_elist.

   data(a) = 1.
   endif.
START-OF-SELECTION.
lv_entity = substring_before( val = entity sub = `/` ).
lv_service = substring_after( val = ENTITY sub = `/` ).
if appname is initial or binding is initial or lv_service is initial.
  write: / |Application name, binding, service, and entity set are required|.
else.
  try.
CL_GUI_FRONTEND_SERVICES=>GET_DESKTOP_DIRECTORY(

CHANGING DESKTOP_DIRECTORY = LV_DESKTOP

  ).
cl_gui_cfw=>flush( ).
data lt_folders type table of string.
lt_folders  = value #(
( |{ LV_DESKTOP }\\{ appname }| )
( |{ LV_DESKTOP }\\{ appname }\\annotations| )
( |{ LV_DESKTOP }\\{ appname }\\i18n| )

).
loop at lt_folders into data(lv_folder).
CL_GUI_FRONTEND_SERVICES=>DIRECTORY_CREATE(
EXPORTING DIRECTORY = lv_folder
  CHANGING rc = lv_rc
    EXCEPTIONS DIRECTORY_ALREADY_EXISTS = 1
      OTHERS = 2
    ).
endloop.
"data(v) = cond string( when pa_v2 = abap_true then 'V2' else 'V4' ).
data(s) = cond string( when PA_SIMPL = abap_true then 'S' else '' ).
data(lo_process) = new lcl_process( ).
data(index_html) = LO_process->DOIT( TEMPLATE = |index.html|
appname = appname BINDING = lv_binding DESC = desc entity = lv_entity service = lv_service title = title
  ).
write: / | index.html {  lines( index_html ) } |.
data(i18n_properties) = LO_PROCESS->DOIT( TEMPLATE = |i18n.properties|
appname = appname BINDING = lv_binding DESC = desc entity = lv_entity service = lv_service title = title
 ).
write: / | i18n.properties {  lines( I18N_PROPERTIES ) } |.
data(manifest_json) = LO_PROCESS->DOIT( TEMPLATE = |{ lv_version }{ s }_manifest.json|
appname = appname BINDING = lv_binding DESC = desc entity = lv_entity service = lv_service title = title
).
write: / | manifest.json {  lines( MANIFEST_JSON ) } |.
data(component_js) = LO_PROCESS->DOIT( TEMPLATE = |{ lv_version }_Component.js|
appname = appname BINDING = lv_binding DESC = desc entity = lv_entity service = lv_service title = title
).
write: / | component.js {  lines( COMPONENT_JS ) } |.
data(annotation_xml) = LO_PROCESS->doit( template = |{ lv_version }_annotation.xml|
appname = appname BINDING = lv_binding DESC = desc entity = lv_entity service = lv_service title = title
 ).
write: / | annotation.xml {  lines( ANNOTAtION_XML ) } |.


data(lv_filepath) = LV_FOLDER && '\index.html'.


CL_GUI_FRONTEND_SERVICES=>GUI_DOWNLOAD(
EXPORTING FILENAME = |{ lv_desktop }\\{ appname }\\index.html|
  FILETYPE = 'ASC'
  CHANGING DATA_TAB = INDEX_HTML
 ) .
CL_GUI_FRONTEND_SERVICES=>GUI_DOWNLOAD(
EXPORTING FILENAME = |{ lv_desktop }\\{ appname }\\i18n\\i18n.propertites|
  FILETYPE = 'ASC'
  CHANGING DATA_TAB = I18N_PROPERTIES
 ) .
CL_GUI_FRONTEND_SERVICES=>GUI_DOWNLOAD(
EXPORTING FILENAME = |{ lv_desktop }\\{ appname }\\manifest.json|
  FILETYPE = 'ASC'
  CHANGING DATA_TAB = MANIFEST_JSON
 ) .
CL_GUI_FRONTEND_SERVICES=>GUI_DOWNLOAD(
EXPORTING FILENAME = |{ lv_desktop }\\{ appname }\\Component.js|
  FILETYPE = 'ASC'
  CHANGING DATA_TAB = COMPONENT_JS
 ) .
CL_GUI_FRONTEND_SERVICES=>GUI_DOWNLOAD(
EXPORTING FILENAME = |{ lv_desktop }\\{ appname }\\annotations\\annotation.xml|
  FILETYPE = 'ASC'
  CHANGING DATA_TAB = ANNOTATION_XML
 ) .
  uline.
data(sa38) = 'SA38'.
data(catalog) = 'Technical catalog'.
data(pfcg) = 'PFCG'.
write:  / |Files written to the { appname } folder on your Desktop |.
  write : / |You can now use |.
  write :  sa38 HOTSPOT on COLOR COL_POSITIVE.
  write: | to run /UI5/UI5_REPOSITORY_LOAD to upload a Fiori BSP app from that folder |.
  write: / |You then need to add the app to a |.
  write: catalog hotspot on color col_positive.
   write: / |And add the technical catalog to a role using |.
  write: pfcg hotspot on color col_positive.
 catch cx_root into data(lx_error).
    write: / |Error  writing files { LX_ERROR->GET_LONGTEXT( ) } |.
    endtry.

endif.
AT LINE-SELECTION.
  DATA lv_fieldname TYPE string.

  GET CURSOR FIELD lv_fieldname.
  IF lv_fieldname = 'CATALOG'.

   call transaction '/UI2/FLPAM'.

  ENDIF.
 IF lv_fieldname = 'PFCG'.

   call transaction 'PFCG'.

  ENDIF.

  IF lv_fieldname = 'SA38'.
    DATA(bsp) = |{ appname }_bsp|.
    SUBMIT /ui5/ui5_repository_load WITH ui5rep = bsp VIA SELECTION-SCREEN.
  ENDIF.
