local panel, zone, die, index;
local result = false;
local fixedValue = false;
local updating = false;

function onDrop(x, y, draginfo)
  if not panel or not zone then return false; end
  panel.cancelDelete(); return DWB.drop(panel, draginfo, zone.id);
end

function setData(w, z, d, i, isFixed, value, isResult)
  panel = w; zone = z; die = d; index = i; result = isResult == true; fixedValue = isFixed == true;
  updating = true;
  if fixedValue then
    face.setVisible(false); fixed.setVisible(true); fixed.setValue(value or 0);
    fixed.setReadOnly(result or panel.getPlan().phase ~= "edit");
  else
    fixed.setVisible(false); face.setVisible(true);
    if not result and panel.getPlan().phase == "edit" then
      face.registerMenuItem("Delete dice", "delete", 6);
    end
    local s = DWBModel.dieType(d);
    local isCrit = result and (d.type or ""):match("^g") ~= nil;
    local icon = s .. (isCrit and "g" or "") .. "icon";
    local widget = face.addBitmapWidget({ icon = icon, position = "center", w = 28, h = 28 });
    local valueText = result and tostring(d.value or d.result or 0) or s:sub(2);
    face.addTextWidget({ font = "sheetlabel", text = valueText, position = "center" });
    face.setTooltipText(s .. (d.feature and " / " .. d.feature or "") .. (result and " — double-click to reroll" or ""));
    if widget and d.dicebodycolor and not isCrit then widget.setColor(d.dicebodycolor); end
  end
  updating = false; refreshSelection();
end

function refreshSelection()
  if fixedValue or not panel then return; end
  local segment = not result and DWBLayout.selectionSegment(panel.getPlan(),zone,index,function(i) return panel.isSelected(zone.id,i); end);
  highlight.setVisible(segment~=nil and segment~=false);
  if segment then highlight.setIcon("dwb_selection_"..segment); end
end

function fixedChanged()
  if updating or not fixedValue or result or not zone or panel.getPlan().phase ~= "edit" then return; end
  zone.modifier = fixed.getValue(); DWBModel.touch(panel.getPlan());
  panel.cancelDelete();
  panel.refreshValidation();
end

function click(button)
  if not panel or result then return true; end
  panel.cancelDelete();
  if button == 1 then
    if Input.isControlPressed() then panel.removeDice(zone.id,index);
    else panel.selection(zone.id, index); end
  end
  return true;
end

function doubleClick()
  if result and not fixedValue then panel.requestReroll(index); end
  return true;
end

function release(button)
  return true;
end

function deleteFromMenu(selection)
  if selection ~= 6 or not panel or result or fixedValue or panel.getPlan().phase ~= "edit" then return; end
  panel.cancelDelete();
  panel.removeDice(zone.id, index);
end

function drag(draginfo)
  if not panel or result or fixedValue or panel.getPlan().phase ~= "edit" then return true; end
  draginfo.setType("dwbmove");
  draginfo.setStringData(Utility.encodeJSON({ id = panel.getPlan().id, zone = zone.id,
    indices = panel.selectedIndices(zone.id, index) }));
  draginfo.setDescription("Move damage dice"); draginfo.setIcon("action_damage");
  return true;
end
