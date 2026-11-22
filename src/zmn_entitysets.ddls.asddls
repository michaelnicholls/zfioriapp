@EndUserText.label: 'Customer entitysets'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_ENTITYSETS'
define custom entity zmn_entitysets

{
  @UI.lineItem: [{ position: 10 }]
 key binding : abap.char(40);
  @UI.lineItem: [{ position: 20 }]
 
 key service : abap.char(30);
  @UI.lineItem: [{ position: 30 }]
 key  entityset : abap.char(30);
  @UI.lineItem: [{ position: 40 }]
  odata: abap.char(2);
  launch_url: abap.char(300);
  @UI.lineItem: [{ position: 50, type: #WITH_URL, url: 'launch_url' }]
  launch : abap.char(30);
  
}
