-- Session turn/reroll accounting and legacy saved-layout claim validation.
local ledger = {};
local turn = 0;
local actorTurns = {};
local active = "";
local rerolls = {};

function onTurnChanged()
  if not Session.IsHost then return; end
  local now = "";
  for _, ct in ipairs(DB.getChildList("combattracker.list")) do
    if DB.getValue(ct, "active", 0) == 1 then now = DB.getPath(ct); break; end
  end
  if now ~= active then
    active = now; turn = turn + 1;
    if now ~= "" then actorTurns[now] = (actorTurns[now] or 0) + 1; end
  end
end

function stamp(ctx, scope)
  if scope == "ownturn" then return actorTurns[ctx.sourceCT] or 0; end
  return turn;
end

function available(ctx, key, scope)
  local used = ledger[ctx.source .. ":" .. key];
  return not used or used ~= tostring(stamp(ctx, scope));
end

function commit(ctx, plan)
  local present = {};
  for _, z in ipairs(plan.zones) do
    for _, die in ipairs(z.dice) do if die.feature then present[die.feature] = true; end end
    for key, amount in pairs(z.featureMods or {}) do
      if amount ~= 0 and z.modifier >= amount then present[key] = true; end
    end
  end
  for key, claim in pairs(plan.claims or {}) do
    if present[key] and claim.scope then
      ledger[ctx.source .. ":" .. key] = tostring(stamp(ctx, claim.scope));
    end
  end
end

function validateClaims(ctx, plan)
  for key, claim in pairs(plan.claims or {}) do
    if claim.scope and not available(ctx, key, claim.scope) then
      return false, key .. " has already been used in this turn";
    end
    if claim.slot then
      local base = ctx.source .. ".powermeta.spellslots" .. claim.slot;
      if DB.getValue(base .. ".used", 0) >= DB.getValue(base .. ".max", 0) then return false, "Spell slot is no longer available"; end
    end
  end
  return true;
end

function presentFeatures(plan)
  local present = {};
  for _, z in ipairs(plan.zones or {}) do
    for _, die in ipairs(z.dice or {}) do if die.feature then present[die.feature] = true; end end
    for key, amount in pairs(z.featureMods or {}) do
      if amount ~= 0 and z.modifier >= amount then present[key] = true; end
    end
  end
  return present;
end

function pruneClaims(plan)
  local present = presentFeatures(plan);
  for key in pairs(plan.claims or {}) do if not present[key] then plan.claims[key] = nil; end end
end

function spendSlots(ctx, plan)
  for _, claim in pairs(plan.claims or {}) do
    if claim.slot then
      local base = ctx.source .. ".powermeta.spellslots" .. claim.slot;
      DB.setValue(base .. ".used", "number", DB.getValue(base .. ".used", 0) + 1);
    end
  end
end

function rerollCount(ctx)
  local key = ctx.source .. ":" .. turn;
  return rerolls[key] or 0;
end

function countReroll(ctx)
  local key = ctx.source .. ":" .. turn;
  rerolls[key] = (rerolls[key] or 0) + 1;
  return rerolls[key];
end

function inspect(rActor)
  local node = ActorManager.getCreatureNode(rActor);
  local data = { features = {}, feats = {}, levels = {}, texts = {} };
  for _, list in ipairs({ "featurelist", "featlist" }) do
    for _, item in ipairs(DB.getChildList(node, list)) do
      local name = DB.getValue(item, "name", ""):lower();
      local key = name:gsub("%s*%b()", ""):gsub("%s+$", "");
      if list == "featurelist" then data.features[key] = true; else data.feats[key] = true; end
      data.texts[key] = DB.getText(item, "text", ""):lower();
    end
  end
  for _, item in ipairs(DB.getChildList(node, "classes")) do
    data.levels[DB.getValue(item, "name", ""):lower()] = DB.getValue(item, "level", 0);
  end
  return data;
end

function alreadyEffect(rActor, feature)
  local nodes = ActorEffectManager.getCombatantEffectNodes(rActor);
  for _, n in ipairs(ActorEffectManager.getActiveEffectNodes(rActor)) do table.insert(nodes, n); end
  for _, node in ipairs(nodes) do
    if DB.getValue(node, "isactive", 1) ~= 0 then
      local name = DB.getValue(node, "label", DB.getValue(node, "effect", "")):lower();
      local label = (name:match("^([^;]+)") or name):gsub("%s*%b()", ""):match("^%s*(.-)%s*$");
      if label == feature then return true; end
    end
  end
  -- Equipped Effects / Advanced Effects may keep action-only effects under Abilities.
  for _, node in ipairs(DB.getChildList(ActorManager.getCreatureNode(rActor), "effectlist")) do
    local name = DB.getValue(node, "effect", DB.getValue(node, "label", "")):lower();
    local label = (name:match("^([^;]+)") or name):gsub("%s*%b()", ""):match("^%s*(.-)%s*$");
    if label == feature then return true; end
  end
  return false;
end

function add(p, key, dtype, dice, mod, scope)
  if p.phase ~= "edit" or p.claims[key] then return false; end
  local z = DWBModel.zone(p, dtype, p.critical and "critical" or "normal", true);
  if not z then return false; end
  local tDice = {};
  for _, s in ipairs(dice or {}) do table.insert(tDice, { type = s, feature = key }); end
  DWBModel.addDice(p, z.id, tDice);
  if (mod or 0) ~= 0 then
    local fixed = DWBModel.zone(p, dtype, "normal", true);
    fixed.modifier = fixed.modifier + mod;
    fixed.featureMods = fixed.featureMods or {}; fixed.featureMods[key] = mod;
  end
  p.claims[key] = { scope = scope };
  return true;
end

function repeatDie(n, die)
  local out = {}; for _ = 1, n do table.insert(out, die); end; return out;
end

-- Optional damage is added only through the native active-effect pipeline or explicit drops.
