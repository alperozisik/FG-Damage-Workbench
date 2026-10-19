-- DEVELOPMENT ONLY. tools/build.py excludes this from release extensions.
-- Explicit /dwbtest commands use only the uniquely named sandbox training target.
local targetPath = "combattracker.list.id-00999";
local lastId;

function onInit()
  Comm.registerSlashHandler("dwbtest", run, "Development harness; local sandbox only");
end

function log(s)
  Debug.console("DWB_TEST " .. s); ChatManager.SystemMessage("DWB TEST: " .. s);
end

function getActor(feature)
  for _, node in ipairs(DB.getChildList("charsheet")) do
    local actor = ActorManager.resolveActor(node);
    if DWBFeatures.inspect(actor).features[feature] then return actor; end
  end
end

function run(_, command)
  if not Session.IsHost or DB.getValue(targetPath .. ".name", "") ~= "DWB Training Target" then
    log("Refused: this is not the explicitly named sandbox fixture"); return;
  end
  DB.setValue(DB.findNode(targetPath), "link", "windowreference", "npc", targetPath);
  local ok, err = pcall(execute, (command or ""):lower());
  if not ok then log("FAIL " .. tostring(err)); end
end

function execute(command)
  local target = ActorManager.resolveActor(targetPath);
  if command == "suite" then suite(); return;
  elseif command == "ui" then uiSuite(); return;
  elseif command == "exact" then exactSuite(); return;
  elseif command == "drops" then dropSuite(); return;
  elseif command == "prefs" then preferenceSuite(); return;
  elseif command == "directcantrip" then directCantripSuite(); return;
  elseif command == "savedoff" then
    assert(not DWBPreferences.localEnabled() and CampaignRegistry.OptDWB_ENABLED=="off","Off preference lost after reload");
    log("PASS local Off preference survives reload"); return;
  elseif command == "weapon" or command == "crit" or command == "paladin" or command == "rogue" then
    local feature = command == "paladin" and "improved divine smite" or command == "rogue" and "sneak attack" or "blessed strikes";
    local source = assert(getActor(feature), "Feature fixture unavailable");
    local weapons = DB.getChildList(ActorManager.getCreatureNode(source), "weaponlist");
    table.sort(weapons, function(a,b) return DB.getPath(a)<DB.getPath(b); end);
    local node = assert(weapons[1]);
    local action = CharWeaponManager.buildAttackAction(source, node);
    local roll = ActionAttack.getRoll(source, action);
    roll.sResult = command == "crit" and "crit" or "hit";
    roll.nTotal = 25; roll.nFirstDie = command == "crit" and 20 or 15;
    roll.sResults = "[HIT]"; roll.aMessages = {};
    ActionAttack.applyAttack(source, target, roll);
    local list = DWB.approvals(); lastId = list[#list] and list[#list].id;
    log("weapon queued " .. tostring(#list) .. " approval(s)");
  elseif command == "cantrip" then
    local source = assert(getActor("blessed strikes"));
    local found;
    for _, power in ipairs(DB.getChildList(ActorManager.getCreatureNode(source), "powers")) do
      if DB.getValue(power,"level",-1)==0 and DB.getValue(power,"group",""):lower():find("spell",1,true) then
        for _, action in ipairs(DB.getChildList(power,"actions")) do
          if DB.getValue(action,"type","")=="damage" then found=power; break; end
        end
      end
      if found then break; end
    end
    assert(found,"No damaging cantrip fixture");
    local roll = { sType="save", sDesc="[SAVE] Dexterity", sSave="dexterity", sSaveDesc="[SAVE VS] " .. DB.getValue(found,"name","") .. " [DWB:" .. DB.getPath(found) .. "]",
      aDice={},nMod=0,nTotal=1,nTarget=20,bRemoveOnMiss=false };
    ActionSave.applySave(target,source,roll);
    local list=DWB.approvals(); lastId=list[#list] and list[#list].id;
    log("cantrip queued " .. tostring(#list) .. " approval(s)");
  elseif command == "approve" then
    assert(lastId,"No queued action"); DWB.approve(lastId);
    local p=assert(DWB.view(lastId),"No local view created (routing/preparation failed)");
    log("approved " .. p.label .. " zones=" .. #p.zones .. " dice=" .. DWBModel.countDice(p));
  elseif command == "stats" then
    local w=Interface.findWindow("dwb_panel",""); local p=w and w.getPlan();
    if p then
      log("phase=" .. p.phase .. " crit=" .. tostring(p.critical) .. " magical=" .. tostring(p.magical) .. " total=" .. DWBModel.total(p));
      for _,z in ipairs(p.zones) do log(z.side .. " " .. z.dtype .. " dice=" .. #z.dice .. " fixed=" .. z.modifier); end
    end
    log("target wounds=" .. DB.getValue(targetPath .. ".wounds",0));
  elseif command == "applytwice" then
    assert(lastId); DWB.command(lastId,"apply"); DWB.command(lastId,"apply"); log("Repeated apply dispatched");
  elseif command == "resist" or command == "immune" or command == "critimmune" or command == "mark" or command == "single" then
    local source=assert(getActor("blessed strikes"));
    local text,actor;
    if command=="resist" then text="RESIST: bludgeoning"; actor=target;
    elseif command=="immune" then text="IMMUNE: radiant"; actor=target;
    elseif command=="critimmune" then text="IMMUNE: critical"; actor=target;
    elseif command=="mark" then text="Harness Mark; DMG: 1d6,fire"; actor=source;
    else text="Harness Single; DMG: 1d6,cold"; actor=source; end
    EffectManager.addEffectByTable(actor,{sName=text,nDuration=0,nGMOnly=0,sApply=command=="single" and "single" or ""});
    log("Added test effect " .. text);
  elseif command == "turn" then
    local actor=assert(getActor("blessed strikes")); local path=ActorManager.getCTNodeName(actor);
    for _,node in ipairs(DB.getChildList("combattracker.list")) do DB.setValue(node,"active","number",0); end
    DB.setValue(path .. ".active","number",1); DWBFeatures.onTurnChanged(); log("New cleric turn");
  else log("weapon | crit | paladin | rogue | cantrip | approve | stats | applytwice | resist | immune | critimmune | mark | single | turn"); end
end

-- Exercise the actual window and drop/hotkey callbacks with serializable drag
-- records. Physical mouse delivery is a separate manual acceptance test.
function uiSuite()
  DWB.demo();
  local w=assert(Interface.findWindow("dwb_panel",""));
  local p=w.getPlan(); local from=p.zones[1]; local to=p.zones[2];
  local originalWindow=w.getZoneControl(1); local oldMagical=p.magical; w.toggleMagical();
  assert(w.getZoneControl(1)==originalWindow and p.magical~=oldMagical,"Magical recreated the dice list");
  log("PASS Magical toggle preserves DTZ controls");
  local fake={ getType=function() return "dice"; end,
    getDiceData=function() return {{type="d6"}}; end };
  assert(not w.isEditing(),"DTZ edit should start locked");
  local cells=w.getZoneControl(1).subwindow.dice.getWindows();
  assert(cells[1].fixed.onDrop(0,0,fake));
  assert(#from.dice==2 and from.modifier==5,"locked fixed-cell dice drop failed");
  log("PASS dice drop over fixed cell works with DTZ edit locked");
  assert(w.getZoneControl(1).subwindow.dice.onDrop(0,0,fake));
  assert(#from.dice==3,"locked dice-list drop failed");
  DWBModel.removeDice(p,from.id,{3}); w.refresh();
  log("PASS dice list routes drops with DTZ edit locked");
  fake={getType=function() return "dwbmove"; end,
    getStringData=function() return Utility.encodeJSON({id=p.id,zone=from.id,indices={1,2}}); end};
  assert(DWB.drop(w,fake,to.id)); assert(#from.dice==0 and #to.dice==4,"move failed");
  log("PASS selected dice move replaces source cells");
  local savedDice=DWBModel.copy(to.dice);
  w.selection(to.id,2); w.selection(to.id,3);
  local selectedCell=w.getZoneControl(to.id).subwindow.dice.getWindows()[3];
  selectedCell.face.onClickDown(2,0,0); selectedCell.face.onClickRelease(2,0,0);
  assert(#to.dice==4,"middle mouse must not delete dice");
  selectedCell.face.onMenuSelection(6); assert(#to.dice==2,"context menu selection delete failed");
  to.dice=savedDice; w.refresh(); log("PASS selection delete; middle mouse leaves dice intact");
  w.toggleEdit(); DWBModel.setCritical(p,true); w.refresh(); w.addZone("critical");
  local added=p.zones[#p.zones];
  for _,damageType in ipairs({"poison","fire"}) do
    local host=w.getZoneControl(added.id); local combo=host.subwindow.dtype;
    combo.onOptionClicked({Value={getValue=function() return damageType; end}});
    assert(w.getZoneControl(added.id)==host and added.dtype==damageType,"native combo callback destroyed its own control");
  end
  log("PASS critical type dropdown selects poison/fire without destroying the native callback context");
  w.toggleEdit();
  p.magical=true; DWBModel.setCritical(p,true); w.refresh(); w.savePreset();
  local save=assert(Interface.findWindow("dwb_save","")); save.name.setValue("Saved test damage");
  local record={}; local drag={
    setType=function(s) record.type=s; end,
    setStringData=function(s) record.payload=s; end,
    setDescription=function(s) record.label=s; end,
    setIcon=function(s) record.icon=s; end,
    getType=function() return record.type; end,
    getStringData=function() return record.payload; end};
  assert(save.dragPreset(drag)); save.close();
  assert(record.label=="Saved test damage" and record.type=="dwbpreset");
  DWBModel.setCritical(p,false); p.magical=false;
  DWBModel.zone(p,"cold","normal",true); w.refresh();
  assert(DWB.activatePreset(drag));
  assert(p.critical and p.magical and not DWBModel.zone(p,"cold","normal"),"preset did not replace layout");
  assert(#DWBModel.buildRoll(p).aDice==8); log("PASS named preset hotkey callback fully replaces layout");
  assert(DWB.drop(w,drag)); log("PASS preset drop callback fully replaces layout");
  w.close(); DWB.activatePreset(drag);
  assert(not Interface.findWindow("dwb_panel","")); log("PASS preset activation without panel leaves panel closed");
  log("UI CALLBACK SUITE COMPLETE");
end

function exactSuite()
  local oldRoll=ActionsManager.roll;
  local oldNotify=ActionDamageD20.notifyApplyDamage;
  local oldResult=ActionsManager.getResultHandler("damage");
  local oldPost=ActionsManager.getPostRollHandler("damage");
  local delivered,postCount; postCount=0;
  ActionsManager.roll=function(_,_,r)
    for i,d in ipairs(r.aDice) do
      local n=tonumber(DWBModel.dieType(d):sub(2)); local v=(i%n)+1;
      if r.sType=="dwbreroll" then v=4; end
      d.result=v; d.value=v;
    end
    DWB.onStageResult(nil,nil,r);
  end;
  ActionsManager.registerPostRollHandler("damage",function(...) postCount=postCount+1; return oldPost(...); end);
  ActionsManager.registerResultHandler("damage",function(source,target,r)
    delivered=DWBModel.copy(r); return oldResult(source,target,r);
  end);
  ActionDamageD20.notifyApplyDamage=function(source,target,r) ActionHealthD20.apply(source,target,r); end;
  local ok,err=pcall(function()
    local target=ActorManager.resolveActor(targetPath);
    for _,n in ipairs(ActorEffectManager.getCombatantEffectNodes(target)) do DB.deleteNode(n); end
    execute("weapon"); local list=DWB.approvals(); local ctx=assert(list[#list]); DWB.approve(ctx.id);
    local p=DWBModel.new("Mixed dice regression"); p.id=ctx.id;
    DWBModel.importClauses(p,{{dmgtype="piercing",dice={"d20","d8","d6","d8"},modifier=6}});
    DWBModel.setCritical(p,true); DWB.command(ctx.id,"roll",p);
    assert(ctx.state=="results"); DWB.command(ctx.id,"reroll",{index=2}); assert(ctx.state=="results");
    local w=assert(Interface.findWindow("dwb_panel","")); assert(w.roll.isEnabled() and w.save.isVisible());
    w.savePreset(); local saved=assert(Interface.findWindow("dwb_save","")); saved.close();
    DWB.command(ctx.id,"undo"); assert(ctx.state=="edit" and ctx.plan.roll==nil);
    assert(DWBFeatures.rerollCount(ctx)>0,"Undo erased the turn reroll count");
    local revised=DWBModel.copy(ctx.plan); DWB.command(ctx.id,"roll",revised);
    assert(ctx.state=="results"); DWB.command(ctx.id,"reroll",{index=2});
    log("PASS reroll replaces the die; Undo returns to setup; Save remains available in results");
    local accepted=DWBModel.copy(ctx.plan.roll); local total=DWBModel.total(ctx.plan);
    local before=DB.getValue(targetPath..".wounds",0);
    DWB.command(ctx.id,"apply"); assert(ctx.state=="applied"); assert(delivered,"No native damage result");
    assert(postCount==0,"Accepted dice were post-processed again at Apply");
    assert(ActionsManager.total(delivered)==total and delivered.nMod==accepted.nMod,"Native/chat total differs from panel");
    assert(#delivered.aDice==#accepted.aDice);
    for i,d in ipairs(accepted.aDice) do
      assert(delivered.aDice[i].result==d.value and delivered.aDice[i].value==d.value and delivered.aDice[i].type==d.type,"Accepted die changed at Apply");
    end
    assert(DB.getValue(targetPath..".wounds",0)-before==total,"Native wounds differ from accepted total");
    log("PASS mixed sorted dice, critical dice and single reroll match native/chat dice and wounds exactly: "..total);
    log("EXACT SUITE COMPLETE");
  end);
  ActionsManager.roll=oldRoll; ActionDamageD20.notifyApplyDamage=oldNotify;
  ActionsManager.registerResultHandler("damage",oldResult); ActionsManager.registerPostRollHandler("damage",oldPost);
  if not ok then error(err); end
end

function suite()
  uiSuite(); dropSuite(); exactSuite(); log("SUITE COMPLETE");
end

function preferenceSuite()
  local original=OptionsManager.getOption("DWB_ENABLED");
  local success,err=pcall(function()
    OptionsManager.setOption("DWB_ENABLED","off");
    assert(CampaignRegistry.OptDWB_ENABLED=="off" and not DWBPreferences.enabled(""));
    local before=#DWB.approvals(); execute("weapon");
    assert(#DWB.approvals()==before,"disabled user still queued damage");
    OptionsManager.setOption("DWB_ENABLED","on"); execute("weapon");
    assert(#DWB.approvals()==before+1,"enabled user did not queue damage");
    OptionsManager.setOption("DWB_ENABLED","off");
    assert(#DWB.approvals()==0,"disabling did not dismiss approval requests");
    log("PASS local user option: Off preserves native attack without DWB; On queues; saved in CampaignRegistry");
  end);
  OptionsManager.setOption("DWB_ENABLED",original);
  if not success then error(err); end
end

function directCantripSuite()
  local original=OptionsManager.getOption("DWB_ENABLED");
  OptionsManager.setOption("DWB_ENABLED","on");
  local originalRoll=ActionsManager.roll; local launched=0;
  ActionsManager.roll=function(...) launched=launched+1; end;
  local success,err=pcall(function()
    local source=assert(getActor("blessed strikes")); local chosen;
    for _,power in ipairs(DB.getChildList(ActorManager.getCreatureNode(source),"powers")) do
      if DB.getValue(power,"level",-1)==0 and DB.getValue(power,"group",""):lower():find("spell",1,true) then
        for _,action in ipairs(DB.getChildList(power,"actions")) do
          if DB.getValue(action,"type","")=="damage" then chosen=action; end
        end
        if chosen then break; end
      end
    end
    assert(chosen,"No damaging cantrip action");
    local target=ActorManager.resolveActor(targetPath);
    local action=PowerManager.getPowerAction(chosen,{rActor=source});
    PowerManager.evalAction(source,DB.getChild(chosen,"..."),action);
    local function drop()
      local roll=ActionDamageD20.getRoll(source,DWBModel.copy(action));
      assert(roll.sDWBPath==DB.getPath(chosen),"damage path metadata missing");
      ActionsManager.actionDirect(source,"damage",{roll},{{target}});
    end
    local before=#DWB.approvals(); drop();
    assert(#DWB.approvals()==before+1 and launched==0,"direct damage bypassed workbench");
    local matched;
    for _,ctx in ipairs(DWB.approvals()) do if ctx.damagePath==DB.getPath(chosen) then matched=ctx; end end
    assert(matched and matched.target==targetPath,"selected action or drop target lost");
    drop(); assert(#DWB.approvals()==before+1 and launched==0,"duplicate direct damage");
    DWB.reject(matched.id);
    log("PASS native direct cantrip targeting: selected action retained, no native roll, no duplicate request");
  end);
  ActionsManager.roll=originalRoll;
  OptionsManager.setOption("DWB_ENABLED",original);
  if not success then error(err); end
end

function dropSuite()
  execute("paladin");
  local ctx; for _,c in ipairs(DWB.approvals()) do if c.id==lastId then ctx=c; end end
  assert(ctx,"No paladin fixture"); DWB.approve(ctx.id);
  local p=DWBModel.copy(ctx.plan);
  assert(not p.suggestions and not next(p.claims),"Class damage was inferred automatically");
  log("PASS no class-damage suggestions or inferred additions");
  local target=DB.findNode(targetPath); local oldType=DB.getValue(target,"type","");
  local source=ActorManager.resolveActor(ctx.source);
  local power=DB.createChild(DB.createChild(ActorManager.getCreatureNode(source),"powers"));
  DB.setValue(power,"name","string","DWB Branding fixture"); DB.setValue(power,"upcast","number",2);
  local action=DB.createChild(DB.createChild(power,"actions")); DB.setValue(action,"type","string","effect");
  local countBefore=#ActorEffectManager.getCombatantEffectNodes(source);
  local success,err=pcall(function()
    local function count(clauses)
      local n=0; for _,c in ipairs(clauses) do n=n+#c.dice; end return n;
    end
    local smite={sName="$ Divine Smite (lvl 1); DMG: 2d8 radiant, melee; IFT: TYPE(undead, fiend); DMG: 1d8 radiant, melee"};
    for _,kind in ipairs({"humanoid","fiend","undead"}) do
      DB.setValue(target,"type","string",kind);
      local c=DWBEffectDrop.clauses(ctx,smite);
      assert(count(c)==(kind=="humanoid" and 2 or 3),kind.." smite dice incorrect");
      for _,v in ipairs(c) do assert(v.dmgtype:find("radiant",1,true)); end
    end
    log("PASS native IFT TYPE: humanoid 2d8, fiend/undead 3d8 radiant");
    DB.setValue(target,"type","string","humanoid");
    local branch={sName="Branches; IFT: TYPE(fiend); DMG: 1d6 fire; ELSE; DMG: 1d4 cold"};
    local branched=DWBEffectDrop.clauses(ctx,branch);
    assert(count(branched)==1 and branched[1].dmgtype=="cold","native ELSE failed");
    branch.sName="Conjunction; IFT: TYPE(humanoid) AND !TYPE(undead); DMG: 1d4 cold";
    assert(count(DWBEffectDrop.clauses(ctx,branch))==1,"native AND/inversion failed");
    log("PASS native ELSE, AND and inverted conditionals");
    local oldRange=ctx.range; ctx.range="R";
    local oldPrepared=ctx.prepared; ctx.prepared=nil;
    assert(count(DWBEffectDrop.clauses(ctx,smite))==0,"melee filter ignored");
    ctx.range=oldRange; ctx.prepared=oldPrepared;
    local c=DWBEffectDrop.clauses(ctx,{sName="Sneak Attack; DMG: 2d6 weapon;"});
    assert(count(c)==2 and c[1].dmgtype==ctx.action.clauses[1].dmgtype,"weapon damage inheritance failed");
    c=DWBEffectDrop.clauses(ctx,{sName="€ Improved Divine Smite; DMG: 1d8 radiant, melee"});
    assert(count(c)==1 and c[1].dmgtype:find("radiant",1,true));
    log("PASS weapon inheritance and Improved Divine Smite drop");
    c=DWBEffectDrop.clauses(ctx,{sName="Branding Smite (Caster); (C); DMG: {_[UPCAST]+2_}d6 radiant",actionPath=DB.getPath(action)});
    assert(count(c)==4,"native UPCAST arithmetic failed");
    log("PASS native UPCAST + expression produces 4d6 radiant");
    DB.setValue(target,"type","string","fiend");
    DWBModel.setCritical(p,true); local normal=DWBModel.zone(p,"slashing","normal",true);
    DWBModel.addDice(p,normal.id,{"d4"}); local normalId=normal.id;
    local dropWindow=Interface.findWindow("dwb_panel",""); dropWindow.setPlan(p);
    local effectText=EffectManager.encodeEffectAsText(smite);
    local drag={getType=function() return "effect"; end,getStringData=function() return effectText; end,
      getSecret=function() return false; end,getShortcutList=function() return {{recordname=ctx.source}}; end,
      getMetaData=function() return nil; end,getMetaDataList=function() return {}; end,getSlotCount=function() return 1; end,setSlot=function() end,
      getSlotType=function() return "effect"; end,getNumberData=function() return 0; end,getDiceData=function() return {}; end};
    assert(DWB.drop(dropWindow,drag),"effect drag not accepted");
    p=DWBModel.copy(ctx.plan);
    assert(#DWBModel.zone(p,"radiant","critical").dice==3);
    assert(#DWBModel.findZone(p,normalId).dice==1,"drop moved noncritical dice");
    assert(#ActorEffectManager.getCombatantEffectNodes(source)==countBefore,"drop applied a real effect");
    local w=Interface.findWindow("dwb_panel","");
    for _,t in ipairs(DWBModel.TYPES) do DWBModel.zone(p,t,"critical",true); end
    w.setPlan(p); local host=w.getZoneControl(p.zones[1].id);
    w.setScrollOffset(0); w.scrollZones(37);
    assert(w.getZoneControl(p.zones[1].id)==host and w.getScrollOffset()==37,"scroll paginates or recreates controls");
    local before=w.getScrollOffset(); w.hscroll.onClickDown(1,320,7); w.hscroll.onClickRelease(1,320,7);
    assert(w.getScrollOffset()~=before,"scrollbar track does not scroll");
    log("PASS continuous horizontal scrolling retains control identities");
    local localChat,broadcast=0,0;
    local oldLocal,oldDeliver=Comm.addChatMessage,Comm.deliverChatMessage;
    Comm.addChatMessage=function(m) if m.shortcuts and m.shortcuts[1].recordname==DWB.linkPath(p.id) then localChat=localChat+1; end end;
    Comm.deliverChatMessage=function() broadcast=broadcast+1; end;
    local closed,closeError=pcall(function() w.close(); DWB.reopen(p.id); Interface.findWindow("dwb_panel","").close(); end);
    Comm.addChatMessage=oldLocal; Comm.deliverChatMessage=oldDeliver;
    assert(closed,closeError); assert(localChat==2 and broadcast==0,"close reminder was missing or broadcast");
    Interface.openWindow("dwb_reopen",DWB.linkPath(p.id));
    assert(Interface.findWindow("dwb_panel","").getPlan().id==p.id,"chat window link did not reopen the request");
    log("PASS every unapplied close emits one local reopen link only");
    DWB.reopen(p.id);
    log("DROP SUITE COMPLETE");
  end);
  DB.setValue(target,"type","string",oldType); DB.deleteNode(power);
  if not success then error(err); end
end
