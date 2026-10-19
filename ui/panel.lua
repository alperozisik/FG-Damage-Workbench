local plan;
local editing = false;
local offset = 0;
local controls = {};
local selected = {};
local selectedZone;
local busy = false;
local refreshing = false;
local previousPhase;
local positions={};
local maxOffset=0;

function onInit()
  -- Native window titles are provided by the XML heading control.
end

function onClose() DWB.panelClosed(plan); end

function getPlan() return plan; end
function isEditing() return editing; end
function setBusy(value) busy = value; refresh(); end

function setPlan(p)
  plan = p; busy = p.phase == "rolling" or p.phase == "rerolling";
  clearSelection();
  if previousPhase ~= p.phase then
    local width = getSize();
    setSize(width, p.phase == "results" and 940 or 590);
    previousPhase = p.phase;
  end
  refresh();
end

function clearSelection() selected = {}; selectedZone = nil; end

function isSelected(zone, index)
  return selectedZone == zone and selected[index] == true;
end

function selection(zone, index)
  if not plan or plan.phase ~= "edit" then return; end
  cancelDelete();
  if selectedZone ~= zone then clearSelection(); selectedZone = zone; end
  selected[index] = not selected[index];
  refreshSelection();
end

function selectedIndices(zone, index)
  local out = {};
  if selectedZone == zone then
    for i, enabled in pairs(selected) do if enabled then table.insert(out, i); end end
  end
  if #out == 0 or not selected[index] then return { index }; end
  table.sort(out); return out;
end

function removeDice(zone, index)
  DWBModel.removeDice(plan, zone, selectedIndices(zone, index)); clearSelection(); refresh();
end

function refreshSelection()
  for _, c in ipairs(controls) do
    if c.subwindow and c.subwindow.refreshSelection then c.subwindow.refreshSelection(); end
  end
end

function refreshTypeChoices()
  for _,c in ipairs(controls) do
    if c.subwindow and c.subwindow.refreshTypeChoices then c.subwindow.refreshTypeChoices(); end
  end
end

function cancelDelete(except)
  for _, c in ipairs(controls) do
    if c.subwindow and c.subwindow.cancelDelete and c.subwindow ~= except then c.subwindow.cancelDelete(); end
  end
end

function toggleEdit()
  if not plan or plan.phase ~= "edit" or busy then return; end
  editing = not editing; cancelDelete(); refresh();
end

function toggleCritical()
  if not plan or busy then return; end
  DWBModel.setCritical(plan, not plan.critical); clearSelection(); offset = 0; refresh();
end

function toggleMagical()
  if not plan or plan.phase ~= "edit" or busy then return; end
  plan.magical = not plan.magical; DWBModel.touch(plan);
  magical.setValue(plan.magical and 1 or 0); cancelDelete();
end

function addZone(side)
  if not plan or plan.phase ~= "edit" or not editing then return; end
  cancelDelete();
  local z = DWBModel.zone(plan, "", side, true);
  if z then DWBModel.touch(plan); offset = 99999; refresh(); end
end

function scrollZones(delta)
  if not plan then return; end
  setScrollOffset(offset+delta);
end

function getScrollOffset() return offset; end
function getZoneControl(id) return viewport.subwindow["zone"..id]; end
function setScrollOffset(value)
  offset=math.max(0,math.min(maxOffset,value));
  for _,p in ipairs(positions) do p.control.setAnchor("left","","left","absolute",p.x-offset); end
  local width=getSize();
  hscroll.configure(width-88,maxOffset,offset);
end

function onWheel(notches)
  scrollZones(-notches*32); return true;
end

function onDrop(x, y, drag)
  cancelDelete(); return DWB.drop(self, drag);
end

function onClickDown(button, x, y)
  cancelDelete(); return button == 2;
end

function onClickRelease(button) return button == 2; end

function onSizeChanged()
  if plan and not refreshing then refresh(); end
end

function refresh()
  if refreshing or not plan then return; end
  refreshing = true;
  DWBModel.sortDice(plan);
  for _, c in ipairs(controls) do c.destroy(); end
  controls = {}; positions={};
  local width,height=getSize();
  local results=plan.phase=="results";
  local canEdit=plan.phase=="edit" and not busy;
  paper.setStaticBounds(18,45,width-36,height-67);
  context.setStaticBounds(44,106,width-88,22);
  viewport.setStaticBounds(44,170,width-88,results and 640 or 270);
  hscroll.setStaticBounds(44,results and 814 or 444,width-88,14);
  critical.setValue(plan.critical and 1 or 0); critical.setEnabled(canEdit);
  edit.setValue(editing and 1 or 0); edit.setEnabled(canEdit);
  magical.setValue(plan.magical and 1 or 0); magical.setEnabled(canEdit);
  context.setValue((plan.actorName and plan.actorName.." / " or "")..plan.label);
  local groups,limit=DWBLayout.groups(plan,width-88,editing and canEdit);
  maxOffset=limit;
  offset=math.min(offset,maxOffset);
  local area=viewport.subwindow;
  area.setPanel(self);
  local function place(c,x,y,w,h)
    c.setAnchor("left","","left","absolute",x-offset); c.setAnchoredWidth(w);
    c.setAnchor("top","","top","absolute",y); c.setAnchoredHeight(h);
    table.insert(positions,{control=c,x=x,y=y,w=w,h=h}); table.insert(controls,c);
  end
  local function caption(name,text,x,y,w)
    local c=area.createControl("dwb_label",name); place(c,x,y,w,22); c.setValue(text);
  end
  for _,g in ipairs(groups) do
    local x=g.x;
    if g.label~="" then
      caption("group_"..g.side,g.label,x+6,10,g.width-12);
      if results then caption("resultgroup_"..g.side,g.label,x+6,340,g.width-12); end
    end
    for j,z in ipairs(g.zones) do
      local zx=x+(j-1)*(DWBLayout.ZONE_WIDTH+DWBLayout.GAP);
      local c=area.createControl("dwb_zonehost","zone"..z.id);
      place(c,zx,40,DWBLayout.ZONE_WIDTH,DWBLayout.ZONE_HEIGHT); c.setValue("dwb_zone","");
      if c.subwindow then c.subwindow.setData(self,plan,z,false); end
      if results then
        local r=area.createControl("dwb_zonehost","result"..z.id);
        place(r,zx,370,DWBLayout.ZONE_WIDTH,DWBLayout.RESULT_HEIGHT); r.setValue("dwb_zone","");
        if r.subwindow then r.subwindow.setData(self,plan,z,true); end
      end
    end
    if editing and canEdit then
      local plus=area.createControl("dwb_add","plus_"..g.side);
      place(plus,x+g.width-26,141,20,20);
      local side=g.side; plus.configure(function() addZone(side); end);
    end
  end
  local ok,err=DWBModel.valid(plan);
  roll.setText(results and "Undo" or "Roll");
  roll.setEnabled(not busy and (results or canEdit and ok));
  local center=math.floor(width/2);
  magical.setStaticBounds(center-70,height-100,140,22); magical.setVisible(not results);
  roll.setStaticBounds(center-70,results and 466 or height-64,140,24);
  save.setStaticBounds(center+116,height-(results and 76 or 64),70,24); save.setVisible(canEdit or results); save.setEnabled(not busy);
  apply.setVisible(results); apply.setEnabled(results and not busy and plan.id~="demo");
  apply.setStaticBounds(center-100,height-76,200,24); apply.setText("Apply "..DWBModel.total(plan).." Damage");
  status.setStaticBounds(44,height-(results and 102 or 126),width-88,22);
  status.setValue(busy and "Working..." or results and "Double-click a result die to reroll. Apply commits these accepted values." or (ok and "Drop dice, damage actions or damage effects." or err));
  hscroll.configure(width-88,maxOffset,offset);
  refreshing=false;
end

function rollOrUndo()
  if not plan or busy then return; end
  cancelDelete(); clearSelection();
  if plan.phase == "results" then
    if plan.id == "demo" then DWBModel.undo(plan); setPlan(plan); else DWB.command(plan.id, "undo"); end
  elseif plan.phase == "edit" and DWBModel.valid(plan) then
    busy = true; refresh();
    if plan.id == "demo" then DWB.demoRoll(plan); else DWB.command(plan.id, "roll", plan); end
  end
end

function applyDamage()
  if not plan or busy or plan.phase ~= "results" or plan.id == "demo" then return; end
  busy = true; refresh(); DWB.command(plan.id, "apply");
end

function savePreset()
  if not plan or busy or (plan.phase ~= "edit" and plan.phase ~= "results") then return; end
  local w = Interface.openWindow("dwb_save", ""); if w then w.setPlan(plan); end
end

function requestReroll(index)
  if not plan or busy or plan.phase ~= "results" then return; end
  local w = Interface.openWindow("dwb_reroll_confirm", "");
  if w then w.setData(self, index, plan.turnRerolls or plan.rerolls or 0); end
end

function confirmReroll(index)
  if not plan or busy then return; end
  if plan.id == "demo" then DWB.tell("Reroll transport is available on a targeted damage action"); return; end
  busy = true; refresh(); DWB.command(plan.id, "reroll", { index = index });
end

function refreshValidation()
  if not plan or plan.phase ~= "edit" then return; end
  local ok, err = DWBModel.valid(plan);
  roll.setEnabled(not busy and ok);
  status.setValue(ok and "Drop dice, damage actions or damage effects." or err);
end
