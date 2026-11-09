using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Reflection.Emit;
using BepInEx;
using BepInEx.Configuration;
using BepInEx.Logging;
using HarmonyLib;
using UnityEngine;

namespace CozyTweaks {
 [BepInPlugin(Id, "Cozy Tweaks", "0.5.2")]
 [BepInProcess("CozyGameRestoration.exe")]
 public sealed class Plugin : BaseUnityPlugin {
  public const string Id = "cozytweaks.personal.qol";
  sealed class ExtraPage {internal string Id;internal Func<string> Title;internal Action Draw;}
  static readonly List<ExtraPage> extraPages=new List<ExtraPage>();
  public static void RegisterSettingsPage(string id,Func<string> title,Action draw) {UnregisterSettingsPage(id);extraPages.Add(new ExtraPage{Id=id,Title=title,Draw=draw});}
  public static void UnregisterSettingsPage(string id) {extraPages.RemoveAll(p=>p.Id==id);if(Instance!=null)Instance.settingsTab=0;}
  internal static Plugin Instance;
  internal static ConfigEntry<bool> Enabled, FastBox, FastFades, FastDrop, ShortReadyDelay;
  internal static ConfigEntry<bool> FastCompletion;
  internal static ConfigEntry<float> BoxSpeed, FadeMaxSeconds, DeskSpeed, ReadyDelaySeconds;
  internal static ConfigEntry<float> CompletionSpeed;
  ConfigEntry<KeyboardShortcut> toggleKey, settingsKey;
  Harmony harmony;
  bool showSettings;
  bool focusSettings;
  int settingsTab;
  Vector2 settingsScroll;
  Rect window = new Rect(30,30,560,560);
  internal static bool SettingsOpen {get{return Instance!=null&&Instance.showSettings;}}
  string status = "";
  internal static bool Active { get { return Instance != null && Enabled.Value; } }

  void Awake() {
   Instance=this;
   L.Initialize(Config);
   Enabled=Config.Bind("General","Enabled",true,"Enable animation improvements. Ctrl+F8 toggles this at runtime.");
   toggleKey=Config.Bind("General","ToggleKey",new KeyboardShortcut(KeyCode.F8,KeyCode.LeftControl),"Toggle improvements for the next animation.");
   settingsKey=Config.Bind("General","SettingsKey",new KeyboardShortcut(KeyCode.F10),"Open or close the settings window.");
   FastBox=Config.Bind("Animations","FastBox",true,"Shorten top-flap animations; preserve the normal opening callback.");
   BoxSpeed=Config.Bind("Animations","BoxSpeed",8f,new ConfigDescription("Opening speed. 1 = original; 20 = fastest. Replaces the old inverse duration slider.",new AcceptableValueRange<float>(1f,20f)));
   FastFades=Config.Bind("Animations","FastParcelSceneFades",true,"Shorten fades only into unpacking, prepainting, and cleaning. Scene loading is still awaited.");
   FadeMaxSeconds=Config.Bind("Animations","FadeMaxSeconds",0.10f,new ConfigDescription("Maximum fade duration for these three scenes.",new AcceptableValueRange<float>(0.03f,1f)));
   FastDrop=Config.Bind("Animations","FastDeskDrop",true,"Shorten supported 3D arrivals and their chained pauses in unpacking and cleaning scenes. Idle loops retain their speed.");
   DeskSpeed=Config.Bind("Animations","DeskArrivalSpeed",5f,new ConfigDescription("Arrival speed. 1 = original; 20 = fastest. Also shortens pauses between arrival actions.",new AcceptableValueRange<float>(1f,20f)));
   ShortReadyDelay=Config.Bind("Experimental","ShortReadyDelay",false,"OPT-IN: reduce the 5-second input lock after cleaning scene setup. Disable if tools or dirt counters initialize incorrectly.");
   ReadyDelaySeconds=Config.Bind("Experimental","ReadyDelaySeconds",1.5f,new ConfigDescription("Input-lock duration when the experimental option is enabled.",new AcceptableValueRange<float>(0.5f,5f)));
   FastCompletion=Config.Bind("Animations","FastCompletion",true,"Shorten completion screen movements, snapshot display hold, celebration delay and scene fades. Real screenshot saving and collection/quest updates are retained.");
   CompletionSpeed=Config.Bind("Animations","CompletionSpeed",8f,new ConfigDescription("Completion presentation speed. Higher = faster.",new AcceptableValueRange<float>(1f,20f)));
   ToolBindings.Initialize(Config);
   InventoryTable.Initialize(Config);
   ToolStatusHud.Initialize(Config);RegisterSettingsPage("tool-status",()=>L.T("Стан інструмента"),ToolStatusHud.DrawSettings);
   harmony=new Harmony(Id);
   Install("box", "ParcelOpeningManager", "OpenParcel", null, "BoxTranspiler");
   Install("fades", "CGRSceneStateManager", "TransitionToScene", "FadePrefix", null);
   Install("desk drop", "tween3d_dropin_then_bob", "Play", null, "DropTranspiler");
   Install("desk slide-in", "tween3d_onappear_dropin", "Play", null, "SlideTranspiler");
   Install("arrival action spacing", "tween3d_onappear_dropin", "StartInvokeSequence", null, "SpacingTranspiler");
   Install("desk transform animation", "tween3d_transformToFrom", "PlayAnimation", null, "TransformTranspiler");
   Install("optional input delay", "CgrGameCleaningSceneManager", "SetReadyForCleanAfterDelay", "ReadyPrefix", null);
   InstallFeature("tool bindings","CGRRewiredHotkeyInput","Update",typeof(ToolBindings),null,null,"InputTranspiler");
   InstallFeature("tool names","CGR_Toolbar_CleaningToolSelector","Start",typeof(ToolBindings),null,"SelectorPostfix",null);
   InstallFeature("settings input focus","cgrInputPrototype","Update",typeof(ToolBindings),"InputPrefix",null,null);
   InstallFeature("inventory table","CollectionsScreen","ShowGameCollection",typeof(InventoryTable),"BeforeCollection","AfterCollection",null);
   InstallFeature("lazy inventory cards","CollectionsScreen","GetCurrentPageItems",typeof(InventoryTable),"PageItemsPrefix",null,null);
   InstallFeature("skip hidden page snapshot","CollectionsScreen","SeedCurrentSpreadForFreshCollection",typeof(InventoryTable),"PageSnapshotPrefix",null,null);
   InstallFeature("shelf table","NodePlacementManager","ShowSelectionUI",typeof(InventoryTable),null,"ShelfPostfix",null);
   InstallFeature("shelf placement markers","ShelfBonusManager","OnGamePlaced",typeof(InventoryTable),null,"PlacementChangedPostfix",null);
   InstallFeature("shelf removal markers","ShelfBonusManager","OnGameRemoved",typeof(InventoryTable),null,"PlacementChangedPostfix",null);
   InstallFeature("close shelf table on state change","GameStateManager","SetGameState",typeof(InventoryTable),"StateChangingPrefix",null,null);
   ModalInput.Install(harmony,message=>Logger.LogInfo(message));
   CompletionAnimations.Install(harmony,message=>Logger.LogInfo(message));
   Logger.LogInfo("Cozy Tweaks 0.5.2 loaded. Default UI: Ukrainian; English can be selected in F10.");
  }
  void InstallFeature(string label,string type,string method,Type patches,string prefix,string postfix,string transpiler) {
   try {
    var target=AccessTools.Method(AccessTools.TypeByName(type),method);if(target==null)throw new MissingMethodException(type,method);
    harmony.Patch(target,prefix==null?null:new HarmonyMethod(patches,prefix),postfix==null?null:new HarmonyMethod(patches,postfix),transpiler==null?null:new HarmonyMethod(patches,transpiler));
    Logger.LogInfo("Installed: "+label);
   } catch(Exception e){Logger.LogError("Module unavailable: "+label+". "+e);status+="Unavailable: "+label+"\n";}
  }

  void Install(string label,string type,string method,string prefix,string transpiler) {
   try {
    var target=AccessTools.Method(AccessTools.TypeByName(type),method);
    if(target==null)throw new MissingMethodException(type,method);
    harmony.Patch(target,prefix==null?null:new HarmonyMethod(typeof(AnimationPatches),prefix),null,transpiler==null?null:new HarmonyMethod(typeof(AnimationPatches),transpiler));
    Logger.LogInfo("Installed: "+label);
   } catch(Exception e) { Logger.LogError("Module unavailable: "+label+". Original behavior retained. "+e);status+="Unavailable: "+label+"\n"; }
  }

  void Update() {
   ModalInput.Update();
   if(toggleKey.Value.IsDown()) { SetEnabled(!Enabled.Value);Logger.LogInfo("Enabled="+Enabled.Value); }
   if(settingsKey.Value.IsDown())SetSettingsOpen(!showSettings);
  }
  void LateUpdate() {ToolStatusHud.Update();}
  void SetSettingsOpen(bool value) {
   if(value==showSettings)return;
   showSettings=value;
   if(value){ModalInput.Open();focusSettings=true;}
   else {ToolStatusHud.EndPlacement();ModalInput.Close();ToolBindings.CancelCapture();}
  }
  public static void CloseForOrder() {if(Instance!=null)Instance.SetSettingsOpen(false);}
  public static void LogMessage(string message) {if(Instance!=null)Instance.Logger.LogInfo(message);}
  void SetEnabled(bool value) {if(value==Enabled.Value)return;Enabled.Value=value;if(!value)InventoryTable.RestoreNative();else InventoryTable.RefreshActive();}
  void OnGUI() {
   var originalEnabled=GUI.enabled;var originalMatrix=GUI.matrix;
   try {GUI.enabled=originalEnabled&&!ModalInput.Blocked;InventoryTable.Draw();}catch(Exception e){Logger.LogError("Inventory table disabled after an error: "+e);InventoryTable.DisableAfterError();}
   finally {GUI.enabled=originalEnabled;GUI.matrix=originalMatrix;}
   if(!showSettings){ToolStatusHud.Draw();return;}
   var originalSkin=GUI.skin;var originalColor=GUI.color;
   try {
    GUI.color=new Color(0,0,0,0.62f);GUI.DrawTexture(new Rect(0,0,Screen.width,Screen.height),Texture2D.whiteTexture);GUI.color=Color.white;
    float scale=Mathf.Clamp(Screen.height/1000f,1f,1.5f);float width=Screen.width/scale,height=Screen.height/scale;
    GUI.matrix=Matrix4x4.Scale(new Vector3(scale,scale,1));GUI.skin=DarkTheme.Skin;
    window.width=Mathf.Min(640,width-40);window.height=Mathf.Min(640,height-40);
    window.x=Mathf.Clamp(window.x,0,width-window.width);window.y=Mathf.Clamp(window.y,0,height-window.height);
    window=GUI.ModalWindow(741836,window,DrawWindow,L.T("Cozy Tweaks 0.5.2  •  гра на паузі"));
    if(focusSettings){GUI.FocusWindow(741836);GUI.BringWindowToFront(741836);focusSettings=false;}
   } finally {GUI.skin=originalSkin;GUI.color=originalColor;GUI.matrix=originalMatrix;}
   ToolStatusHud.Draw();
  }
  void DrawWindow(int id) {
   GUILayout.BeginHorizontal();GUILayout.Label("Мова / Language",GUILayout.Width(145));
   if(GUILayout.Button((L.Language==UiLanguage.Ukrainian?"✓ ":"")+"Українська"))L.Language=UiLanguage.Ukrainian;
   if(GUILayout.Button((L.Language==UiLanguage.English?"✓ ":"")+"English"))L.Language=UiLanguage.English;
   GUILayout.EndHorizontal();
   SetEnabled(GUILayout.Toggle(Enabled.Value,L.T("Увімкнути покращення (лівий Ctrl+F8)")));
   var tabNames=new List<string>{L.T("Анімації"),L.T("Інструменти"),L.T("Інвентар")};tabNames.AddRange(extraPages.Select(p=>p.Title()));
   settingsTab=Mathf.Clamp(settingsTab,0,tabNames.Count-1);
   int tab=GUILayout.Toolbar(settingsTab,tabNames.ToArray());if(tab!=settingsTab){settingsTab=tab;ToolBindings.CancelCapture();}
   settingsScroll=GUILayout.BeginScrollView(settingsScroll,GUILayout.Height(window.height-165));
   if(settingsTab==1)ToolBindings.Draw();
   else if(settingsTab==2)InventoryTable.DrawSettings();
   else if(settingsTab>=3)extraPages[settingsTab-3].Draw();
   else DrawAnimations();
   GUILayout.EndScrollView();
   if(status.Length>0)GUILayout.Label(status);
   if(GUILayout.Button(L.T("Закрити (F10)")))SetSettingsOpen(false);
   GUI.DragWindow(new Rect(0,0,window.width,22));
  }
  void DrawAnimations() {
   GUILayout.Label(L.T("Більше = швидше. Зміни діють на наступну анімацію."));
   FastBox.Value=GUILayout.Toggle(FastBox.Value,L.T("Прискорити відкриття кришок коробки"));
   GUILayout.Label(L.T("Швидкість відкриття: ×")+BoxSpeed.Value.ToString("0.0",L.Culture)+L.T(" (1 — звичайна, 20 — найшвидша)"));
   BoxSpeed.Value=GUILayout.HorizontalSlider(BoxSpeed.Value,1f,20f);
   FastFades.Value=GUILayout.Toggle(FastFades.Value,L.T("Прискорити затемнення між коробкою та столом"));
   FastDrop.Value=GUILayout.Toggle(FastDrop.Value,L.T("Прискорити появу предметів і паузи між ними"));
   GUILayout.Label(L.T("Швидкість появи: ×")+DeskSpeed.Value.ToString("0.0",L.Culture));
   DeskSpeed.Value=GUILayout.HorizontalSlider(DeskSpeed.Value,1f,20f);
   FastCompletion.Value=GUILayout.Toggle(FastCompletion.Value,L.T("Прискорити екран після завершення чищення"));
   GUILayout.Label(L.T("Швидкість завершення: ×")+CompletionSpeed.Value.ToString("0.0",L.Culture));
   CompletionSpeed.Value=GUILayout.HorizontalSlider(CompletionSpeed.Value,1f,20f);
   ShortReadyDelay.Value=GUILayout.Toggle(ShortReadyDelay.Value,L.T("Експериментально: скоротити блокування інструментів"));
   if(ShortReadyDelay.Value) {
    GUILayout.Label(L.T("Очікування інструментів: ")+ReadyDelaySeconds.Value.ToString("0.0",L.Culture)+L.T(" с"));
    ReadyDelaySeconds.Value=GUILayout.HorizontalSlider(ReadyDelaySeconds.Value,0.5f,5f);
   }
  }
  void OnDestroy() {ModalInput.Shutdown();DarkTheme.Dispose();if(harmony!=null)harmony.UnpatchSelf();InventoryTable.RestoreNative();if(Instance==this)Instance=null;}
  internal static void LogArrival(string message) { if(Instance!=null)Instance.Logger.LogInfo("Arrival: "+message); }
 }

 internal static class AnimationPatches {
  internal static float BoxSeconds(float seconds) {return Plugin.Active&&Plugin.FastBox.Value?Mathf.Max(0.02f,seconds/Plugin.BoxSpeed.Value):seconds;}

  // Match duration arguments of the two verified LocalRotation calls, never the
  // rotation angle, repeat count, or completion callback.
  internal static IEnumerable<CodeInstruction> BoxTranspiler(IEnumerable<CodeInstruction> source) {
   var code=source.ToList();var matches=new HashSet<int>();
   for(int i=0;i+7<code.Count;i++) {
    var call=code[i+7].operand as MethodInfo;
    if(code[i].opcode==OpCodes.Ldc_R4 && (float)code[i].operand==1f &&
       code[i+1].opcode==OpCodes.Ldc_I4_6 && code[i+2].opcode==OpCodes.Ldc_I4_1 &&
       code[i+3].opcode==OpCodes.Ldc_I4_0 && code[i+4].opcode==OpCodes.Ldc_R4 && (float)code[i+4].operand==0f &&
       code[i+5].opcode==OpCodes.Ldc_R4 && (float)code[i+5].operand==0f && code[i+6].opcode==OpCodes.Ldc_I4_0 &&
       code[i+7].opcode==OpCodes.Call && call!=null && call.Name=="LocalRotation" && call.DeclaringType.FullName=="PrimeTween.Tween")matches.Add(i);
   }
   if(matches.Count!=2)throw new InvalidOperationException("Unsupported OpenParcel layout; expected 2 duration sites, found "+matches.Count);
   var result=new List<CodeInstruction>();
   for(int i=0;i<code.Count;i++){result.Add(code[i]);if(matches.Contains(i))result.Add(new CodeInstruction(OpCodes.Call,AccessTools.Method(typeof(AnimationPatches),"BoxSeconds")));}
   return result;
  }

  internal static void FadePrefix(string __0,ref float __1,ref float __2) {
   if(!Plugin.Active)return;
   if(IsCompletionScene(__0)){if(!Plugin.FastCompletion.Value)return;}
   else if(!Plugin.FastFades.Value||(__0!="cgr_ParcelUnpackingScene"&&__0!="cgr_LoadingPrepaintPreparationScene"&&__0!="cgr_CleaningStationScene"))return;
   __1=Mathf.Min(__1,Plugin.FadeMaxSeconds.Value);__2=Mathf.Min(__2,Plugin.FadeMaxSeconds.Value);
  }
  internal static void ReadyPrefix(ref float __0) {
   if(Plugin.Active&&Plugin.ShortReadyDelay.Value)__0=Mathf.Min(__0,Plugin.ReadyDelaySeconds.Value);
  }
  static readonly HashSet<string> reportedArrivals=new HashSet<string>();
  static bool IsArrivalScene(string name) {return name=="cgr_CleaningStationScene"||name=="cgr_ParcelUnpackingScene";}
  static bool IsCompletionScene(string name) {return name=="cgr_CelebrationScene"||name=="cgr_AddedToCollectionScreen1";}
  static bool InCompletion(Component owner) {return IsCompletionScene(owner.gameObject.scene.name)||IsCompletionScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene().name);}
  static bool ShouldSpeedArrival(Component owner) {
   if(!Plugin.Active||owner==null)return false;
   if(InCompletion(owner))return Plugin.FastCompletion.Value;
   return Plugin.FastDrop.Value&&(IsArrivalScene(owner.gameObject.scene.name)||IsArrivalScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene().name));
  }
  static void ReportArrival(Component owner) {
   string key=owner.GetInstanceID()+":"+owner.GetType().Name;
   if(reportedArrivals.Count>=128||!reportedArrivals.Add(key))return;
   Plugin.LogArrival("type="+owner.GetType().Name+" object="+owner.name+" scene="+owner.gameObject.scene.name+" active="+UnityEngine.SceneManagement.SceneManager.GetActiveScene().name+" speed="+Plugin.DeskSpeed.Value);
  }
  internal static float DropSeconds(float seconds,Component owner) {
   if(!ShouldSpeedArrival(owner))return seconds;
   ReportArrival(owner);return Mathf.Max(0.02f,seconds/(InCompletion(owner)?Plugin.CompletionSpeed.Value:Plugin.DeskSpeed.Value));
  }
  internal static float DropDelay(float seconds,Component owner) {
   return ShouldSpeedArrival(owner)?Mathf.Max(0f,seconds/(InCompletion(owner)?Plugin.CompletionSpeed.Value:Plugin.DeskSpeed.Value)):seconds;
  }
  internal static float TransformSeconds(float seconds,Component owner) {
   // Repeating idle motion is unrelated to the arrival and retains its speed.
   var cycles=AccessTools.Field(owner.GetType(),"maxCycles");
   if(cycles==null||(int)cycles.GetValue(owner)!=1)return seconds;
   return DropSeconds(seconds,owner);
  }
  internal static IEnumerable<CodeInstruction> SlideTranspiler(IEnumerable<CodeInstruction> source) {
   return ScaleFields(source,"tween3d_onappear_dropin",new Dictionary<string,string>{{"duration","DropSeconds"},{"delay","DropDelay"}},2);
  }
  internal static IEnumerable<CodeInstruction> SpacingTranspiler(IEnumerable<CodeInstruction> source) {
   return ScaleFields(source,"tween3d_onappear_dropin",new Dictionary<string,string>{{"delayBetweenActions","DropDelay"}},1);
  }
  internal static IEnumerable<CodeInstruction> TransformTranspiler(IEnumerable<CodeInstruction> source) {
   return ScaleFields(source,"tween3d_transformToFrom",new Dictionary<string,string>{{"duration","TransformSeconds"}},3);
  }
  static IEnumerable<CodeInstruction> ScaleFields(IEnumerable<CodeInstruction> source,string type,Dictionary<string,string> fields,int expected) {
   int count=0;var result=new List<CodeInstruction>();
   foreach(var ins in source) {
    result.Add(ins);var f=ins.operand as FieldInfo;string helper;
    if(ins.opcode!=OpCodes.Ldfld||f==null||f.DeclaringType.Name!=type||!fields.TryGetValue(f.Name,out helper))continue;
    count++;result.Add(new CodeInstruction(OpCodes.Ldarg_0));result.Add(new CodeInstruction(OpCodes.Call,AccessTools.Method(typeof(AnimationPatches),helper)));
   }
   if(count!=expected)throw new InvalidOperationException("Unsupported arrival layout for "+type+": "+count+" duration sites.");
   return result;
  }
  internal static IEnumerable<CodeInstruction> DropTranspiler(IEnumerable<CodeInstruction> source) {
   var code=source.ToList();int duration=0,delay=0;var result=new List<CodeInstruction>();
   foreach(var ins in code) {
    result.Add(ins);var f=ins.operand as FieldInfo;
    if(ins.opcode!=OpCodes.Ldfld||f==null||f.DeclaringType.Name!="tween3d_dropin_then_bob")continue;
    string helper=null;if(f.Name=="dropDuration"){duration++;helper="DropSeconds";}if(f.Name=="dropDelay"){delay++;helper="DropDelay";}
    if(helper!=null){result.Add(new CodeInstruction(OpCodes.Ldarg_0));result.Add(new CodeInstruction(OpCodes.Call,AccessTools.Method(typeof(AnimationPatches),helper)));}
   }
   if(duration!=1||delay!=1)throw new InvalidOperationException("Unsupported desk drop layout.");
   return result;
  }
 }
}













