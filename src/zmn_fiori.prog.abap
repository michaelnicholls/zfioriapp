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
    RETURNING VALUE(content) type xstring..
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
  content = LV_CONTENT.
ENDIF.
*          DATA: lo_http_client TYPE REF TO if_http_client, " if_web_http_client for BTP
*          lv_url         TYPE string,
*          lv_body   TYPE string,
*          lv_response    TYPE string, " comment out got BTP
*          lv_status      TYPE i,
*         " ls_data TYPE ty_wordle,
*          lv_reason      TYPE string.
*     lv_url = 'https://raw.githubusercontent.com/michaelnicholls/zfioriapp/main/' && template.
*     cl_http_client=>create_by_url(
*      EXPORTING
*        url                = lv_url
*      IMPORTING
*        client             = lo_http_client
*      EXCEPTIONS
*        argument_not_found = 1
*        plugin_not_active  = 2
*        internal_error     = 3
*        OTHERS             = 4 ).
*    IF sy-subrc <> 0. RETURN. ENDIF.
*
*
*    lo_http_client->request->set_method( if_http_request=>co_request_method_get ).
*    lo_http_client->send(
*      EXCEPTIONS
*        http_communication_failure = 1
*        http_invalid_state         = 2
*        http_processing_failed     = 3
*
*        OTHERS                     = 4 ).
*    IF sy-subrc <> 0. lo_http_client->close( ). RETURN. ENDIF.
*    lo_http_client->receive(
*"  EXCEPTIONS
*"    http_communication_failure = 1
* "   http_invalid_state         = 2
*
*  "  OTHERS                     = 3
*   ).
*    IF sy-subrc <> 0. lo_http_client->close( ). RETURN. ENDIF.
*
*    lv_response = lo_http_client->response->get_cdata( ).
*    content = LV_RESPONSE.
  write: / 'data received'.
      ENDMETHOD.
      ENDCLASS.
PARAMETERS: pa_bsp type string DEFAULT 'TEST',
    pa_v2 RADIOBUTTON GROUP  v,
    pa_v4 RADIOBUTTON GROUP v DEFAULT 'X',
    pa_simpl as CHECKBOX.
data: lv_desktop type string,

lv_rc type i,
lt_data type STANDARD TABLE OF string.
START-OF-SELECTION.
if pa_bsp is initial.
  write: / |BSP name required|.
else.
  try.
CL_GUI_FRONTEND_SERVICES=>GET_DESKTOP_DIRECTORY(

CHANGING DESKTOP_DIRECTORY = LV_DESKTOP

  ).
cl_gui_cfw=>flush( ).
data lt_folders type table of string.
lt_folders  = value #(
( |{ LV_DESKTOP }\\{ pa_bsp }| )
( |{ LV_DESKTOP }\\{ pa_bsp }\\annotations| )
( |{ LV_DESKTOP }\\{ pa_bsp }\\i18n| )

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
data(index_html) = LO_process->DOIT( TEMPLATE = |index.html| ).
*data(i18n_properties) = LO_PROCESS->DOIT( TEMPLATE = |i18n.properties| ).
*data(manifest_json) = LO_PROCESS->DOIT( TEMPLATE = |{ v }{ s }_manifest.json| ).
*data(component_js) = LO_PROCESS->DOIT( TEMPLATE = |{ v }_Component.js| ).
*data(annotaion_xml) = LO_PROCESS->doit( template = |{ v }_annotation.xml| ).


data(lv_filepath) = LV_FOLDER && '\index.html'.

data(lv_string) = cl_abap_codepage=>convert_from(
                  source   = index_html
                  codepage = 'UTF-8' ).
split lv_string AT cl_abap_char_utilities=>newline into table lt_data.

CL_GUI_FRONTEND_SERVICES=>GUI_DOWNLOAD(
EXPORTING FILENAME = LV_FILEPATH
  FILETYPE = 'ASC'
  CHANGING DATA_TAB = lt_data
"    EXCEPTIONS others = 1
 ) .
write:  / |Files written to { pa_bsp } |.
 catch cx_root into data(lx_error).
    write: / |Error  writing files { LX_ERROR->GET_LONGTEXT( ) } |.
    endtry.

endif.
