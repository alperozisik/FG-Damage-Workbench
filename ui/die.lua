local panel, zone, die, index;
local result = false;
local fixedValue = false;
local updating = false;

function onWheel(notches) if panel then return panel.onWheel(notches); end end

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
    if not result and panel.getPlan().phase == "edit" then registerDieMenu(); end
    local s = DWBModel.dieType(d);
    local isCrit = result and (d.type or ""):match("^g") ~= nil;
    local auto=(d.nReroll or 0)>0;
    local icon = s .. (isCrit and "g" or auto and "r" or "") .. "icon";
    local widget = face.addBitmapWidget({ icon = icon, position = "center", w = 28, h = 28 });
    local valueText = result and tostring(d.value or d.result or 0) or s:sub(2);
    face.addTextWidget({ font = "sheetlabel", text = valueText, position = "center" });
    face.setTooltipText(s .. (auto and (" — auto reroll <= "..d.nReroll..(d.bRerollNoLimit and " (repeat)" or " (once)")) or "") .. (d.feature and " / " .. d.feature or "") .. (result and " — double-click to reroll" or ""));
    if result and d.rolls then
      local values={};for _,attempt in ipairs(d.rolls) do table.insert(values,tostring(attempt.value or attempt.result)..(attempt.dropped and " (discarded)" or ""));end
      face.setTooltipText(s.." — "..table.concat(values," → ").." — double-click to reroll");
    end
    if widget and (d.iconcolor or d.dicebodycolor) and not isCrit then widget.setColor(d.iconcolor or d.dicebodycolor); end
    if d.backcolor then face.setBackColor(d.backcolor); end
  end
  updating = false; refreshSelection();
end

function registerDieMenu()
  face.resetMenuItems();
  local sides=tonumber(DWBModel.dieType(die):sub(2));
  if sides>20 then face.registerMenuItem("Delete dice","delete",6);return; end
  face.registerMenuItem("Reroll if lower or equal than","shuffle",7);
  face.registerMenuItem("No auto reroll",(die.nReroll or 0)==0 and "button_checkon" or "button_checkoff",7,8);
  if sides<=8 then
    for n=1,sides-1 do face.registerMenuItem(tostring(n),die.nReroll==n and "button_checkon" or "button_checkoff",7,8-n); end
  else
    -- FG context menus have eight slots per level.
    for first=1,sides-1,7 do
      local group=7-math.floor((first-1)/7);
      face.registerMenuItem(first.."–"..math.min(first+6,sides-1),"radial_plus",7,group);
      for n=first,math.min(first+6,sides-1) do
        face.registerMenuItem(tostring(n),die.nReroll==n and "button_checkon" or "button_checkoff",7,group,8-(n-first));
      end
    end
  end
  face.registerMenuItem("Delete dice","delete",6);
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

function menuSelection(selection,sub,leaf)
  if not panel or result or fixedValue or panel.getPlan().phase ~= "edit" then return; end
  panel.cancelDelete();
  if selection==6 then panel.removeDice(zone.id,index);
  elseif selection==7 and sub then
    local sides=tonumber(DWBModel.dieType(die):sub(2));
    local threshold=sub==8 and 0 or (sides<=8 and 8-sub or leaf and (7-sub)*7+9-leaf);
    if threshold then panel.setAutoReroll(zone.id,index,threshold); end
  end
end

-- Retained for native harness/backward compatibility.
function deleteFromMenu(selection) menuSelection(selection); end

function drag(draginfo)
  if not panel or result or fixedValue or panel.getPlan().phase ~= "edit" then return true; end
  draginfo.setType("dwbmove");
  draginfo.setStringData(Utility.encodeJSON({ id = panel.getPlan().id, zone = zone.id,
    indices = panel.selectedIndices(zone.id, index) }));
  draginfo.setDescription("Move damage dice"); draginfo.setIcon("action_damage");
  return true;
end
