local M={}
function M.fold(value)
 local out={}
 for _,code in utf8.codes(value)do
  if code>=65 and code<=90 then code=code+32
  elseif code>=1040 and code<=1071 then code=code+32
  elseif code>=1024 and code<=1039 then code=code+80
  elseif code==1168 then code=1169 end
  out[#out+1]=utf8.char(code)
 end
 return table.concat(out)
end
function M.matches(name,id,query)
 query=M.fold(query):match('^%s*(.-)%s*$')
 return query==''or M.fold(name):find(query,1,true)~=nil or M.fold(id):find(query,1,true)~=nil
end
return M
