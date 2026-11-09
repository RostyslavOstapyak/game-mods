using System.Collections.Generic;
using UnityEngine;

namespace CozyTweaks {
 internal static class DarkTheme {
  static GUISkin skin;
  static readonly List<Texture2D> textures=new List<Texture2D>();
  static readonly Color text=new Color(0.90f,0.92f,0.95f);
  internal static GUISkin Skin {
   get {
    if(skin!=null)return skin;
    skin=UnityEngine.Object.Instantiate(GUI.skin);
    var background=Solid(new Color(0.065f,0.075f,0.10f));
    var surface=Solid(new Color(0.11f,0.13f,0.17f));
    var hover=Solid(new Color(0.18f,0.22f,0.28f));
    var selected=Solid(new Color(0.13f,0.35f,0.35f));
    Paint(skin.window,background,background,background);
    skin.window.padding=new RectOffset(18,18,36,16);skin.window.fontSize=16;
    Paint(skin.box,surface,surface,surface);
    Paint(skin.button,surface,hover,selected);skin.button.padding=new RectOffset(10,10,7,7);
    Paint(skin.textField,surface,hover,selected);skin.textField.padding=new RectOffset(8,8,6,6);
    Paint(skin.textArea,surface,hover,selected);
    skin.label.normal.textColor=text;skin.label.wordWrap=true;
    skin.toggle.normal.textColor=skin.toggle.hover.textColor=skin.toggle.active.textColor=text;
    skin.toggle.onNormal.textColor=skin.toggle.onHover.textColor=skin.toggle.onActive.textColor=new Color(0.45f,0.92f,0.82f);
    var off=Checkbox(false);var on=Checkbox(true);
    skin.toggle.normal.background=skin.toggle.hover.background=skin.toggle.active.background=off;
    skin.toggle.onNormal.background=skin.toggle.onHover.background=skin.toggle.onActive.background=on;
    skin.toggle.border=new RectOffset(20,1,0,0);skin.toggle.padding=new RectOffset(26,5,4,4);
    Paint(skin.horizontalSlider,surface,surface,surface);Paint(skin.horizontalSliderThumb,hover,selected,selected);
    Paint(skin.verticalScrollbar,surface,surface,surface);Paint(skin.verticalScrollbarThumb,hover,selected,selected);
    Paint(skin.horizontalScrollbar,surface,surface,surface);Paint(skin.horizontalScrollbarThumb,hover,selected,selected);
    return skin;
   }
  }
  static void Paint(GUIStyle style,Texture2D normal,Texture2D hover,Texture2D active) {
   style.border=new RectOffset(0,0,0,0);
   style.normal.background=normal;style.hover.background=hover;style.active.background=active;style.focused.background=hover;
   style.onNormal.background=active;style.onHover.background=active;style.onActive.background=active;style.onFocused.background=active;
   foreach(var state in new[]{style.normal,style.hover,style.active,style.focused,style.onNormal,style.onHover,style.onActive,style.onFocused})state.textColor=text;
  }
  static Texture2D Solid(Color color) {
   var texture=new Texture2D(2,2,TextureFormat.RGBA32,false);texture.SetPixels(new[]{color,color,color,color});texture.Apply();textures.Add(texture);return texture;
  }
  static Texture2D Checkbox(bool enabled) {
   var texture=new Texture2D(24,20,TextureFormat.RGBA32,false);var pixels=new Color[24*20];
   for(int y=2;y<18;y++)for(int x=2;x<18;x++)pixels[y*24+x]=(x==2||x==17||y==2||y==17)?new Color(0.4f,0.47f,0.55f):new Color(0.1f,0.12f,0.16f);
   if(enabled)for(int y=6;y<14;y++)for(int x=6;x<14;x++)pixels[y*24+x]=new Color(0.35f,0.85f,0.72f);
   texture.SetPixels(pixels);texture.Apply();textures.Add(texture);return texture;
  }
  internal static void Dispose() {if(skin!=null)UnityEngine.Object.Destroy(skin);skin=null;foreach(var texture in textures)if(texture!=null)UnityEngine.Object.Destroy(texture);textures.Clear();}
 }
}







