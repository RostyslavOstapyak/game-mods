local M={}
function M.score(pawn,camera,rotation,terminal)
 local x,y,z=terminal.X-pawn.X,terminal.Y-pawn.Y,terminal.Z-pawn.Z
 if x*x+y*y>250*250 or math.abs(z)>250 then return nil end
 local dx,dy,dz=terminal.X-camera.X,terminal.Y-camera.Y,terminal.Z+155-camera.Z
 local length=math.sqrt(dx*dx+dy*dy+dz*dz)
 if length<1 then return nil end
 local pitch,yaw=math.rad(rotation.Pitch),math.rad(rotation.Yaw)
 local dot=(dx*math.cos(pitch)*math.cos(yaw)+dy*math.cos(pitch)*math.sin(yaw)+dz*math.sin(pitch))/length
 if dot<.94 then return nil end
 return dot-length/100000
end
return M
