function onInit() refresh(); end
function onSizeChanged()
  local width, height = getSize(); paper.setStaticBounds(18,45,width-36,height-64);
  help.setStaticBounds(44,66,width-88,48);
  list.setStaticBounds(44,126,width-88,height-170);
end
function refresh()
  if not Session.IsHost then close(); return; end
  onSizeChanged();
  list.closeAll();
  for _, ctx in ipairs(DWB.approvals()) do list.createWindow().setData(ctx); end
end
