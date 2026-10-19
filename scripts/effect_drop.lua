-- Evaluate a dropped effect without adding it to the combat tracker. All
-- expression, conditional and descriptor rules come from the installed ruleset.
function actionNode(source, effect)
  local node = effect.actionPath and DB.findNode(effect.actionPath);
  local root = ActorManager.getCreatureNodeName(source) .. ".";
  if node and DB.getPath(node):sub(1,#root)==root and DB.getValue(node,"type","")=="effect" then return node; end
  local title = (effect.sName or ""):match("^([^;]+)") or "";
  local found;
  for _,power in ipairs(DB.getChildList(ActorManager.getCreatureNode(source),"powers")) do
    local name = DB.getValue(power,"name","");
    if name~="" and title:lower():find(name:lower(),1,true) then
      for _,action in ipairs(DB.getChildList(power,"actions")) do
        if DB.getValue(action,"type","")=="effect" then
          if found then return nil; end
          found=action;
        end
      end
    end
  end
  return found;
end

function clauses(ctx, effect, critical)
  local source,target=ActorManager.resolveActor(ctx.source),ActorManager.resolveActor(ctx.target);
  if not source or not target then error("Effect drops require the attack's source and target"); end
  local e={sName=effect.sName,sSource=effect.sSource or ctx.sourceCT};
  e.nodeAction=actionNode(EffectManager.getSourceActor(e) or source,effect);
  if e.sName:find("[UPCAST]",1,true) and not e.nodeAction then
    error("Drop the effect action from the caster's power so its upcast value is available");
  end
  -- Includes installed overrides and native [_] variables / {_expression_} math.
  EffectManager.onEffectEval(source,e);
  if e.sName:find("{_",1,true) or e.sName:find("%[[A-Z]+%]") then error("Unresolved effect expression"); end
  local filter=DWBModel.copy(ctx.prepared and ctx.prepared.tEffectFilter or {});
  if ctx.weapon then table.insert(filter,"weapon"); end
  if ctx.cantrip then table.insert(filter,"spell"); end
  if ctx.range=="M" then table.insert(filter,"melee"); elseif ctx.range=="R" then table.insert(filter,"ranged"); end
  local check=EffectQueryManager.checkDataBuild(source,"DMG",false,{rTarget=target,tFilter=filter,
    tActionTags=ctx.prepared and ctx.prepared.tActionTags,bIgnoreExpire=true});
  -- A real node supplies an identity to native conditional recursion checks;
  -- no node is created and no existing effect is activated, expired or changed.
  check.tEffectsData={{node=ActorManager.getCreatureNode(source),sLabel=e.sName,nActive=1}};
  check.nEffectCheck=1;
  EffectQueryManager.checkDataComps(check);
  local matches=EffectQueryManager.getCheckCompResults(check);
  local bonuses={};
  for _,c in ipairs(matches) do
    local key=EffectQueryManager.getBonusKeyAndGroupFromList(c.remainder) or "";
    local b=bonuses[key] or {dice={},mod=0}; bonuses[key]=b;
    for _,d in ipairs(c.dice) do table.insert(b.dice,d); end
    b.mod=b.mod+c.mod;
  end
  local base=DWBModel.copy(ctx.action.clauses or {});
  if #base==0 then base={{dmgtype=ctx.action.dmgtype or "",dice={}}}; end
  local r={clauses={base[1]},aDice={},nMod=0,nEffectMod=0,tEffectDice={},bCritical=critical==true};
  ActionDamageD20.applyModDmgEffectsBonus(r,bonuses);
  table.remove(r.clauses,1);
  return r.clauses;
end

function import(ctx, plan, effect)
  if type(effect)~="table" or type(effect.sName)~="string" or #effect.sName>12000 then return nil,"Invalid effect drop"; end
  local ok, clausesOrError=pcall(clauses,ctx,effect,plan.critical);
  if not ok then return nil,tostring(clausesOrError); end
  if #clausesOrError==0 then return nil,"This effect adds no damage for this attack and target"; end
  local p=DWBModel.copy(plan);
  local imported,err=DWBModel.appendClauses(p,clausesOrError);
  if not imported then return nil,err; end
  return p;
end
