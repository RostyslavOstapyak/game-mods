-- Shared dark input style; leaves content, font size, focus and selection untouched.
return function(input)
 local ink={r=.855,G=.791,B=.658,A=1}
 input:SetForegroundColor(ink)
 input.WidgetStyle.TextStyle.ColorAndOpacity.SpecifiedColor=ink
 input.WidgetStyle.TextStyle.ColorAndOpacity.ColorUseRule=0
 local colors={
  BackgroundImageNormal={r=.0024,G=.0065,B=.0137,A=1},
  BackgroundImageHovered={r=.0052,G=.0176,B=.0356,A=1},
  BackgroundImageFocused={r=.008,G=.027,B=.051,A=1},
  BackgroundImageReadOnly={r=.0024,G=.0065,B=.0137,A=1},
 }
 for state,color in pairs(colors)do
  input.WidgetStyle[state].TintColor.SpecifiedColor=color
  input.WidgetStyle[state].TintColor.ColorUseRule=0
 end
end
