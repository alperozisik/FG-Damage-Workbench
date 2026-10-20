-- Host owns targets, approval, accepted rolls, feature usage and commit state.
local pending = {};
local views = {};
local counter = 0;
local oldAttack, oldSave, oldWeapon, oldPower, oldPostGet;
local previewing = false;
local rolling = {};

function onInit()
  ToolbarManager.registerButton("dwb_edit", {
    sType="toggle", nDefault=1,
    {icon="button_toolbar_locked_false",tooltipres="button_toolbar_locked_false"},
    {icon="button_toolbar_locked_true",tooltipres="button_toolbar_locked_true"},
    fnOnValueChange=function(c)
      local w=WindowManager.getTopWindow(c.window);
      if w and w.setEditing then w.setEditing(c.getValue()==0); end
    end,
  });
  if Session.IsHost and DB.findNode("damageworkbenchlinks") then DB.deleteNode("damageworkbenchlinks"); end
  registerRollTransport();
  OptionsManager.registerOptionData({ sKey = "DWB_CONFIRM", sGroupRes = "dwb_options",
    sLabelRes = "dwb_confirmation", sType = "option_entry_cycler",
    tCustom = { labelsres = "dwb_ask|dwb_auto", values = "ask|auto", default = "ask" } });
  GameManager.addAction("dwbstage", { bUseModStack = false });
  GameManager.addAction("dwbreroll", { bUseModStack = false });
  ActionsManager.registerResultHandler("dwbstage", onStageResult);
  ActionsManager.registerResultHandler("dwbreroll", onStageResult);
  OOBManager.registerOOBMsgHandler("DWB_VIEW", receiveView);
  OOBManager.registerOOBMsgHandler("DWB_COMMAND", receiveCommand);
  OOBManager.registerOOBMsgHandler("DWB_DIRECT_DAMAGE", receiveDirectDamage);
  GameManager.addEventFunction("onActionPostTargeting", onDamageTargeting);
  Interface.addKeyedEventHandler("onHotkeyActivated", "dwbpreset", activatePreset);
  Interface.addKeyedEventHandler("onHotkeyActivated", "dwbreopen", activateReopen);
  Comm.registerSlashHandler("dwb", slash, "Open pending damage; /dwb demo opens a local demonstration");
  oldAttack = ActionAttack.applyAttack;
  ActionAttack.applyAttack = function(source, target, roll)
    oldAttack(source, target, roll);
    if Session.IsHost and (roll.sResult == "hit" or roll.sResult == "crit") then queue(source, target, roll, false); end
  end;
  oldSave = ActionSave.applySave;
  ActionSave.applySave = function(target, source, roll)
    oldSave(target, source, roll);
    if Session.IsHost and (roll.sResult == "failure" or roll.sResult == "half_failure") then queue(source, target, roll, true); end
  end;
  -- Preserve whatever implementation other extensions have installed.
  oldWeapon = CharWeaponManager.buildAttackAction;
  CharWeaponManager.buildAttackAction = function(actor, node)
    local action = oldWeapon(actor, node);
    if action then action.sDWBPath = DB.getPath(node); end
    return action;
  end;
  local oldAttackRoll = ActionAttack.getRoll;
  ActionAttack.getRoll = function(actor, action)
    local roll = oldAttackRoll(actor, action);
    if action then roll.sDWBPath = action.sDWBPath or action.weaponPath; end
    return roll;
  end;
  local oldEffectRoll=ActionEffect.getRoll;
  ActionEffect.getRoll=function(actor,action,targets)
    local roll=oldEffectRoll(actor,action,targets);
    if roll and action then roll.sDWBPath=action.sDWBPath; end
    return roll;
  end;
  oldPower = PowerManager.getPowerAction;
  PowerManager.getPowerAction = function(node, data)
    local action = oldPower(node, data);
    if action and node then action.sDWBPath = DB.getPath(node); end
    return action;
  end;
  oldPostGet = GameManager.getMultiKeyFunction("onActionPostGetRoll", "");
  GameManager.setMultiKeyFunction("onActionPostGetRoll", "", function(actor, action, roll)
    if oldPostGet then oldPostGet(actor, action, roll); end
    if action then roll.sDWBPath = action.sDWBPath or action.weaponPath; end
  end);
  -- powersave has its own builder and does not dispatch onActionPostGetRoll.
  local old = ActionPowerSave.getRoll;
  ActionPowerSave.getRoll = function(actor, action)
    local roll = old(actor, action);
    if action and action.sDWBPath then roll.sDesc = roll.sDesc .. " [DWB:" .. action.sDWBPath .. "]"; end
    return roll;
  end;
  if Session.IsHost then
    DB.addHandler("combattracker.list.*.active", "onUpdate", DWBFeatures.onTurnChanged);
    DWBFeatures.onTurnChanged();
  end
end

function onClose()
  GameManager.removeEventFunction("onActionPostTargeting", onDamageTargeting);
  if Session.IsHost then DB.removeHandler("combattracker.list.*.active", "onUpdate", DWBFeatures.onTurnChanged); end
end

function tell(s)
  ChatManager.SystemMessage("Damage Workbench: " .. s);
end

function newId()
  counter = counter + 1;
  return string.format("%08x%08x%08x-%d", math.random(0, 0x7fffffff), math.random(0, 0x7fffffff), math.random(0, 0x7fffffff), counter);
end

function linkPath(id) return "damageworkbenchlinks.id-"..id; end
function createReopenLink(id)
  local node=DB.createNode(linkPath(id));
  DB.setValue(node,"request","string",id);
  DB.setPublic(node,true);
end

function pathOfAction(source, roll, save)
  local path = roll.sDWBPath or (roll.sSaveDesc or ""):match("%[DWB:([^]]+)%]") or (roll.sDesc or ""):match("%[DWB:([^]]+)%]");
  local node = path and DB.findNode(path);
  local sourcePath = ActorManager.getCreatureNodeName(source);
  if node and path:sub(1, #sourcePath + 1) == sourcePath .. "." then return node; end
  local label;
  if save then label = ActionCore.decodeLabelText(roll.sSaveDesc or "", "action_savevs_tag");
  else label = roll.sLabel or ActionCore.decodeLabelText(roll.sDesc or "", "action_attack_tag"); end
  label = (label or ""):lower():gsub("%s*%([^)]*%)%s*$", "");
  local found = {};
  for _, list in ipairs(save and { "powers" } or { "weaponlist", "powers" }) do
    for _, entry in ipairs(DB.getChildList(ActorManager.getCreatureNode(source), list)) do
      if DB.getValue(entry, "name", ""):lower() == label then table.insert(found, entry); end
    end
  end
  if #found == 1 then return found[1]; end
  return nil;
end

function damageAction(source, node)
  local path = DB.getPath(node);
  if path:match("%.weaponlist%.") then
    local action = CharWeaponManager.buildDamageAction(source, node);
    local _, itemPath = DB.getValue(node, "shortcut", "", "");
    action.weaponPath = path;
    return action, { weapon = true, range = action.range, properties = DB.getValue(node, "properties", ""), itemPath = itemPath };
  end
  local power = node;
  if path:match("%.actions%.") then power = DB.getChild(node, "..."); end
  if DB.getValue(power, "level", -1) ~= 0 then return nil; end
  local group = DB.getValue(power, "group", ""):lower();
  if not group:find("spell", 1, true) and DB.getValue(power, "type", ""):lower() ~= "spell" then return nil; end
  -- A direct damage drop must keep the selected variant (e.g. d8/d12),
  -- rather than silently substituting the power's first damage action.
  if DB.getValue(node,"type","")=="damage" then
    local action=PowerManager.getPowerAction(node,{rActor=source});
    if action then PowerManager.evalAction(source,power,action); end
    return action,{cantrip=true,damagePath=DB.getPath(node)};
  end
  local actions = DB.getChildList(power, "actions");
  table.sort(actions, function(a, b)
    local x, y = DB.getValue(a, "order", 0), DB.getValue(b, "order", 0);
    if x == y then return DB.getPath(a) < DB.getPath(b); end
    return x < y;
  end);
  for _, actionNode in ipairs(actions) do
    if DB.getValue(actionNode, "type", "") == "damage" then
      local action=PowerManager.getPowerAction(actionNode, { rActor = source });
      if action then PowerManager.evalAction(source,power,action); end
      return action, { cantrip = true,damagePath=DB.getPath(actionNode) };
    end
  end
end

function onDamageTargeting(source, groups, rolls)
  if not source or not ActorManager.isPC(source) then return; end
  if Session.IsHost then
    if not DWBPreferences.enabled(DWBPreferences.owner(source)) then return; end
  elseif not DWBPreferences.localEnabled() then return; end
  local targets={}; local seen={};
  for _,group in ipairs(groups or {}) do for _,target in ipairs(group) do
    local path=ActorManager.getCTNodeName(target);
    if path~="" and not seen[path] then seen[path]=true; table.insert(targets,path); end
  end end
  if #targets==0 then return; end
  for i=#rolls,1,-1 do
    local roll=rolls[i];
    local node=roll.sType=="damage" and not roll.sDWBCommitted and pathOfAction(source,roll,false);
    if node and DB.getValue(node,"type","")=="damage" then
      local power=DB.getChild(node,"...");
      local group=DB.getValue(power,"group",""):lower();
      if DB.getValue(power,"level",-1)==0 and
        (group:find("spell",1,true) or DB.getValue(power,"type",""):lower()=="spell") then
        for _,target in ipairs(targets) do
          local msg={type="DWB_DIRECT_DAMAGE",source=ActorManager.getCreatureNodeName(source),
            target=target,path=DB.getPath(node),user=Session.IsHost and "" or Session.UserName};
          if Session.IsHost then receiveDirectDamage(msg); else Comm.deliverOOBMessage(msg,""); end
        end
        -- Remove before modifiers/dice: effects are previewed once by DWB.
        table.remove(rolls,i);
      end
    end
  end
end

function receiveDirectDamage(msg)
  if not Session.IsHost then return; end
  local source,target=ActorManager.resolveActor(msg.source),ActorManager.resolveActor(msg.target);
  if not source or not target or not ActorManager.isPC(source) then return; end
  local owner=DWBPreferences.owner(source);
  if msg.user~="" and msg.user~=owner then return; end
  local roll={sType="damage",sDWBPath=msg.path,sResult="hit"};
  local node=pathOfAction(source,roll,false);
  if not node or DB.getValue(node,"type","")~="damage" then return; end
  queue(source,target,roll,false,true);
end

function queue(source, target, roll, save, direct)
  if not source or not target or not ActorManager.isPC(source) then return; end
  local owner=DWBPreferences.owner(source);
  if not DWBPreferences.enabled(owner) then return; end
  local node = pathOfAction(source, roll, save);
  if not node then return; end
  if direct then
    for _,ctx in pairs(pending) do
      if ctx.source==ActorManager.getCreatureNodeName(source) and
        ctx.target==ActorManager.getCTNodeName(target) and (ctx.damagePath or ctx.actionPath)==DB.getPath(node) and ctx.state~="applied" then
        if ctx.state=="approval" then showApprovals(); else sendView(ctx,true); end
        return;
      end
    end
  end
  local ok, action, info = pcall(damageAction, source, node);
  if not ok then tell("Could not build damage: " .. tostring(action)); return; end
  if not action then return; end
  local ctx = info;
  ctx.id = newId(); ctx.source = ActorManager.getCreatureNodeName(source);
  ctx.sourceCT = ActorManager.getCTNodeName(source);
  ctx.target = ActorManager.getCTNodeName(target);
  if ctx.target == "" then ctx.target = ActorManager.getCreatureNodeName(target); end
  ctx.owner = owner;
  ctx.action = action; ctx.critical = roll.sResult == "crit"; ctx.state = "approval";
  ctx.actionPath=DB.getPath(node);
  ctx.advantage = roll.bADV or (roll.sDesc or ""):match("%[ADV%]") ~= nil;
  ctx.disadvantage = roll.bDIS or (roll.sDesc or ""):match("%[DIS%]") ~= nil;
  ctx.label = action.label or "Damage";
  ctx.publicName = ActorManager.getDisplayName(source);
  pending[ctx.id] = ctx;
  if OptionsManager.isOption("DWB_CONFIRM", "auto") then approve(ctx.id);
  else showApprovals(); end
end

function showApprovals()
  local w = Interface.findWindow("dwb_approvals", "");
  if #approvals() == 0 then if w then w.close(); end; return; end
  w = w or Interface.openWindow("dwb_approvals", "");
  if w and w.refresh then w.refresh(); end
end

function approvals()
  local out = {};
  for _, ctx in pairs(pending) do if ctx.state == "approval" then table.insert(out, ctx); end end
  table.sort(out, function(a, b) return a.id < b.id; end);
  return out;
end

function preferenceChanged(user)
  if not Session.IsHost or DWBPreferences.enabled(user) then return; end
  for id,ctx in pairs(pending) do
    if ctx.owner==user and ctx.state=="approval" then pending[id]=nil; end
  end
  showApprovals();
end

function reject(id)
  if not Session.IsHost then return; end
  pending[id] = nil; showApprovals();
end

function prepare(ctx)
  local source, target = ActorManager.resolveActor(ctx.source), ActorManager.resolveActor(ctx.target);
  if (ctx.itemPath or "") ~= "" then source.itemPath = ctx.itemPath; end
  local roll = ActionDamageD20.getRoll(source, DWBModel.copy(ctx.action));
  roll.bCritical = ctx.critical;
  local expires = {};
  local original = EffectManager.applyEffectExpiration;
  local originalCrit = ActionAttackCore.getCritState;
  if previewing then error("Nested effect preview is not supported"); end
  previewing = true;
  -- Preview must not consume the native per-target critical token.
  ActionAttackCore.getCritState = function() return ctx.critical; end;
  EffectManager.applyEffectExpiration = function(node, match)
    if node then
      table.insert(expires, { path = DB.getPath(node), match = match,
        label = DB.getValue(node, "label", ""), active = DB.getValue(node, "isactive", 0),
        apply = DB.getValue(node, "apply", "") });
    end
  end;
  local ok, err = pcall(function() ActionsManager.applyModifiers(source, target, roll, true); end);
  EffectManager.applyEffectExpiration = original;
  ActionAttackCore.getCritState = originalCrit;
  previewing = false;
  if not ok then error(err); end
  ActionCore.decodeRollClauses(roll);
  ctx.expirations = expires; ctx.prepared = roll;
  local p = DWBModel.new(ctx.label);
  p.flags = {};
  for _, key in ipairs({ "bModMax", "bModHalf", "bModDouble", "nMult", "bSecret", "bTower" }) do p.flags[key] = roll[key]; end
  local imported, importError = DWBModel.importClauses(p, DWBModel.rollClauses(roll));
  if not imported then error(importError or "Could not import damage clauses"); end
  p.magical = ctx.cantrip == true;
  for _, c in ipairs(roll.clauses or {}) do if (c.dmgtype or ""):match("magic") then p.magical = true; end end
  DWBModel.setCritical(p, roll.bCritical == true);
  -- Optional class damage is supplied by active effects or explicit drops.
  p.id = ctx.id; p.source=ctx.source; p.actorName = ctx.publicName; p.turnRerolls = DWBFeatures.rerollCount(ctx);
  return p;
end

function approve(id)
  if not Session.IsHost then return; end
  local ctx = pending[id];
  if not ctx or ctx.state ~= "approval" then return; end
  if not DWBPreferences.enabled(ctx.owner) then pending[id]=nil; showApprovals(); return; end
  local ok, plan = pcall(prepare, ctx);
  if not ok then tell("Preparation failed; no damage applied: " .. tostring(plan)); return; end
  ctx.plan = plan; ctx.state = "edit";
  createReopenLink(ctx.id);
  Comm.deliverChatMessage({ text = ctx.publicName .. " — " .. ctx.label .. ": HIT. Damage adjustment pending.", font = "systemfont" });
  sendView(ctx, true);
  showApprovals();
end

function sendView(ctx, open)
  local msg = { type = "DWB_VIEW", id = ctx.id, state = ctx.state,
    payload = Utility.encodeJSON(ctx.plan), open = open and "1" or "0", notice = ctx.notice };
  if ctx.owner == "" then receiveView(msg); else Comm.deliverOOBMessage(msg, ctx.owner); end
  ctx.notice = nil;
end

function refuse(ctx, text)
  ctx.notice = text; sendView(ctx);
end

function receiveView(msg)
  local plan = Utility.decodeJSON(msg.payload or "");
  if not plan then return; end
  if msg.notice and msg.notice ~= "" then tell(msg.notice); end
  plan.id = msg.id; plan.phase = msg.state;
  views[msg.id] = plan;
  local w = Interface.findWindow("dwb_panel", "");
  if msg.open == "1" and DWBPreferences.localEnabled() then
    w = Interface.openWindow("dwb_panel", "");
    if w then w.setPlan(plan); end
    -- A custom hotkey-style chat entry is a session-only reopen handle.
    local token = { text = "Reopen damage: " .. (plan.label or "Damage"), font = "systemfont",
      icon = "action_damage", shortcuts = { { class = "dwb_reopen", recordname = linkPath(msg.id) } } };
    Comm.addChatMessage(token);
  elseif w and w.getPlan() and w.getPlan().id == msg.id then w.setPlan(plan); end
  if msg.state == "applied" then views[msg.id] = nil; if w and w.getPlan() and w.getPlan().id == msg.id then w.close(); end end
end

function command(id, operation, data)
  local msg = { type = "DWB_COMMAND", id = id, op = operation,
    payload = Utility.encodeJSON(data or {}) };
  if Session.IsHost then receiveCommand(msg); else Comm.deliverOOBMessage(msg, ""); end
end

function checkExpirations(ctx)
  for _, e in ipairs(ctx.expirations or {}) do
    local node = DB.findNode(e.path);
    if not node or DB.getValue(node, "label", "") ~= e.label or DB.getValue(node, "isactive", 0) ~= e.active then
      return false, "An effect changed. Close this panel and resolve a fresh attack.";
    end
  end
  return true;
end

function receiveCommand(msg)
  if not Session.IsHost then return; end
  local ctx = pending[msg.id];
  if not ctx then return; end
  local data = Utility.decodeJSON(msg.payload or "") or {};
  local op = msg.op;
  if op == "effectdrop" and ctx.state == "edit" then
    local candidate=data.plan;
    if type(candidate)~="table" or candidate.phase~="edit" or type(candidate.zones)~="table" then return; end
    local plan,err=DWBEffectDrop.import(ctx,candidate,data.effect);
    if not plan then ctx.plan=candidate; refuse(ctx,err); return; end
    plan.id=ctx.id; plan.source=ctx.source; plan.label=ctx.label; plan.flags=DWBModel.copy(ctx.plan.flags);
    ctx.plan=plan; sendView(ctx);
  elseif op == "roll" and ctx.state == "edit" then
    local ok, err = DWBModel.valid(data);
    if not ok then refuse(ctx, err); return; end
    data.phase = "edit"; data.id = ctx.id; data.label = ctx.label; data.rerolls = 0;
    data.flags = DWBModel.copy(ctx.plan.flags);
    -- Claims may only reference features supplied by the host.
    local allowed = DWBModel.copy(ctx.plan.claims);
    -- Restored feature dice still count against the current turn's usage.
    data.claims = data.claims or {};
    for key in pairs(DWBFeatures.presentFeatures(data)) do
      if not allowed[key] then refuse(ctx, "Saved feature is unavailable for this attack: " .. key .. ". Remove its dice or choose a fresh layout."); return; end
      if not data.claims[key] then data.claims[key] = DWBModel.copy(allowed[key]); end
    end
    for key, claim in pairs(data.claims or {}) do
      if not allowed[key] then refuse(ctx, "Unknown feature claim"); return; end
      data.claims[key] = allowed[key];
    end
    DWBFeatures.pruneClaims(data);
    ok, err = DWBFeatures.validateClaims(ctx, data);
    if ok then ok, err = checkExpirations(ctx); end
    if not ok then refuse(ctx, err); return; end
    ctx.plan = data;
    ctx.expected = DWBModel.buildRoll(data);
    ctx.nonce = newId(); ctx.state = "rolling";
    sendRoll(ctx, ctx.expected, false);
  elseif op == "landed" and (ctx.state == "rolling" or ctx.state == "rerolling") then
    if data.nonce ~= ctx.nonce then return; end
    ctx.nonce = nil;
    local ok, err;
    if ctx.state == "rolling" then
      ok, err = DWBModel.recordResults(ctx.plan, data);
    else
      local want = ctx.plan.roll.aDice[ctx.rerollIndex];
      local accepted;accepted,err=DWBModel.resolveDice({want},data.aDice or {});
      local d=accepted and accepted[1];
      ok=d and DWBModel.reroll(ctx.plan,ctx.rerollIndex,d.value or d.result);
      if ok then
        for _,key in ipairs({"diceskin","dicebodycolor","dicetextcolor","iconcolor","backcolor","rolls"}) do
          want[key]=DWBModel.copy(d[key]);
        end
      end
      if ok then ctx.plan.turnRerolls = DWBFeatures.countReroll(ctx); end
    end
    if not ok then ctx.state = "edit"; ctx.plan.phase = "edit"; tell(err or "Invalid dice result; damage was not applied");
    else ctx.state = "results"; end
    sendView(ctx);
  elseif op == "undo" and ctx.state == "results" then
    auditUndo(ctx);
    if DWBModel.undo(ctx.plan) then ctx.state = "edit"; sendView(ctx); end
  elseif op == "double" and ctx.state == "results" and type(data.enabled)=="boolean" then
    ctx.plan.doubleDamage=data.enabled; sendView(ctx);
  elseif op == "reroll" and ctx.state == "results" then
    local i = tonumber(data.index);
    local die = i and ctx.plan.roll.aDice[i];
    if not die then return; end
    ctx.rerollIndex = i; ctx.nonce = newId(); ctx.state = "rerolling";
    local mapping = ctx.plan.roll.mapping[i]; local z = DWBModel.findZone(ctx.plan, mapping.zone);
    sendRoll(ctx, { aDice = { DWBModel.copy(die) }, clauses = { { dice = {die.type}, dmgtype = DWBModel.typeText(z, die, mapping.critical, ctx.plan.magical) } }, nMod = 0, sDesc = "Damage reroll" }, true);
  elseif op == "apply" and ctx.state == "results" then
    apply(ctx);
  elseif op == "reopen" and ctx.state ~= "approval" and ctx.state ~= "applied" then sendView(ctx, true); end
end

function sendRoll(ctx, roll, reroll)
  roll=DWBModel.copy(roll);
  roll.bSecret=secretRoll(ctx);
  local msg = { type = "DWB_ROLL", id = ctx.id, nonce = ctx.nonce,
    source=ctx.source, payload = Utility.encodeJSON(roll), reroll = reroll and "1" or "0" };
  if ctx.owner == "" then receiveRoll(msg); else Comm.deliverOOBMessage(msg, ctx.owner); end
end

function secretRoll(ctx)
  local source,target=ActorManager.resolveActor(ctx.source),ActorManager.resolveActor(ctx.target);
  local flags=ctx.plan and ctx.plan.flags or {};
  if flags.bSecret or flags.bTower then return true; end
  if ctx.owner=="" and OptionsManager.isOption("REVL","off") then return true; end
  if source and CombatManager.isCTHidden(ActorManager.getCTNode(source)) then return true; end
  return not ActionsManager.getShowResultToPlayer(source,target);
end

function auditUndo(ctx)
  local parts={}; local p=ctx.plan;
  for _,z in ipairs(p.zones) do
    local dice={};
    for i,m in ipairs(p.roll and p.roll.mapping or {}) do
      if m.zone==z.id then
        local d=p.roll.aDice[i];
        local mode=(d.nReroll or 0)>0 and ("r"..d.nReroll..(d.bRerollNoLimit and "" or "#1")) or "";
        table.insert(dice,DWBModel.dieType(d)..mode.."="..tostring(d.value or d.result));
      end
    end
    if z.modifier~=0 then table.insert(dice,string.format("%+d",z.modifier)); end
    table.insert(parts,z.dtype.." ("..z.side.."): "..table.concat(dice,", "));
  end
  local text=(ctx.owner~="" and ctx.owner or "GM").." — "..(ctx.publicName or "").." / "..ctx.label..": UNDONE\n"..table.concat(parts,"; ").."\nTotal: "..DWBModel.total(p)..(p.doubleDamage and " (x2 enabled)" or "")..". No damage applied.";
  local message={text=text,font="systemfont",icon="action_damage",secret=true};
  Comm.deliverChatMessage(message,"");
  if ctx.owner~="" then Comm.deliverChatMessage(DWBModel.copy(message),ctx.owner); end
end

function receiveRoll(msg)
  local r = Utility.decodeJSON(msg.payload or "");
  if not r then return; end
  r.sType = msg.reroll == "1" and "dwbreroll" or "dwbstage";
  r.sDWBId = msg.id; r.sDWBNonce = msg.nonce;
  r.sDesc = "Damage Workbench";
  local dice = {};
  local cursor = 1;
  for _, clause in ipairs(r.clauses or {}) do
    for _ in ipairs(clause.dice or {}) do
      local d = DWBModel.copy(r.aDice[cursor]);
      if d then
        local styled = {};
        DiceRollManager.addDamageDice(styled, { DWBModel.dieType(d) }, { dmgtype = clause.dmgtype,
          iconcolor = (d.type or ""):match("^g") and "00FF00" or nil,
        });
        local result=styled[1] or d;
        result.mode=d.mode;
        -- Retain dropped skins and let the native throw engine execute the mode.
        for _,key in ipairs({"diceskin","dicebodycolor","dicetextcolor","iconcolor","backcolor"}) do
          if d[key]~=nil then result[key]=d[key]; end
        end
        table.insert(dice, result);
      end
      cursor = cursor + 1;
    end
  end
  if #dice == #r.aDice then r.aDice = dice; end
  for _, d in ipairs(r.aDice) do d.result = nil; d.value = nil; end
  rolling[msg.nonce] = true;
  local w = Interface.findWindow("dwb_panel", "");
  if w then w.setBusy(true); end
  -- Roll directly: effects/modifier stack were already captured exactly once.
  ActionsManager.roll(ActorManager.resolveActor(msg.source), nil, r);
end

function onStageResult(_, _, r)
  if not r.sDWBNonce or not rolling[r.sDWBNonce] then return; end
  rolling[r.sDWBNonce] = nil;
  if r.sDWBId == "demo" then
    local p = views.demo;
    DWBModel.recordResults(p, r);
    local w = Interface.findWindow("dwb_panel", ""); if w then w.setPlan(p); end
    return;
  end
  command(r.sDWBId, "landed", { nonce = r.sDWBNonce, aDice = r.aDice });
end

function apply(ctx)
  local ok, err = checkExpirations(ctx);
  if ok then ok, err = DWBFeatures.validateClaims(ctx, ctx.plan); end
  if not ok then refuse(ctx, err); return; end
  local source, target = ActorManager.resolveActor(ctx.source), ActorManager.resolveActor(ctx.target);
  if not source or not target then refuse(ctx, "The source or target no longer exists"); return; end
  if not ActorManager.isPC(target) and not ActorManager.isRecordType(target, { "npc", "vehicle" }) then
    refuse(ctx, "The target has no native health record. Correct its combat tracker link before applying."); return;
  end
  if (ctx.itemPath or "") ~= "" then source.itemPath = ctx.itemPath; end
  -- Mark before dispatch; repeated clicks/OOB delivery cannot apply twice.
  ctx.state = "applying";
  local r = DWBModel.copy(ctx.plan.roll);
  r.bModDouble=r.bModDouble or ctx.plan.doubleDamage==true;
  r.sType = "damage"; r.sDesc = "[DAMAGE" .. (ctx.range and " (" .. ctx.range .. ")" or "") .. "] " .. ctx.label;
  if ctx.plan.critical then r.sDesc = r.sDesc .. " [CRITICAL]"; end
  if r.bModHalf then r.sDesc = r.sDesc .. " [HALF]"; end
  if r.bModDouble then r.sDesc = r.sDesc .. " [DOUBLE]"; end
  r.bCritical = ctx.plan.critical; r.bWeapon = ctx.weapon; r.bSpell = ctx.cantrip;
  r.sRange = ctx.range; r.nTotal = DWBModel.total(ctx.plan);
  r.mapping = nil; r.sDWBCommitted = ctx.id;
  -- These values have already been accepted (including explicit rerolls/min/max).
  -- Do not run a second post-roll transformation after displaying the results.
  for _, die in ipairs(r.aDice) do
    die.result = die.value or die.result; die.value = die.result;
    die.dropped = nil;
  end
  for _, c in ipairs(r.clauses) do c.nTotal = nil; end
  ActionCore.encodeRollClauses(r);
  ActionCore.decodeRollClauses(r);
  ActionCore.encodeDamageTypesDisplay(r);
  if ActionsManager.total(r) ~= DWBModel.total(ctx.plan) then
    ctx.state = "results"; refuse(ctx, "Accepted damage total changed; no damage applied"); return;
  end
  -- Let the current result hooks and native health application handle
  -- resistance, immunity, critical immunity, wards, concentration, and Undo.
  local success, failure = pcall(function()
    local seen = {};
    for _, e in ipairs(ctx.expirations or {}) do
      local key = e.path .. ":" .. tostring(e.match);
      if not seen[key] then
        seen[key] = true;
        EffectManager.applyEffectExpiration(DB.findNode(e.path), e.match);
      end
    end
    DWBFeatures.commit(ctx, ctx.plan);
    target.nOrder = 1;
    ActionsManager.resolveAction(source, target, r);
    ActionAttackCore.clearCritState(source, target);
  end);
  if not success then
    ctx.state = "error";
    tell("Apply encountered an error. Check the combat tracker before retrying: " .. tostring(failure));
    return;
  end
  ctx.state = "applied"; ctx.plan.phase = "applied"; sendView(ctx);
  DB.deleteNode(linkPath(ctx.id));
  pending[ctx.id] = nil;
end

function view(id)
  return views[id];
end

function panelClosed(plan)
  if not plan or plan.phase=="applied" then return; end
  -- Local chat only: this runs on the machine that closed the window.
  if plan.id=="demo" then views.demo=plan;
  elseif views[plan.id] and plan.phase=="edit" then views[plan.id]=plan; end
  local shortcuts=plan.id~="demo" and {{class="dwb_reopen",recordname=linkPath(plan.id)}} or nil;
  Comm.addChatMessage({text="Damage was not applied. Reopen damage: "..(plan.label or "Damage").." (or /dwb)",
    font="systemfont",icon="action_damage",shortcuts=shortcuts});
end

function reopen(id)
  if views[id] then
    local w = Interface.openWindow("dwb_panel", ""); if w then w.setPlan(views[id]); end
  else tell("This pending damage no longer exists in this session"); end
end

function activateReopen(drag)
  reopen(drag.getStringData()); return true;
end

function activatePreset(drag)
  local saved = Utility.decodeJSON(drag.getStringData() or "");
  local w = Interface.findWindow("dwb_panel", "");
  if w and w.getPlan() then
    if DWBModel.replace(w.getPlan(), saved) then w.refresh(); else tell("Presets can only replace an unrolled damage plan"); end
  else tell("Use " .. (saved and saved.label or "this damage") .. " inside the Damage Adjustment Panel"); end
  return true;
end

function drop(w, drag, zoneId)
  local p = w.getPlan();
  if not p or p.phase ~= "edit" then return false; end
  local dtype = drag.getType();
  if dtype=="effect" then
    local source=ActorManager.resolveActor(p.source);
    if not source or p.id=="demo" then tell("Drop effects into a targeted damage panel"); return true; end
    local effect=EffectManager.decodeEffectFromDrag(drag,source);
    if effect then
      w.setBusy(true);
      command(p.id,"effectdrop",{plan=p,effect={sName=effect.sName,sSource=effect.sSource,actionPath=drag.getMetaData("sDWBPath")}});
    end
    return true;
  end
  if dtype == "dwbpreset" then return activatePreset(drag); end
  if dtype == "dwbmove" and zoneId then
    local move = Utility.decodeJSON(drag.getStringData() or "");
    if move and move.id == p.id then DWBModel.moveDice(p, move.zone, zoneId, move.indices); w.clearSelection(); w.refresh(); end
    return true;
  end
  if dtype == "dice" and zoneId then
    DWBModel.addDice(p, zoneId, drag.getDiceData()); w.clearSelection(); w.refresh(); return true;
  end
  if dtype == "damage" then
    local _, rolls = ActionsManager.decodeActionFromDrag(drag);
    local r = rolls and rolls[1];
    if r then
      ActionCore.decodeRollClauses(r);
      local imported, importError = DWBModel.appendClauses(p, DWBModel.rollClauses(r));
      if not imported then tell(importError or "Could not import damage action"); end
      w.refresh();
    end
    return true;
  end
  return false;
end

function slash(_, text)
  local setting=(text or ""):lower():match("^%s*(.-)%s*$");
  if setting=="on" or setting=="off" then
    OptionsManager.setOption("DWB_ENABLED",setting);
    tell("Damage Workbench "..setting.." for this user. Applies to new attacks; existing pending damage can still be reopened.");
    return;
  end
  if (text or ""):lower() == "demo" then demo(); return; end
  for id in pairs(views) do reopen(id); return; end
  tell("No unresolved damage. Weapon hits and failed cantrip saves open a panel after GM confirmation.");
end

function demo()
  local p = DWBModel.new("Demo damage (no target)"); p.id = "demo";
  DWBModel.importClauses(p, { { dmgtype = "piercing", dice = { "d8" }, modifier = 5 },
    { dmgtype = "radiant", dice = { "d8", "d8" }, modifier = 0 } });
  views.demo = p;
  local w = Interface.openWindow("dwb_panel", ""); w.setPlan(p);
end

function demoRoll(p)
  local r = DWBModel.buildRoll(p);
  if not r then return; end
  r.sType = "dwbstage"; r.sDWBId = "demo"; r.sDWBNonce = newId(); r.bSecret = true;
  rolling[r.sDWBNonce] = true;
  views.demo = p;
  ActionsManager.roll(nil, nil, r);
end

-- Register after the global function has been defined (onInit runs later).
function registerRollTransport()
  OOBManager.registerOOBMsgHandler("DWB_ROLL", receiveRoll);
end
