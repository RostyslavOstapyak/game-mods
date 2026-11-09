using BepInEx.Configuration;
using UnityEngine;
namespace CozyTweaks {
 internal static class ToolStatusHud {
  static ConfigEntry<bool> enabled,showBar; static ConfigEntry<float> positionX,positionY; static bool positioning; static Vector2 dragPosition,grabOffset; static bool dragging;
  static CGR_Toolbar_CleaningToolSelector selector;
  static GameObject root;
  static cgrToolMasterEyeDropper liquid;
  static cgrToolMasterPolish polish;
  static cgrToolMasterQtip swab;
  static cgrToolMasterToothbrush brush; static ToolDirtinessTracker tracker;
  static float nextLookup,value;
  static string title;
  static bool visible,dirty;
  static GUIStyle heading,number;
  internal static void Initialize(ConfigFile config) {
   enabled=config.Bind("ToolStatus","Enabled",true,"Show remaining liquid or tool dirtiness for the selected tool while cleaning.");
   positionX=config.Bind("ToolStatus","PositionX",1f,new ConfigDescription("Horizontal position within available screen space (0 left, 1 right).",new AcceptableValueRange<float>(0,1)));
   positionY=config.Bind("ToolStatus","PositionY",0.2f,new ConfigDescription("Vertical position within available screen space (0 top, 1 bottom).",new AcceptableValueRange<float>(0,1)));
   showBar=config.Bind("ToolStatus","ShowBar",true,"Show a colored bar alongside the percentage. Display only; does not change tool capacity or dirtiness.");
  }
  internal static void EndPlacement(){if(dragging)SavePosition();positioning=false;dragging=false;}
  internal static void Update() {
   UpdatePlacement();
   visible=false;
   if(!Plugin.Active||!enabled.Value||GameStateManager.Instance==null||GameStateManager.Instance.CurrentGameState!=GameState.CleaningStation)return;
   if(selector==null) {
    if(Time.unscaledTime<nextLookup)return;nextLookup=Time.unscaledTime+1f;
    selector=Object.FindObjectOfType<CGR_Toolbar_CleaningToolSelector>();root=null;
   }
   if(selector==null||selector.cleaningTools==null||selector.currentToolIndex<0||selector.currentToolIndex>=selector.cleaningTools.Length)return;
   var selected=selector.cleaningTools[selector.currentToolIndex];
   if(selected==null||!selected.activeInHierarchy)return;
   if(root!=selected) {
    root=selected;
    liquid=root.GetComponentInChildren<cgrToolMasterEyeDropper>(true);
    polish=root.GetComponentInChildren<cgrToolMasterPolish>(true);
    swab=root.GetComponentInChildren<cgrToolMasterQtip>(true);
    brush=root.GetComponentInChildren<cgrToolMasterToothbrush>(true);tracker=root.GetComponentInChildren<ToolDirtinessTracker>(true);
   }
   dirty=false;
   if(liquid!=null&&liquid.isActiveAndEnabled&&liquid.isActiveTool){title=L.T("Рідина");value=liquid.fillPercent;}
   else if(polish!=null&&polish.isActiveAndEnabled&&polish.isActiveTool){title=L.T("Поліроль");value=polish.fillPercent;}
   else if(swab!=null&&swab.isActiveAndEnabled&&swab.isActiveTool){title=L.T("Ватна паличка");value=swab.dirtinessTracker!=null?swab.dirtinessTracker.dirtPercent*100f:swab.dirtPercent*100f;dirty=true;}
   else if(brush!=null&&brush.isActiveAndEnabled&&brush.isActiveTool){title=L.T("Щітка");value=brush.dirtinessTracker!=null?brush.dirtinessTracker.dirtPercent*100f:brush.dirtPercent*100f;dirty=true;}
   else if(tracker!=null&&tracker.isActiveAndEnabled){title=root.name.IndexOf("qtip",System.StringComparison.OrdinalIgnoreCase)>=0?L.T("Ватна паличка"):tracker.toolName;value=tracker.dirtPercent*100f;dirty=true;}
   else return;
   if(float.IsNaN(value)||float.IsInfinity(value))return;
   value=Mathf.Clamp(value,0,100);visible=true;
  }
  static float HudScale {get{return Mathf.Clamp(Screen.height/1000f,0.8f,1.8f);}}
  static Vector2 AvailableSpace {get {float scale=HudScale;return new Vector2(Mathf.Max(1,Screen.width/scale-276),Mathf.Max(1,Screen.height/scale-(showBar.Value?108:90)-16));}}
  static void SavePosition() {
   var space=AvailableSpace;positionX.Value=Mathf.Clamp01((dragPosition.x-8)/space.x);positionY.Value=Mathf.Clamp01((dragPosition.y-8)/space.y);
  }
  static void UpdatePlacement() {
   if(!positioning||!Plugin.SettingsOpen){if(dragging)SavePosition();dragging=false;return;}
   var space=AvailableSpace;var mouse=new Vector2(Input.mousePosition.x,Screen.height-Input.mousePosition.y)/HudScale;
   var position=new Vector2(8+positionX.Value*space.x,8+positionY.Value*space.y);
   var panel=new Rect(position.x,position.y,260,showBar.Value?108:90);
   if(!dragging&&Input.GetMouseButtonDown(0)&&panel.Contains(mouse)){dragging=true;dragPosition=position;grabOffset=mouse-position;}
   if(dragging) {
    var next=mouse-grabOffset;dragPosition=new Vector2(Mathf.Clamp(next.x,8,8+space.x),Mathf.Clamp(next.y,8,8+space.y));
    if(!Input.GetMouseButton(0)){SavePosition();dragging=false;}
   }
  }
  internal static void DrawSettings() {
   if(GUILayout.Button(positioning?L.T("Завершити переміщення"):L.T("Перемістити індикатор"))){if(positioning)EndPlacement();else positioning=true;}
   if(positioning)GUILayout.Label(L.T("Перетягни індикатор мишею. Позиція зберігається після відпускання."));
   if(GUILayout.Button(L.T("Повернути стандартну позицію"))){positionX.Value=1;positionY.Value=0.2f;}
   enabled.Value=GUILayout.Toggle(enabled.Value,L.T("Показувати стан активного інструмента"));
   showBar.Value=GUILayout.Toggle(showBar.Value,L.T("Кольорова смуга під відсотками"));
   GUILayout.Label(L.T("Рідина й поліроль: 100% — повний запас, 0% — порожньо."));
   GUILayout.Label(L.T("Паличка й щітка: 0% — чисті, 100% — потрібно очистити."));
   GUILayout.Label(L.T("Індикатор справа з’являється лише під час чищення для інструментів із запасом або забрудненням."));
  }
  internal static void Draw() {
   bool preview=positioning&&Plugin.SettingsOpen;
   if(!preview&&(!visible||!Plugin.Active||!enabled.Value||Plugin.SettingsOpen||GameStateManager.Instance==null||GameStateManager.Instance.CurrentGameState!=GameState.CleaningStation))return;
   var matrix=GUI.matrix;var color=GUI.color;
   try {
    float scale=Mathf.Clamp(Screen.height/1000f,0.8f,1.8f);
    GUI.matrix=Matrix4x4.Scale(new Vector3(scale,scale,1));
    float width=Screen.width/scale,height=Screen.height/scale;float panelHeight=showBar.Value?108:90;
    float availableX=Mathf.Max(1,width-276),availableY=Mathf.Max(1,height-panelHeight-16);
    var panel=new Rect(8+positionX.Value*availableX,8+positionY.Value*availableY,260,panelHeight);
    if(preview&&dragging)panel.position=dragPosition;
    GUI.color=new Color(0.035f,0.045f,0.06f,0.9f);GUI.DrawTexture(panel,Texture2D.whiteTexture);GUI.color=Color.white;
    if(heading==null){heading=new GUIStyle(GUI.skin.label){fontSize=16,alignment=TextAnchor.MiddleLeft};heading.normal.textColor=Color.white;number=new GUIStyle(heading){fontSize=20,fontStyle=FontStyle.Bold};}
    GUI.Label(new Rect(panel.x+14,panel.y+8,232,25),preview?L.T("Перетягни мене"):title,heading);
    float good=dirty?1-value/100f:value/100f;var accent=Color.Lerp(new Color(1,0.35f,0.25f),new Color(0.35f,0.9f,0.72f),good);
    GUI.Label(new Rect(panel.x+14,panel.y+34,232,35),(dirty?L.T("Забруднення"):L.T("Залишок"))+": "+Mathf.RoundToInt(value)+"%",number);
    if(showBar.Value){var bar=new Rect(panel.x+14,panel.y+83,232,8);GUI.color=new Color(0.2f,0.23f,0.27f);GUI.DrawTexture(bar,Texture2D.whiteTexture);bar.width*=value/100f;GUI.color=accent;GUI.DrawTexture(bar,Texture2D.whiteTexture);}
   } finally {GUI.matrix=matrix;GUI.color=color;}
  }
 }
}





