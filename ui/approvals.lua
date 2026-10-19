function onInit() refresh(); end
function onSizeChanged()
  local width, height = getSize(); paper.setStaticBounds(18,45,width-36,height-64);
  help.setStaticBounds(44,66,width-88,48);
  list.setStaticBounds(44,126,width-88,height-150);
end
function refresh()
  if not Session.IsHost then close(); return; end
  local requests=DWB.approvals();
  local width=getSize(); setSize(width,math.min(630,150+math.max(1,#requests)*80));
  onSizeChanged();
  list.closeAll();
  for _, ctx in ipairs(requests) do list.createWindow().setData(ctx); end
end
