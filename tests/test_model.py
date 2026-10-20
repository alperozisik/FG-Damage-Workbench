"""Run with Python + lupa. The test runtime never loads Fantasy Grounds."""
from pathlib import Path
import sys
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".private" / "python"))
from lupa.lua54 import LuaRuntime

class ModelTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.model = self.lua.table()
        self.lua.globals().DWBModel = self.model
        self.lua.execute("setmetatable(DWBModel, {__index = _G})")
        self.lua.execute("function loadModule(source, env) return assert(load(source, 'module', 't', env))() end")
        self.lua.globals().loadModule((ROOT / "scripts/model.lua").read_text(), self.model)

    def run_lua(self, source):
        self.lua.execute(source)

    def test_decoded_action_retains_per_die_reroll_and_skin(self):
        self.run_lua('''
          local M=DWBModel;
          local r={clauses={{dmgtype='radiant',dice={'d6'},modifier=0}},
            aDice={{type='d6',mode='r2#1',dicebodycolor='ABCDEF'}}};
          local p=M.new(); assert(M.importClauses(p,M.rollClauses(r)));
          local d=p.zones[1].dice[1];assert(d.nReroll==2 and not d.bRerollNoLimit and d.dicebodycolor=='ABCDEF');
          assert(r.clauses[1].dice[1]=='d6');
        ''')

    def test_native_discarded_rerolls_preserve_order_and_reject_invalid_chains(self):
        self.run_lua('''
          local M=DWBModel;local p=M.new();
          M.importClauses(p,{{dmgtype='fire',dice={{type='d6',mode='r2#1'},'d8'}}});
          local dice={{type='d6',result=1,dropped=true},{type='d6',result=2,iconcolor='FF123456'},{type='d8',result=7}};
          assert(M.recordResults(p,{aDice=dice}));
          assert(M.total(p)==9 and #p.roll.aDice==2 and #p.roll.aDice[1].rolls==2);
          assert(p.roll.aDice[1].iconcolor=='FF123456' and p.roll.aDice[2].value==7);
          assert(not M.resolveDice({{type='d6'}},dice));
          assert(not M.resolveDice({{type='d6',nReroll=2}},{{type='d6',result=3,dropped=true},{type='d6',result=4}}));
          assert(not M.resolveDice({{type='d6',nReroll=2}},{{type='d6',result=1,dropped=true},{type='d6',result=2,dropped=true},{type='d6',result=4}}));
          local repeated=M.resolveDice({{type='d6',nReroll=2,bRerollNoLimit=true}},{{type='d6',result=1,dropped=true},{type='d6',result=2,dropped=true},{type='d6',result=4}});
          assert(#repeated==1 and repeated[1].result==4 and #repeated[1].rolls==3);
        ''')

    def test_die_menu_thresholds_and_checked_state(self):
        self.run_lua('''
          dieUI={};setmetatable(dieUI,{__index=_G});
          DWBLayout={selectionSegment=function()return nil end};
          local calls={};local noop=function()end;
          dieUI.face={resetMenuItems=function()calls={}end,registerMenuItem=function(...)table.insert(calls,{...})end,
            setVisible=noop,addBitmapWidget=function()return {setColor=noop}end,addTextWidget=noop,setTooltipText=noop};
          dieUI.fixed={setVisible=noop};dieUI.highlight={setVisible=noop};
          local selected;testPanel={getPlan=function()return {phase='edit'}end,cancelDelete=noop,
            setAutoReroll=function(z,i,n)selected=n end};
          function checkMenu(sides,threshold)
            dieUI.setData(testPanel,{id=1},{type='d'..sides,nReroll=threshold},1,false,nil,false);
            return calls;
          end
          function menuSelected()return selected end
        ''')
        self.lua.globals().loadModule((ROOT / 'ui/die.lua').read_text(encoding='utf-8'),self.lua.globals().dieUI)
        self.run_lua('''
          local calls=checkMenu(6,0);assert(calls[1][3]==7 and calls[2][1]=='No auto reroll' and calls[2][2]=='button_checkon' and calls[2][4]==8);
          assert(calls[#calls][1]=='Delete dice' and calls[#calls][3]==6);
          dieUI.menuSelection(7,6);assert(menuSelected()==2);dieUI.menuSelection(7,8);assert(menuSelected()==0);
          calls=checkMenu(20,19);local values={};
          for _,c in ipairs(calls) do if c[5] then values[tonumber(c[1])]=true;if c[1]=='19' then assert(c[2]=='button_checkon');dieUI.menuSelection(c[3],c[4],c[5]);assert(menuSelected()==19);end end end
          for n=1,19 do assert(values[n]);end
          calls=checkMenu(100,0);assert(#calls==1 and calls[1][1]=='Delete dice');
        ''')

    def test_critical_toggle_merges_then_redistributes(self):
        self.run_lua('''
          local M=DWBModel; local p=M.new('Test');
          M.importClauses(p, {{dmgtype='piercing',dice={'d6'},modifier=5}});
          assert(M.setCritical(p,true));
          local a=M.zone(p,'piercing','critical'); local b=M.zone(p,'piercing','normal');
          assert(a.modifier==0 and b.modifier==5);
          M.addDice(p,b.id,{'d8'});
          assert(M.setCritical(p,false));
          assert(#p.zones==1 and #p.zones[1].dice==2 and p.zones[1].modifier==5);
          M.setCritical(p,true);
          assert(#M.zone(p,'piercing','critical').dice==2);
          assert(M.zone(p,'piercing','normal').modifier==5);
          local r=M.buildRoll(p); assert(#r.aDice==4 and r.nMod==5);
        ''')

    def test_noncritical_dice_not_doubled_and_critical_tag_preserved(self):
        self.run_lua('''
          local M=DWBModel; local p=M.new();
          M.importClauses(p, {{dmgtype='piercing,silver',dice={'d6'},modifier=5}});
          M.setCritical(p,true); p.magical=true;
          M.addDice(p,M.zone(p,'piercing','normal').id,{'d8'});
          local r=M.buildRoll(p); assert(#r.aDice==3 and r.nMod==5);
          local crit=0; for _,c in ipairs(r.clauses) do
            if c.dmgtype:find('critical') then crit=crit+1; assert(c.dmgtype:find('silver')); end
            assert(c.dmgtype:find('magic'));
          end; assert(crit==1);
        ''')

    def test_piercer_extra_die_is_not_doubled(self):
        self.run_lua('''
          local M=DWBModel; local p=M.new();
          M.importClauses(p, {{dmgtype='piercing',dice={'d8'},modifier=5,nExtraCritDice=1}});
          assert(#M.buildRoll(p).aDice==1); M.setCritical(p,true);
          assert(#M.buildRoll(p).aDice==3);
        ''')

    def test_undo_and_irreversible_reroll(self):
        self.run_lua('''
          local M=DWBModel; local p=M.new();
          M.importClauses(p, {{dmgtype='fire',dice={'d6'},modifier=3}});
          local r={aDice={{type='d6',result=4}}}; assert(M.recordResults(p,r)); assert(M.total(p)==7);
          assert(M.undo(p)); assert(p.phase=='edit'); assert(M.recordResults(p,r));
          assert(M.reroll(p,1,2)); assert(M.total(p)==5 and p.rerolls==1);
          assert(not M.reroll(p,1,7)); assert(M.total(p)==5);
          assert(M.undo(p)); assert(p.phase=='edit' and p.roll==nil and p.rerolls==1);
          assert(not M.reroll(p,1,4)); assert(M.recordResults(p,r)); assert(M.total(p)==7);
        ''')

    def test_blank_type_duplicate_and_result_forgery_rejected(self):
        self.run_lua('''
          local M=DWBModel; local p=M.new(); local z=M.zone(p,'','normal',true);
          M.addDice(p,z.id,{'d6'}); assert(not M.valid(p)); z.dtype='fire'; assert(M.valid(p));
          assert(not M.recordResults(p,{aDice={{type='d8',result=3}}}));
          assert(not M.recordResults(p,{aDice={{type='d6',result=7}}}));
          assert(not M.recordResults(p,{aDice={{type='d6',result=-1}}}));
          assert(not M.recordResults(p,{aDice={}}));
          table.insert(p.zones,M.copy(z)); assert(not M.valid(p));
        ''')

    def test_selection_move_delete_and_unique_choices(self):
        self.run_lua('''
          local M=DWBModel; local p=M.new();
          M.importClauses(p, {{dmgtype='piercing',dice={'d6','d8','d10'},modifier=5}});
          local a=p.zones[1]; local b=M.zone(p,'fire','normal',true);
          assert(not M.contains(M.availableTypes(p,a.id,'normal'),'fire'));
          M.moveDice(p,a.id,b.id,{1,3}); assert(#a.dice==1 and #b.dice==2);
          assert(a.dice[1].type=='d8'); M.removeDice(p,b.id,{1,2}); assert(#b.dice==0);
        ''')

    def test_preset_replaces_all_layout_without_authority(self):
        self.run_lua('''
          local M=DWBModel; local p=M.new();
          M.importClauses(p,{{dmgtype='fire',dice={'d6'},modifier=2}}); p.magical=true; M.setCritical(p,true);
          p.claims={['sneak attack']={scope='turn'}}; local saved=M.preset(p,'Saved');
          local other=M.new(); M.importClauses(other,{{dmgtype='cold',dice={'d10'},modifier=9}});
          assert(M.replace(other,saved)); assert(other.critical and other.magical);
          assert(not M.zone(other,'cold','normal')); assert(next(other.claims)==nil);
          assert(#M.buildRoll(other).aDice==2);
        ''')

    def test_all_lua_and_inline_xml_scripts_compile(self):
        compile_lua = self.lua.eval("function(s,n) local f,e=load(s,n); return f~=nil,e end")
        for path in list((ROOT / "scripts").glob("*.lua")) + list((ROOT / "ui").glob("*.lua")) + list((ROOT / "tests").glob("*.lua")):
            ok, error = compile_lua(path.read_text(encoding="utf-8"), str(path))
            self.assertTrue(ok, error)
        for path in ROOT.rglob("*.xml"):
            if any(part.startswith(".") for part in path.relative_to(ROOT).parts):
                continue
            for script in ET.parse(path).iter("script"):
                if script.text and script.text.strip():
                    ok, error = compile_lua(script.text, str(path))
                    self.assertTrue(ok, error)

    def test_unsupported_import_is_atomic_and_roll_flags_survive(self):
        self.run_lua('''
          local M=DWBModel; local p=M.new('Test');
          assert(M.importClauses(p,{{dmgtype='fire',dice={'d6'},modifier=2}}));
          local n=#p.zones; local count=M.countDice(p);
          assert(not M.importClauses(p,{{dmgtype='cold',dice={'d8','-d4'},modifier=3}}));
          assert(#p.zones==n and M.countDice(p)==count);
          p.flags={bModMax=true,bModHalf=true,bModDouble=true,nMult=2};
          local r=M.buildRoll(p); assert(r.bModMax and r.bModHalf and r.bModDouble and r.nMult==2);
        ''')

    def test_saved_slot_choice_is_declarative_and_invalid_claims_rejected(self):
        self.run_lua('''
          local M=DWBModel; local p=M.new();
          assert(M.importClauses(p,{{dmgtype='radiant',dice={'d8'},modifier=0}}));
          p.claims={['divine smite']={slot=2}};
          local s=M.preset(p,'Smite'); assert(s.choices['divine smite'].slot==2);
          local q=M.new(); assert(M.replace(q,s));
          assert(not next(q.claims) and q.choices['divine smite'].slot==2);
          q.choices='invalid'; assert(not M.valid(q)); q.choices={};
          q.claims={['divine smite']={slot=6}}; assert(not M.valid(q));
        ''')

    def load_layout(self):
        env = self.lua.table()
        self.lua.globals().DWBLayout = env
        self.lua.execute("setmetatable(DWBLayout, {__index = _G})")
        self.lua.globals().loadModule((ROOT / "scripts/layout.lua").read_text(), env)

    def test_stable_die_order_survives_move_critical_and_roll(self):
        self.run_lua('''
          local M=DWBModel; local p=M.new();
          M.importClauses(p,{{dmgtype='piercing',dice={'d20','d8','d6','d8'},modifier=6}});
          local z=p.zones[1]; assert(z.dice[1].type=='d6' and z.dice[4].type=='d20');
          z.dice[2].feature='first'; z.dice[3].feature='second';
          M.sortDice(p); assert(z.dice[2].feature=='first' and z.dice[3].feature=='second');
          M.setCritical(p,true); local r=M.buildRoll(p);
          assert(#r.aDice==8 and r.aDice[1].type=='d6' and r.aDice[2].type=='g6');
          assert(r.aDice[7].type=='d20' and r.aDice[8].type=='g20');
          for i,d in ipairs(r.aDice) do d.result=1; d.value=2; end
          assert(M.recordResults(p,r));
          for _,d in ipairs(p.roll.aDice) do assert(d.result==2 and d.value==2); end
          assert(M.reroll(p,2,4)); assert(p.roll.aDice[2].result==4 and p.roll.aDice[2].value==4);
          assert(M.total(p)==24);
        ''')

    def test_compact_groups_keep_both_sides_and_small_add_margin(self):
        self.load_layout()
        self.run_lua('''
          local M,L=DWBModel,DWBLayout; local p=M.new();
          M.importClauses(p,{{dmgtype='piercing',dice={'d8'},modifier=6}}); M.setCritical(p,true);
          local g=L.groups(p,472,true);
          assert(#g==2 and g[1].width==168 and g[2].width==168);
          assert(g[2].x==188 and g[2].x+g[2].width<=472);
          for _,t in ipairs(M.TYPES) do M.zone(p,t,'critical',true); M.zone(p,t,'normal',true); end
          local limit,content; g,limit,content=L.groups(p,472,true);
          assert(content>472 and limit==content-472);
          assert(g[2].x==g[1].width+L.GROUP_GAP);
        ''')

    def test_selection_connects_neighbors_without_crossing_rows_or_fixed_cell(self):
        self.load_layout()
        self.run_lua('''
          local p=DWBModel.new(); local z=DWBModel.zone(p,'fire','normal',true);
          DWBModel.addDice(p,z.id,{'d6','d6','d6','d6'});
          local selected=function(i) return i>=1 and i<=4; end;
          assert(DWBLayout.selectionSegment(p,z,1,selected)=='start');
          assert(DWBLayout.selectionSegment(p,z,2,selected)=='end');
          assert(DWBLayout.selectionSegment(p,z,3,selected)=='start');
          assert(DWBLayout.selectionSegment(p,z,4,selected)=='end');
        ''')

    def setup_features(self):
        self.lua.execute('''
          Session={IsHost=true};
          Store={}; Lists={};
          DB={
            getChildList=function(node,list) return Lists[tostring(node)..'.'..tostring(list or '')] or {} end,
            getValue=function(node,path,default)
              if default==nil then default=path; path=nil; end
              local k=tostring(node)..(path and '.'..path or '');
              if Store[k]~=nil then return Store[k]; end; return default;
            end,
            getText=function(node,path,default) return Store[tostring(node)..'.'..path] or default end,
            getPath=function(node) return node end
          };
          ActorManager={getCreatureNode=function(a) return a end,resolveActor=function(a)return a end};
          ActorEffectManager={getCombatantEffectNodes=function(a)return Lists[a..'.effects'] or {} end,
            getActiveEffectNodes=function(a)return {} end};
          EffectManager={hasCondition=function(a,s)return Store[a..'.condition.'..s] or false end};
          DWBFeatures={}; setmetatable(DWBFeatures,{__index=_G});
          function feature(key,name,text) Store[key..'.name']=name; Store[key..'.text']=text or '' end;
          function context() return {source='pc',sourceCT='ctpc',target='target',weapon=true,range='M'} end;
          function basePlan() local p=DWBModel.new(); DWBModel.importClauses(p,{{dmgtype='piercing',dice={'d8'},modifier=5}}); return p end;
        ''')
        self.lua.globals().loadModule((ROOT / "scripts/features.lua").read_text(), self.lua.globals().DWBFeatures)

    def test_appending_damage_keeps_manual_noncritical_dice(self):
        self.run_lua('''
          local M=DWBModel; local p=M.new();
          M.importClauses(p,{{dmgtype='slashing',dice={'d8'},modifier=7}}); M.setCritical(p,true);
          local normal=M.zone(p,'slashing','normal'); M.addDice(p,normal.id,{'d4'});
          assert(M.appendClauses(p,{{dmgtype='radiant',dice={'d8','d8'},modifier=0}}));
          assert(#M.findZone(p,normal.id).dice==1 and M.findZone(p,normal.id).modifier==7);
          assert(#M.zone(p,'radiant','critical').dice==2);
          local before=M.countDice(p); assert(not M.appendClauses(p,{{dmgtype='fire',dice={'-d6'}}}));
          assert(M.countDice(p)==before);
        ''')

    def test_user_preferences_route_independently_and_sync_on_reconnect(self):
        self.lua.execute('''
          Session={IsHost=true,UserName='GM'}; option='on'; sent={}; registrations={};
          OptionsManager={isOption=function(k,v)return option==v end,
            registerOptionData=function(d) registrations[d.sKey]=d end,
            registerCallback=function()end,unregisterCallback=function()end};
          OOBManager={registerOOBMsgHandler=function()end};
          User={getActiveUsers=function()return {'Alice','Bob'}end,
            addEventHandler=function()end,removeEventHandler=function()end};
          Comm={deliverOOBMessage=function(msg,user)table.insert(sent,{msg=msg,user=user})end};
          DB={getOwner=function(node)return node=='alice' and 'Alice' or node=='bob' and 'Bob' or 'Offline' end};
          ActorManager={getCreatureNode=function(a)return a end,isPC=function()return true end};
          Interface={findWindow=function()end};
          DWB={}; setmetatable(DWB,{__index=_G});
          DWBPreferences={};setmetatable(DWBPreferences,{__index=_G});
        ''')
        for name,path in [('DWB','scripts/manager.lua'),('DWBPreferences','scripts/preferences.lua')]:
            self.lua.globals().loadModule((ROOT / path).read_text(encoding='utf-8'),self.lua.globals()[name])
        self.run_lua('''
          local P=DWBPreferences; P.onInit(); assert(registrations.DWB_ENABLED.bLocal);
          P.receive({user='Alice',enabled='off'}); P.receive({user='Bob',enabled='on'});
          assert(not P.enabled('Alice') and P.enabled('Bob') and P.enabled(''));
          assert(P.owner('alice')=='Alice' and P.owner('bob')=='Bob' and P.owner('offline')=='');
          option='off'; P.changed(); assert(P.enabled('Bob') and not P.enabled(''));
          P.login('Bob',false); assert(not P.enabled('Bob'));
          P.login('Bob',true); assert(sent[#sent].user=='Bob' and sent[#sent].msg.type=='DWB_PREFERENCE_QUERY');
          P.receive({user='Bob',enabled='on'}); assert(P.enabled('Bob'));
          local paths=0; DWB.pathOfAction=function()paths=paths+1 end;
          DWB.queue('alice','target',{},false); DWB.queue('offline','target',{},false); assert(paths==0);
          DWB.queue('bob','target',{},false); assert(paths==1);
          Session.IsHost=false; Session.UserName='Alice'; option='off'; P.onTabletopInit();
          assert(sent[#sent].msg.user=='Alice' and sent[#sent].msg.enabled=='off' and sent[#sent].user=='');
          option='on'; P.query(); assert(sent[#sent].msg.enabled=='on');
          local opened=0;
          Utility={decodeJSON=function()return {} end};
          Interface.openWindow=function() opened=opened+1; return {setPlan=function()end} end;
          Comm.addChatMessage=function()end;
          option='off'; DWB.receiveView({id='late',open='1',state='edit',payload='{}'});
          assert(opened==0,'late host response opened a disabled workbench');
          option='on'; DWB.receiveView({id='next',open='1',state='edit',payload='{}'});
          assert(opened==1);
        ''')

    def test_scroll_drag_keeps_grab_offset_and_wheel_routes_to_panel(self):
        self.lua.execute('''
          Scroll={};setmetatable(Scroll,{__index=_G}); current=0; wheel=0;
          setVisible=function()end;
          window={scrollhandle={setVisible=function()end,setStaticBounds=function()end},
            getScrollTrackGeometry=function()return 44,372,200 end,
            setScrollOffset=function(v)current=v;Scroll.configure(200,600,v)end,
            onWheel=function(n)wheel=wheel+n;return true end};
        ''')
        self.lua.globals().loadModule((ROOT / 'ui/hscroll.lua').read_text(encoding='utf-8'),self.lua.globals().Scroll)
        self.run_lua('''
          Scroll.configure(200,600,0);
          Scroll.onClickDown(1,10,4);
          Scroll.onDragStart(1,10,4,{});
          Scroll.onDrag(1,20,4,{}); assert(current==40);
          Scroll.onDrag(1,30,4,{}); assert(current==80);
          Scroll.onDrag(1,30,4,{}); assert(current==80,'stationary pointer caused drift');
          Scroll.onDrag(1,500,4,{}); assert(current==600);
          Scroll.onDrag(1,-50,4,{}); assert(current==0);
          Scroll.onDragEnd(); assert(Scroll.onWheel(-2) and wheel==-2);
        ''')

    def test_direct_cantrip_drop_uses_target_and_selected_damage_variant(self):
        self.lua.execute('''
          Session={IsHost=true}; enabled=true; built={}; sent={};
          local power='pc.powers.spell';
          DB={getPath=function(n)return n end,findNode=function(n)return n end,
            getChild=function(n)return power end,
            getValue=function(n,k,d)
              if k=='type' then return n==power and 'spell' or 'damage' end;
              if k=='level' then return 0 end;
              if k=='group' then return 'Spells (Cleric)' end; return d;
            end};
          ActorManager={isPC=function(a)return a=='pc' end,getDisplayName=function(a)return a end,getCreatureNodeName=function(a)return a end,
            getCTNodeName=function(a)return a end,resolveActor=function(a)return a end};
          DWBPreferences={localEnabled=function()return enabled end,enabled=function()return enabled end,
            owner=function()return '' end};
          PowerManager={getPowerAction=function(n)table.insert(built,n); return {label='Cantrip',clauses={}} end,
            evalAction=function(a,p,action)action.evaluated=true end};
          OptionsManager={isOption=function()return false end};
          Interface={findWindow=function()end,openWindow=function()return {refresh=function()end}end};
          DWB={};setmetatable(DWB,{__index=_G});
        ''')
        self.lua.globals().loadModule((ROOT / 'scripts/manager.lua').read_text(encoding='utf-8'),self.lua.globals().DWB)
        self.run_lua('''
          local path='pc.powers.spell.actions.d12';
          local function rolls() return {{sType='damage',sDWBPath=path}} end;
          local r=rolls(); DWB.onDamageTargeting('pc',{{'target'}},r);
          assert(#r==0 and #DWB.approvals()==1);
          local ctx=DWB.approvals()[1]; assert(ctx.target=='target' and ctx.cantrip);
          assert(built[1]==path and ctx.action.evaluated and ctx.damagePath==path);
          r=rolls(); DWB.onDamageTargeting('pc',{{'target'}},r);
          assert(#r==0 and #DWB.approvals()==1,'duplicate pending damage');
          enabled=false; r=rolls(); DWB.onDamageTargeting('pc',{{'other'}},r); assert(#r==1);
          enabled=true; r=rolls(); DWB.onDamageTargeting('pc',{{}},r); assert(#r==1);
          r={{sType='damage',sDWBPath=path,sDWBCommitted='already'}};
          DWB.onDamageTargeting('pc',{{'target'}},r); assert(#r==1);
          Session.IsHost=false;Session.UserName='Alice';
          Comm={deliverOOBMessage=function(m,u)table.insert(sent,m)end};
          r=rolls(); DWB.onDamageTargeting('pc',{{'dropTarget'}},r);
          assert(#r==0 and sent[1].target=='dropTarget' and sent[1].path==path);
        ''')

    def load_manager(self):
        self.run_lua('DWB={}; setmetatable(DWB,{__index=_G});')
        self.lua.globals().loadModule((ROOT / 'scripts/manager.lua').read_text(encoding='utf-8'),self.lua.globals().DWB)

    def test_auto_reroll_import_menu_model_and_saved_layout(self):
        self.run_lua('''
          local M=DWBModel; local p=M.new(); local z=M.zone(p,'fire','normal',true);
          assert(M.addDice(p,z.id,{{type='d6',mode='r2#1',dicebodycolor='AABBCC'},'d8r1#1'}));
          assert(z.dice[1].nReroll==2 and not z.dice[1].bRerollNoLimit);
          assert(z.dice[2].nReroll==1 and z.dice[1].dicebodycolor=='AABBCC');
          M.setCritical(p,true); local r=M.buildRoll(p);
          assert(#r.aDice==4 and r.aDice[1].mode=='r2#1' and r.aDice[2].mode=='r2#1');
          local restored=M.new(); assert(M.replace(restored,M.preset(p,'saved')));
          assert(restored.zones[1].dice[1].nReroll==2);
          assert(M.setAutoReroll(restored,z.id,1,0)); assert(not M.buildRoll(restored).aDice[1].mode);
          assert(not M.setAutoReroll(restored,z.id,1,6));
          local before=M.countDice(p); assert(not M.appendClauses(p,{{dmgtype='cold',dice={{type='d6',mode='r6#1'}}}}));
          assert(M.countDice(p)==before);
          local q=M.new(); local t=M.zone(q,'fire','normal',true);
          assert(not M.addDice(q,t.id,{{type='d100',mode='r1#1'}}));
          assert(not M.addDice(q,t.id,{{type='d6',mode='r2#2'}}));
          assert(M.importClauses(q,{{dmgtype='fire',dice={'d6'},nReroll=2}}));
          assert(M.buildRoll(q).aDice[1].mode=='r2#1');
        ''')

    def test_roll_visibility_and_undo_audience(self):
        self.load_manager()
        self.run_lua('''
          local option='on'; local friendly=true; local hidden=false; local gated=0;
          ActorManager={resolveActor=function(a)return a end,getCTNode=function(a)return a end};
          CombatManager={isCTHidden=function()return hidden end};
          OptionsManager={isOption=function(k,v)return option==v end};
          ActionsManager={getShowResultToPlayer=function(a,b)assert(a=='source' and b=='target'); gated=gated+1;return friendly end};
          local p=DWBModel.new('Sword');DWBModel.importClauses(p,{{dmgtype='slashing',dice={'d6'},modifier=3}});
          assert(DWBModel.recordResults(p,{aDice={{type='d6',result=4}}}));
          local ctx={source='source',target='target',owner='Alice',plan=p,label='Sword',publicName='Fighter'};
          assert(not DWB.secretRoll(ctx));friendly=false;assert(DWB.secretRoll(ctx));assert(gated==2);
          friendly=true;hidden=true;assert(DWB.secretRoll(ctx));hidden=false;
          p.flags={bSecret=true};assert(DWB.secretRoll(ctx));p.flags={};
          option='off';ctx.owner='';assert(DWB.secretRoll(ctx));ctx.owner='Alice';assert(not DWB.secretRoll(ctx));
          local messages={};Comm={deliverChatMessage=function(m,u)table.insert(messages,{m=m,u=u})end};
          DWB.auditUndo(ctx);assert(#messages==2 and messages[1].u=='' and messages[2].u=='Alice');
          assert(messages[1].m.secret and messages[1].m.text:find('d6=4',1,true) and messages[1].m.text:find('Total: 7',1,true));
          ctx.owner='';messages={};DWB.auditUndo(ctx);assert(#messages==1 and messages[1].u=='');
        ''')

    def test_native_roll_transport_keeps_mode_and_skin(self):
        self.load_manager()
        self.run_lua('''
          local M=DWBModel;local p=M.new();M.importClauses(p,{{dmgtype='fire',dice={{type='d6',mode='r2#1',dicebodycolor='ABCDEF'}}}});
          local r=M.buildRoll(p);r.bSecret=false;
          Utility={decodeJSON=function()return M.copy(r)end};Interface={findWindow=function()end};
          ActorManager={resolveActor=function(a)return a end};
          DiceRollManager={addDamageDice=function(out,types,data)table.insert(out,{type=types[1],diceskin=42})end};
          local captured;ActionsManager={roll=function(source,target,roll)captured=roll;assert(source=='source')end};
          DWB.receiveRoll({id='test',nonce='once',source='source',payload='encoded'});
          assert(captured.bSecret==false and captured.aDice[1].mode=='r2#1');
          assert(captured.aDice[1].dicebodycolor=='ABCDEF' and captured.aDice[1].diceskin==42);
        ''')

    def test_x2_apply_uses_native_multiplier_without_changing_dice(self):
        self.load_manager()
        self.run_lua('''
          local M=DWBModel;local p=M.new();M.importClauses(p,{{dmgtype='fire',dice={'d6'},modifier=3}});
          assert(M.recordResults(p,{aDice={{type='d6',result=4}}}));
          assert(M.appliedTotal(p)==7);p.doubleDamage=true;assert(M.appliedTotal(p)==14);
          assert(p.roll.aDice[1].result==4);local delivered;
          ActorManager={resolveActor=function(a)return {name=a} end,isPC=function()return true end};
          DWBFeatures={validateClaims=function()return true end,commit=function()end};
          ActionCore={encodeRollClauses=function()end,decodeRollClauses=function()end,encodeDamageTypesDisplay=function()end};
          ActionsManager={total=function(r)return r.nMod+r.aDice[1].result end,resolveAction=function(a,b,r)delivered=r end};
          ActionAttackCore={clearCritState=function()end};DB={deleteNode=function()end};DWB.sendView=function()end;
          local ctx={id='test',source='source',target='target',plan=p,label='Sword',state='results'};
          DWB.apply(ctx);assert(ctx.state=='applied');
          assert(delivered.bModDouble and delivered.sDesc:find('[DOUBLE]',1,true));
          assert(delivered.nTotal==7 and delivered.aDice[1].result==4 and delivered.nMod==3);
          local q=M.new();assert(M.replace(q,M.preset(p,'saved')));assert(not q.doubleDamage);
        ''')

if __name__ == '__main__':
    unittest.main(verbosity=2)
