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
 binding type char30  as listbox visible length 30 USER-COMMAND b_sel , "DEFAULT 'Z_BINDING_XX',
 "binding type string LOWER CASE,
    service type string default 'Z_SERVICE',
    entity type string LOWER CASE default 'zview_name',
    title type string LOWER CASE default 'My app',
    desc type string LOWER CASE default 'App description',
  "  appname type string DEFAULT 'TEST',
    pa_v2 RADIOBUTTON GROUP  v,
    pa_v4 RADIOBUTTON GROUP v DEFAULT 'X',
    pa_simpl as CHECKBOX.
data: lv_desktop type string,
lv_binding type string,
lv_service type string,
lv_entity type string,
lv_rc type i,
lt_data type STANDARD TABLE OF string.
at SELECTION-SCREEN OUTPUT.
  data gt_list type vrm_values.
  clear gt_list.
  try.
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
                  v = 'v2'.
                ENDIF.
                IF publishedv4 = abap_true.
                  v = 'v4'.
                ENDIF.
                if v is not initial.
                  GT_LIST = value #( base gt_list ( key =  |{ t_binding } - { v } | text = |{ t_binding } - { v } | ) ).
                  endif.
                endloop.
              endloop.

  ENDLOOP.
  catch cx_root INTO data(cx_error).
   data(a) = CX_ERROR->GET_LONGTEXT( ).
   data(b) = 10.
    endtry.
sort GT_LIST.
 call FUNCTION 'VRM_SET_VALUES'

 EXPORTING id = 'BINDING' values = gt_list.

 at SELECTION-SCREEN.
 if sy-ucomm = 'B_SEL'.
  lv_binding = substring_before( val = binding sub = ` ` ).
  data(v) = substring_after( val = BINDING sub = `- ` ).
   data(a) = 1.
   endif.
START-OF-SELECTION.
if appname is initial.
  write: / |Application name required|.
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
data(v) = cond string( when pa_v2 = abap_true then 'V2' else 'V4' ).
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
data(manifest_json) = LO_PROCESS->DOIT( TEMPLATE = |{ v }{ s }_manifest.json|
appname = appname BINDING = lv_binding DESC = desc entity = lv_entity service = lv_service title = title
).
write: / | manifest.json {  lines( MANIFEST_JSON ) } |.
data(component_js) = LO_PROCESS->DOIT( TEMPLATE = |{ v }_Component.js|
appname = appname BINDING = lv_binding DESC = desc entity = lv_entity service = lv_service title = title
).
write: / | component.js {  lines( COMPONENT_JS ) } |.
data(annotation_xml) = LO_PROCESS->doit( template = |{ v }_annotation.xml|
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
write:  / |Files written to { appname } |.
 catch cx_root into data(lx_error).
    write: / |Error  writing files { LX_ERROR->GET_LONGTEXT( ) } |.
    endtry.

endif.
