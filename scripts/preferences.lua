-- Native local options persist in this client's CampaignRegistry. The host
-- receives only a session copy for routing each character owner's next hit.
local users={};
function onInit()
  OptionsManager.registerOptionData({sKey="DWB_ENABLED",bLocal=true,sGroupRes="dwb_options",
    sLabelRes="dwb_enabled",sType="option_entry_cycler",
    tCustom={labelsres="dwb_on|dwb_off",values="on|off",default="on"}});
  OptionsManager.registerCallback("DWB_ENABLED",changed);
  OOBManager.registerOOBMsgHandler("DWB_PREFERENCE",receive);
  OOBManager.registerOOBMsgHandler("DWB_PREFERENCE_QUERY",query);
  if Session.IsHost then User.addEventHandler("onLogin",login); end
end
function onTabletopInit()
  if Session.IsHost then
    for _,user in ipairs(User.getActiveUsers()) do login(user,true); end
  else changed(); end
end
function onClose()
  OptionsManager.unregisterCallback("DWB_ENABLED",changed);
  if Session.IsHost then User.removeEventHandler("onLogin",login); end
end
function localEnabled() return OptionsManager.isOption("DWB_ENABLED","on"); end
function owner(actor)
  local user=DB.getOwner(ActorManager.getCreatureNode(actor)) or "";
  for _,online in ipairs(User.getActiveUsers()) do if online==user then return user; end end
  return "";
end
function enabled(user)
  if (user or "")=="" then return localEnabled(); end
  -- Until the client answers, keep classic behavior instead of opening an
  -- unwanted panel using another user's default.
  return users[user]==true;
end
function changed()
  if Session.IsHost then DWB.preferenceChanged("");
  else Comm.deliverOOBMessage({type="DWB_PREFERENCE",user=Session.UserName,
    enabled=localEnabled() and "on" or "off"},""); end
end
function login(user,active)
  users[user]=nil;
  if active then Comm.deliverOOBMessage({type="DWB_PREFERENCE_QUERY"},user); end
end
function query()
  if not Session.IsHost then changed(); end
end
function receive(msg)
  if not Session.IsHost or (msg.enabled~="on" and msg.enabled~="off") then return; end
  for _,user in ipairs(User.getActiveUsers()) do
    if user==msg.user then users[user]=msg.enabled=="on"; DWB.preferenceChanged(user); return; end
  end
end
