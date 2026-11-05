-- Display formatting only; editable amounts and payment calculations stay numeric.
local M={}
local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
local L=dofile(DIR..'/localization.lua')
function M.number(value)
 local s=tostring(value)
 local sign,digits,tail=s:match('^([%-]?)(%d+)(.*)$')
 if not digits then return s end
 return sign..digits:reverse():gsub('(%d%d%d)','%1 '):reverse():gsub('^ ','')..tail
end
function M.message(value)
 return(L.message(value):gsub('%d%d%d%d+',M.number))
end
function M.error(value)
 local text=tostring(value):gsub('^.-%.lua:%d+: ','')
 return M.message(text)
end
return M
