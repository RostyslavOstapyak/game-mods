-- Plain policy only. No inventory actions or UObject references.
local M={version=1}
M.universalRequests={DuraluminumRod=true,T6RefinedResourceA=true}
local categories={
 combat={'Items.Holsters.MeleeWeapons','Items.Holsters.RangedWeapons','Items.Clothes.HeavyArmor','Items.Clothes.ScoutArmor','Items.Ammo.Light','Items.Ammo.Heavy','Items.Ammo.Exotic','Items.Ammo.Vehicle'},
 crafting={'Items.RefinedResources.Metal','Items.RefinedResources.Support','Items.CraftedResources'},
 gathering={'Items.Holsters.GatheringTools.Cutteray','Items.Holsters.GatheringTools.Compactor'},
 exploration={'Items.Clothes.Stillsuit','Items.Holsters.UtilityTools.Suspensor','Items.Holsters.HydrationTools','Items.Holsters.CartographyTools'},
 sabotage={'Items.Holsters.MeleeWeapons','Items.Holsters.RangedWeapons.Light.Rifle.SpitDart'},
}
local function has(tags,prefix)
 prefix=prefix:lower()
 for _,tag in ipairs(tags)do tag=tag:lower();if tag==prefix or tag:sub(1,#prefix+1)==prefix..'.'then return true end end
 return false
end
function M.eligible(item,category)
 if not categories[category]then return false,'category_unresolved'end
 local id,tags=item.id,item.tags
 if type(id)~='string'or not id:match('^[%w_]+$')or type(tags)~='table'then return false,'invalid_item'end
 if item.enabled~=true or item.deprecated~=false then return false,'inactive'end
 local folded=id:lower()
 for _,word in ipairs({'npc','debug','test','mtx','contract','journey'})do
  if folded:find(word,1,true)then return false,'restricted_identity'end
 end
 for _,tag in ipairs({'Items.RawResources','Items.Contract','Items.ActorBoundItem','Items.Schematics','Items.Consumables.Customizations','Items.Consumables.BuildableSets','Items.HideFromExchange','Items.ExcludeFromPlayerSellingToVendor'})do
  if has(tags,tag)then return false,'restricted_tag'end
 end
 -- Melange is a separate universal payment with its own fixed configured rate.
 if id=='MelangeSpice'or has(tags,'Items.RefinedResources.Spice')then return false,'universal_melange'end
 if not has(tags,'LootTier.5')and not has(tags,'LootTier.6')then return false,'unsupported_tier'end
 for _,tag in ipairs(categories[category])do if has(tags,tag)then return true end end
 return false,'wrong_category'
end
function M.tier6Pool(items,category)
 local pool,seen={},{}
 for _,item in ipairs(items)do
  if M.eligible(item,category)and has(item.tags,'LootTier.6')then
   assert(not seen[item.id],'Duplicate request candidate.');seen[item.id]=true;pool[#pool+1]=item.id
  end
 end
 table.sort(pool);return pool
end
function M.requestPool(items,category)
 local pool=M.tier6Pool(items,category)
 local seen={};for _,id in ipairs(pool)do seen[id]=true end
 for _,item in ipairs(items)do
  if M.universalRequests[item.id]and not seen[item.id]and M.eligible(item,'crafting')then
   seen[item.id]=true;pool[#pool+1]=item.id
  end
 end
 table.sort(pool);return pool
end
function M.accepts(item,category,requested)
 if M.eligible(item,category)then return true end
 if item.id==requested and M.universalRequests[item.id]then return M.eligible(item,'crafting')end
 return false
end
function M.choose(pool,iteration,house,previous)
 assert(type(iteration)=='string'and iteration~=''and type(house)=='string'and house~='','Persistent iteration and house identities required.')
 if previous then
  -- A persisted request is immutable within its iteration, even if catalog order changes.
  for _,id in ipairs(pool)do if id==previous then return previous end end
  return nil,'saved_request_unavailable'
 end
 if #pool==0 then return nil,'no_eligible_tier6'end
 local hash=0
 for c in(iteration..':'..house):gmatch('.')do hash=(hash*131+c:byte())%2147483647 end
 return pool[hash%#pool+1]
end
function M.rewardMultiplier(template,request)
 return request and template==request and 2 or 1
end
return M
