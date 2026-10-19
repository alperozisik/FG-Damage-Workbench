local panel,plan,zone;
local refreshing=false;
local confirmDelete=false;
local resultMode=false;

function setData(w,p,z,isResult)
  panel=w; plan=p; zone=z; resultMode=isResult==true; refresh();
end
function getPanel() return panel; end
function getZone() return zone; end
function onWheel(notches) if panel then return panel.onWheel(notches); end end
function refreshTypeChoices()
  if not zone or resultMode then return; end
  local wasRefreshing=refreshing; refreshing=true;
  local items={};
  for _,s in ipairs(DWBModel.availableTypes(plan,zone.id,zone.side)) do table.insert(items,s); end
  dtype.setItems(items); dtype.setValue(zone.dtype);
  title.setValue(zone.dtype=="" and "Choose type" or zone.dtype);
  refreshing=wasRefreshing;
end
function refresh()
  if not zone then return; end
  refreshing=true;
  local editing=panel.isEditing() and plan.phase=="edit" and not resultMode;
  title.setValue(zone.dtype=="" and "Choose type" or zone.dtype);
  title.setVisible(not editing); dtype.setVisible(editing); remove.setVisible(editing);
  refreshTypeChoices();
  dice.closeAll();
  if not plan.critical or zone.side=="normal" then
    dice.createWindow().setData(panel,zone,nil,nil,true,zone.modifier,resultMode);
  end
  if resultMode then
    for i,m in ipairs(plan.roll.mapping) do
      if m.zone==zone.id then dice.createWindow().setData(panel,zone,plan.roll.aDice[i],i,false,nil,true); end
    end
  else
    for i,d in ipairs(zone.dice) do dice.createWindow().setData(panel,zone,d,i); end
  end
  total.setVisible(resultMode);
  if resultMode then total.setValue(tostring(DWBModel.total(plan,zone.id))); end
  refreshing=false;
end
function refreshSelection()
  for _,cell in ipairs(dice.getWindows()) do cell.refreshSelection(); end
end
function changeType(value)
  if refreshing or not zone or resultMode or plan.phase~="edit" or not panel.isEditing() then return; end
  if not DWBModel.contains(DWBModel.availableTypes(plan,zone.id,zone.side),value) then return; end
  panel.cancelDelete(); zone.dtype=value; DWBModel.touch(plan);
  -- The native combo finishes hiding its list after onSelect returns. Keep
  -- that control alive instead of destroying it during its own event.
  panel.refreshTypeChoices(); panel.refreshValidation();
end
function deleteZone()
  if not zone or resultMode or not panel.isEditing() then return; end
  panel.cancelDelete(self);
  if confirmDelete then DWBModel.removeZone(plan,zone.id); panel.clearSelection(); panel.refresh();
  else confirmDelete=true; remove.setValue(1); end
end
function cancelDelete() confirmDelete=false; remove.setValue(0); end
function onDrop(x,y,drag)
  if not zone or resultMode then return false; end
  panel.cancelDelete(); return DWB.drop(panel,drag,zone.id);
end
function onClickDown(button)
  if panel then panel.cancelDelete(); end
  return button==2;
end
function onClickRelease(button) return button==2; end
