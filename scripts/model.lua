-- Original Damage Workbench code. No ruleset or third-party source is bundled.
-- Pure state model: no DB, network, UI, or random-number side effects.
TYPES = { "acid", "bludgeoning", "cold", "fire", "force", "lightning",
  "necrotic", "piercing", "poison", "psychic", "radiant", "slashing", "thunder", "untyped" };
MAX_DICE = 240;
MAX_ZONES = 28;

function copy(v)
  if type(v) ~= "table" then return v; end
  local out = {};
  for k, x in pairs(v) do out[k] = copy(x); end
  return out;
end

function contains(t, value)
  for _, v in ipairs(t or {}) do if v == value then return true; end end
  return false;
end

function dieType(d)
  local s = type(d) == "table" and d.type or d;
  if type(s) ~= "string" then return nil; end
  local sides = tonumber(s:match("^[dgrbp](%d+)$"));
  if not contains({2, 3, 4, 6, 8, 10, 12, 20, 100}, sides) then return nil; end
  return "d" .. sides;
end

function new(label)
  return { version = 1, label = label or "Damage", critical = false, magical = false,
    phase = "edit", zones = {}, serial = 0, revision = 0, rerolls = 0, claims = {} };
end

function touch(p)
  p.revision = (p.revision or 0) + 1;
end

function sortDice(p)
  if p.phase ~= "edit" then return; end
  for _, z in ipairs(p.zones) do
    local ordered = {};
    for i, die in ipairs(z.dice) do table.insert(ordered, { die = die, order = i }); end
    table.sort(ordered, function(a, b)
      local x, y = tonumber((dieType(a.die) or "d0"):sub(2)), tonumber((dieType(b.die) or "d0"):sub(2));
      if x == y then return a.order < b.order; end
      return x < y;
    end);
    for i, entry in ipairs(ordered) do z.dice[i] = entry.die; end
  end
end

function zone(p, dtype, side, create)
  side = side or "normal";
  for _, z in ipairs(p.zones) do
    if z.dtype == dtype and z.side == side then return z; end
  end
  if not create or #p.zones >= MAX_ZONES then return nil; end
  p.serial = p.serial + 1;
  local z = { id = p.serial, dtype = dtype, side = side, modifier = 0, dice = {} };
  table.insert(p.zones, z);
  return z;
end

function findZone(p, id)
  for _, z in ipairs(p.zones) do if z.id == id then return z; end end
end

function availableTypes(p, id, side)
  local out = {};
  for _, dtype in ipairs(TYPES) do
    local used = false;
    for _, z in ipairs(p.zones) do
      if z.id ~= id and z.side == side and z.dtype == dtype then used = true; end
    end
    if not used then table.insert(out, dtype); end
  end
  return out;
end

function removeZone(p, id)
  if p.phase ~= "edit" then return false; end
  for i, z in ipairs(p.zones) do
    if z.id == id then table.remove(p.zones, i); touch(p); return true; end
  end
  return false;
end

function countDice(p)
  local n = 0;
  for _, z in ipairs(p.zones) do n = n + #z.dice; end
  return n;
end

function addDice(p, id, dice, extra)
  if p.phase ~= "edit" then return false; end
  local z = findZone(p, id);
  if not z or countDice(p) + #dice > MAX_DICE then return false; end
  local clean = {};
  for _, v in ipairs(dice) do
    local s = dieType(v);
    if not s then return false; end
    local d = type(v) == "table" and copy(v) or { type = s };
    d.type = s; d.result = nil; d.value = nil;
    d.criticalOnly = extra == true;
    table.insert(clean, d);
  end
  for _, d in ipairs(clean) do table.insert(z.dice, d); end
  sortDice(p);
  touch(p); return true;
end

-- Append without reclassifying dice the user already placed in Non-critical.
function appendClauses(p, clauses)
  if p.phase~="edit" then return false; end
  local addition=new();
  local ok,err=importClauses(addition,clauses);
  if not ok then return false,err; end
  if p.critical then setCritical(addition,true); end
  if countDice(p)+countDice(addition)>MAX_DICE then return false,"Too many damage dice"; end
  local out=copy(p);
  for _,z in ipairs(addition.zones) do
    local dest=zone(out,z.dtype,z.side,true);
    if not dest then return false,"Too many damage types"; end
    for _,d in ipairs(z.dice) do table.insert(dest.dice,copy(d)); end
    dest.modifier=dest.modifier+z.modifier;
    dest.extraCritDice=math.max(dest.extraCritDice or 0,z.extraCritDice or 0);
    if #dest.dice==#z.dice then dest.tags=copy(z.tags); end
  end
  sortDice(out); touch(out);
  p.zones=out.zones; p.serial=out.serial; p.revision=out.revision;
  return true;
end

function parseType(s)
  local primary, tags = nil, {};
  for tag in (s or ""):lower():gmatch("[^,]+") do
    tag = tag:match("^%s*(.-)%s*$");
    if contains(TYPES, tag) and not primary then primary = tag;
    elseif tag ~= "critical" and tag ~= "" then table.insert(tags, tag); end
  end
  return primary or "untyped", tags;
end

function importClauses(p, clauses)
  if p.phase ~= "edit" then return false; end
  local incoming = 0;
  for _, c in ipairs(clauses or {}) do
    for _, d in ipairs(c.dice or {}) do
      if not dieType(d) then return false, "This action uses an unsupported custom or signed die"; end
      incoming = incoming + 1;
    end
  end
  if incoming + countDice(p) > MAX_DICE then return false, "Too many damage dice"; end
  for _, c in ipairs(clauses or {}) do
    local dtype, tags = parseType(c.dmgtype);
    local extra = (c.dmgtype or ""):match("critical") ~= nil;
    if not extra or not c.bCritical then
      local z = zone(p, dtype, "normal", true);
      if z then
        local dice = {};
        for _, v in ipairs(c.dice or {}) do
          local d = type(v) == "table" and copy(v) or { type = v };
          d.tags = copy(tags); d.nMin = c.nMin; d.nReroll = c.nReroll;
          d.bMax = c.bMax;
          d.bRerollNoLimit = c.bRerollNoLimit;
          table.insert(dice, d);
        end
        addDice(p, z.id, dice, extra);
        z.modifier = z.modifier + (c.modifier or 0);
        z.tags = copy(tags);
        z.extraCritDice = math.max(z.extraCritDice or 0, c.nExtraCritDice or 0);
      end
    end
  end
  touch(p); return true;
end

function setCritical(p, enabled)
  if p.phase ~= "edit" or p.critical == enabled then return false; end
  if enabled then
    local before = copy(p.zones);
    p.zones = {};
    for _, z in ipairs(before) do
      z.side = "critical";
      local nMod = z.modifier;
      z.modifier = 0;
      table.insert(p.zones, z);
      if nMod ~= 0 then
        local fixed = zone(p, z.dtype, "normal", true);
        fixed.modifier = fixed.modifier + nMod;
        fixed.tags = copy(z.tags);
        fixed.featureMods = copy(z.featureMods);
        z.featureMods = nil;
      end
    end
  else
    local before = copy(p.zones);
    p.zones = {};
    for _, z in ipairs(before) do
      local dst = zone(p, z.dtype, "normal", true);
      dst.modifier = dst.modifier + z.modifier;
      dst.tags = dst.tags or copy(z.tags);
      dst.extraCritDice = math.max(dst.extraCritDice or 0, z.extraCritDice or 0);
      if z.featureMods then
        dst.featureMods = dst.featureMods or {};
        for key, n in pairs(z.featureMods) do dst.featureMods[key] = (dst.featureMods[key] or 0) + n; end
      end
      for _, d in ipairs(z.dice) do
        if not d.criticalOnly then table.insert(dst.dice, d); end
      end
    end
  end
  p.critical = enabled;
  sortDice(p);
  touch(p); return true;
end

function moveDice(p, from, into, indices)
  if p.phase ~= "edit" or from == into then return false; end
  local a, b = findZone(p, from), findZone(p, into);
  if not a or not b then return false; end
  local moving = {};
  for _, i in ipairs(indices) do if a.dice[i] then table.insert(moving, copy(a.dice[i])); end end
  removeDice(p, from, indices);
  for _, d in ipairs(moving) do table.insert(b.dice, d); end
  sortDice(p);
  touch(p); return true;
end

function removeDice(p, id, indices)
  if p.phase ~= "edit" then return false; end
  local z = findZone(p, id);
  if not z then return false; end
  local remove = {};
  for _, i in ipairs(indices) do remove[i] = true; end
  for i = #z.dice, 1, -1 do if remove[i] then table.remove(z.dice, i); end end
  touch(p); return true;
end

function valid(p)
  if type(p) ~= "table" or type(p.zones) ~= "table" or #p.zones > MAX_ZONES then return false, "Invalid damage plan"; end
  if type(p.critical) ~= "boolean" or type(p.magical) ~= "boolean" then return false, "Invalid damage options"; end
  if p.claims ~= nil and type(p.claims) ~= "table" then return false, "Invalid feature claims"; end
  if p.choices ~= nil and type(p.choices) ~= "table" then return false, "Invalid feature choices"; end
  for _, list in ipairs({ p.claims or {}, p.choices or {} }) do
    for key, claim in pairs(list) do
      if type(key) ~= "string" or type(claim) ~= "table" then return false, "Invalid feature claim"; end
      if claim.slot and (type(claim.slot) ~= "number" or claim.slot < 1 or claim.slot > 5 or claim.slot ~= math.floor(claim.slot)) then return false, "Invalid spell slot"; end
    end
  end
  if type(p.serial) ~= "number" or p.serial < 0 or p.serial > 100000 or p.serial ~= math.floor(p.serial) then return false, "Invalid zone identifiers"; end
  local nDice, nFixed, used = 0, 0, {};
  for _, z in ipairs(p.zones) do
    if type(z) ~= "table" or type(z.id) ~= "number" or z.id ~= math.floor(z.id) then return false, "Invalid zone"; end
    if not contains(TYPES, z.dtype) then return false, "Choose a damage type for every zone"; end
    if z.side ~= "normal" and z.side ~= "critical" then return false, "Invalid damage group"; end
    if not p.critical and z.side ~= "normal" then return false, "Critical group is disabled"; end
    local key = z.side .. ":" .. z.dtype;
    if used[key] then return false, "Duplicate damage type in group"; end
    used[key] = true;
    if type(z.modifier) ~= "number" or z.modifier ~= math.floor(z.modifier) or math.abs(z.modifier) > 9999 then return false, "Invalid fixed damage"; end
    if p.critical and z.side == "critical" and z.modifier ~= 0 then return false, "Fixed damage belongs in non-critical group"; end
    if type(z.dice) ~= "table" then return false, "Invalid dice"; end
    if z.extraCritDice and (type(z.extraCritDice) ~= "number" or z.extraCritDice < 0 or z.extraCritDice > 10 or z.extraCritDice ~= math.floor(z.extraCritDice)) then return false, "Invalid extra critical dice"; end
    nFixed = nFixed + math.abs(z.modifier);
    for _, d in ipairs(z.dice) do
      if type(d) ~= "table" or not dieType(d) then return false, "Unsupported die"; end
      nDice = nDice + 1;
    end
  end
  if nDice > MAX_DICE then return false, "Too many dice"; end
  if nDice == 0 and nFixed == 0 then return false, "Add damage before rolling"; end
  return true;
end

function typeText(z, d, critical, magical)
  local tags = { z.dtype == "untyped" and "" or z.dtype };
  for _, s in ipairs((d and d.tags) or z.tags or {}) do
    if s ~= "magic" and s ~= "magical" and s ~= "critical" and not contains(tags, s) then table.insert(tags, s); end
  end
  if magical then table.insert(tags, "magic"); end
  if critical then table.insert(tags, "critical"); end
  return table.concat(tags, ","):gsub("^,", "");
end

function buildRoll(p)
  local ok, err = valid(p);
  if not ok then return nil, err; end
  local r = { sType = "dwbstage", sDesc = "[DAMAGE] " .. (p.label or "Damage"),
    aDice = {}, nMod = 0, clauses = {}, mapping = {}, bCritical = p.critical };
  for key, value in pairs(p.flags or {}) do r[key] = value; end
  local function append(z, d, isCrit, index)
    local dmgtype = typeText(z, d, isCrit, p.magical);
    local die = copy(d); die.type = dieType(d); die.result = nil; die.value = nil;
    if isCrit then die.type = "g" .. die.type:sub(2); end
    table.insert(r.aDice, die);
    table.insert(r.clauses, { dmgtype = dmgtype, dice = { die.type }, modifier = 0, nMin = d.nMin, bMax = d.bMax });
    table.insert(r.mapping, { zone = z.id, index = index, critical = isCrit });
  end
  for _, z in ipairs(p.zones) do
    r.nMod = r.nMod + z.modifier;
    if z.modifier ~= 0 then table.insert(r.clauses, { dmgtype = typeText(z, nil, false, p.magical), dice = {}, modifier = z.modifier }); end
    local best, bestIndex;
    for i, d in ipairs(z.dice) do
      if not d.criticalOnly then
        append(z, d, false, i);
        if p.critical and z.side == "critical" then append(z, d, true, i); end
      elseif p.critical then append(z, d, true, i); end
      local sides = tonumber(dieType(d):sub(2));
      if not best or sides > tonumber(dieType(best):sub(2)) then best = d; bestIndex = i; end
    end
    if best and p.critical and z.side == "critical" then
      for _ = 1, z.extraCritDice or 0 do append(z, best, true, bestIndex); end
    end
  end
  return r;
end

function recordResults(p, roll)
  local expected, err = buildRoll(p);
  if not expected then return false, err; end
  if #(roll.aDice or {}) ~= #expected.aDice then return false, "Dice count mismatch"; end
  for i, d in ipairs(roll.aDice or {}) do
    local want = expected.aDice[i];
    local value = d.value or d.result;
    if dieType(d) ~= dieType(want) or type(value) ~= "number" or value ~= math.floor(value) or value < 1 or value > tonumber(dieType(d):sub(2)) then return false, "Invalid die result"; end
    want.result = value; want.value = value;
    if (p.flags and p.flags.bModMax) or want.bMax then want.value = tonumber(dieType(want):sub(2));
    elseif want.nMin then want.value = math.max(want.value, math.min(want.nMin, tonumber(dieType(want):sub(2)))); end
    want.diceskin = d.diceskin; want.dicebodycolor = d.dicebodycolor; want.dicetextcolor = d.dicetextcolor;
    want.result = want.value;
  end
  expected.mapping = expected.mapping or {};
  p.roll = expected; p.phase = "results"; p.rerolls = p.rerolls or 0;
  touch(p); return true;
end

function total(p, zoneId)
  local n = 0;
  for _, z in ipairs(p.zones) do if not zoneId or z.id == zoneId then n = n + z.modifier; end end
  for i, m in ipairs(p.roll and p.roll.mapping or {}) do
    if not zoneId or m.zone == zoneId then local d = p.roll.aDice[i]; n = n + (d.value or d.result or 0); end
  end
  return math.max(0, n);
end

function undo(p)
  if p.phase ~= "results" then return false; end
  p.roll = nil; p.phase = "edit"; touch(p); return true;
end

function reroll(p, index, value)
  if p.phase ~= "results" or not p.roll or not p.roll.aDice[index] then return false; end
  local d = p.roll.aDice[index];
  if type(value) ~= "number" or value ~= math.floor(value) or value < 1 or value > tonumber(dieType(d):sub(2)) then return false; end
  d.result = value; d.value = value;
  if (p.flags and p.flags.bModMax) or d.bMax then d.value = tonumber(dieType(d):sub(2));
  elseif d.nMin then d.value = math.max(d.value, math.min(d.nMin, tonumber(dieType(d):sub(2)))); end
  d.result = d.value;
  p.rerolls = (p.rerolls or 0) + 1; touch(p); return true;
end

function preset(p, name)
  return { version = 1, label = name or p.label, critical = p.critical, magical = p.magical,
    zones = copy(p.zones), serial = p.serial, choices = copy(p.choices or p.claims or {}) };
end

function replace(p, saved)
  if p.phase ~= "edit" or type(saved) ~= "table" or saved.version ~= 1 then return false; end
  local t = copy(saved); t.phase = "edit";
  local ok = valid(t);
  if not ok then return false; end
  p.zones = t.zones; p.serial = t.serial; p.critical = t.critical; p.magical = t.magical;
  -- A preset is a layout, never authority to spend a feature again.
  p.claims = {}; p.roll = nil; p.rerolls = 0;
  p.choices = copy(t.choices or {});
  sortDice(p);
  touch(p); return true;
end
