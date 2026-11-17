local DIR=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
return dofile(DIR..'/backpack_items.lua')
