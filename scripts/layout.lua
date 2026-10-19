CELL = 32;
ZONE_WIDTH = 136;
ZONE_HEIGHT = 222;
RESULT_HEIGHT = 254;
GAP = 10;
GROUP_GAP = 20;

function vertical(p)
  local cardTop=p and p.critical and 32 or 8;
  if not p or p.phase~="results" then
    return {height=520,viewport=264,track=372,cardTop=cardTop};
  end
  local undo=104+cardTop+ZONE_HEIGHT+12;
  local resultHeading=undo+24+12-104;
  local resultTop=resultHeading+(p.critical and 30 or 0);
  local bottom=104+resultTop+RESULT_HEIGHT;
  return {height=bottom+124,viewport=bottom-104,track=bottom+8,
    cardTop=cardTop,undo=undo,resultHeading=resultHeading,resultTop=resultTop};
end

function groups(p, available, editing)
  local groups = p.critical and { {side="critical", label="Critical", zones={}}, {side="normal", label="Non-critical", zones={}} }
    or { {side="normal", label="", zones={}} };
  for _, z in ipairs(p.zones) do
    for _, g in ipairs(groups) do if z.side == g.side then table.insert(g.zones,z); end end
  end
  local extra = editing and 32 or 0;
  local wanted = 0;
  for _, g in ipairs(groups) do
    g.minimum = #g.zones > 0 and ZONE_WIDTH + extra or 106;
    g.width = math.max(g.minimum, #g.zones * (ZONE_WIDTH+GAP) - GAP + extra);
    wanted = wanted + g.width;
  end
  local x=0;
  for _,g in ipairs(groups) do
    g.x=x;
    x=x+g.width+GROUP_GAP;
  end
  local content=math.max(0,x-GROUP_GAP);
  return groups,math.max(0,content-available),content;
end

function selectionSegment(p,z,index,selected)
  if not selected(index) then return nil; end
  local firstFixed=(not p.critical or z.side=="normal") and 1 or 0;
  local slot=index-1+firstFixed;
  local left=slot%3>0 and selected(index-1);
  local right=slot%3<2 and selected(index+1);
  if left and right then return "middle"; elseif left then return "end"; elseif right then return "start"; end
  return "solo";
end
