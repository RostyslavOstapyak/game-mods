-- Reacquire an already loaded UObject; never keep wrappers alive between frames.
return function(path)
 if type(path)~='string'or path==''or path=='None'then return nil end
 local object=StaticFindObject(path)
 if object and object:IsValid()then return object end
 return LoadAsset(path)
end
