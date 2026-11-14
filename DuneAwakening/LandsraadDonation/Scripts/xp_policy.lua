-- User-defined mod economy, independent of vanilla mission reward multipliers.
-- Pure planning only. No native XP action until the house track is verified.
local M={}
function M.quote(points,rate)
 assert(type(points)=='number'and points%1==0 and points>=1 and points<=6000,'Invalid contribution amount.')
 assert(type(rate)=='number'and rate==rate and rate>=0 and rate<=1000,'Invalid specialization XP rate.')
 return math.floor(points*rate+0.000000001)
end
return M
