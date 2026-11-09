using System;
using System.Linq;
using System.Reflection;
using HarmonyLib;
using UnityEngine;
using UnityEngine.EventSystems;

namespace CozyTweaks {
 internal static class ModalInput {
  static bool open,releaseBarrier;
  static int blockedThroughFrame;
  static float previousTimeScale;
  static bool previousCursorVisible;
  static CursorLockMode previousCursorLock;
  internal static bool Blocked {get{return open||releaseBarrier||Time.frameCount<=blockedThroughFrame;}}
  internal static void Open() {
   if(open)return;
   previousTimeScale=Time.timeScale;Time.timeScale=0f;
   previousCursorVisible=Cursor.visible;previousCursorLock=Cursor.lockState;Cursor.lockState=CursorLockMode.None;Cursor.visible=true;
   open=true;releaseBarrier=false;
   ClearNativePointers();
  }
  internal static void Close() {
   if(!open)return;
   open=false;releaseBarrier=true;blockedThroughFrame=Time.frameCount+2;
   Time.timeScale=previousTimeScale;
   Cursor.lockState=previousCursorLock;Cursor.visible=previousCursorVisible;
   ClearNativePointers();
  }
  internal static void Update() {
   if(releaseBarrier&&Time.frameCount>blockedThroughFrame&&!Input.anyKey)releaseBarrier=false;
  }
  internal static void Shutdown() {
   if(open){Time.timeScale=previousTimeScale;Cursor.lockState=previousCursorLock;Cursor.visible=previousCursorVisible;}
   open=false;releaseBarrier=false;blockedThroughFrame=-1;
  }
  static void ClearNativePointers() {
   foreach(var system in UnityEngine.Object.FindObjectsOfType<EventSystem>()) {
    if(system.currentInputModule!=null)system.currentInputModule.DeactivateModule();
    system.SetSelectedGameObject(null);
   }
  }
  internal static bool AllowGameInput() {return !Blocked&&!InventoryTable.PointerOverPanel;}
  internal static bool BlockButton(ref bool __result) {if(!Blocked)return true;__result=false;return false;}
  internal static bool BlockAxis(ref float __result) {if(!Blocked)return true;__result=0f;return false;}
  internal static void Install(Harmony harmony,Action<string> log) {
   var prefix=new HarmonyMethod(typeof(ModalInput),"AllowGameInput");int count=0;
   // Unity UI must not receive pointer, wheel or submit events from the IMGUI
   // settings window. The mod itself does not depend on EventSystem processing.
   count+=Patch(harmony,AccessTools.Method(typeof(EventSystem),"Update"),prefix,log);
   count+=Patch(harmony,AccessTools.Method(typeof(UnityEngine.UI.Button),"Press"),prefix,log);
   foreach(var method in typeof(Rewired.Player).GetMethods(BindingFlags.Public|BindingFlags.Instance|BindingFlags.DeclaredOnly).Where(m=>!m.IsGenericMethod)) {
    if(method.ReturnType==typeof(bool)&&new[]{"GetButton","GetButtonDown","GetButtonUp","GetNegativeButton","GetNegativeButtonDown","GetNegativeButtonUp"}.Contains(method.Name))
     count+=Patch(harmony,method,new HarmonyMethod(typeof(ModalInput),"BlockButton"),log);
    else if(method.ReturnType==typeof(float)&&(method.Name=="GetAxis"||method.Name=="GetAxisRaw"))
     count+=Patch(harmony,method,new HarmonyMethod(typeof(ModalInput),"BlockAxis"),log);
   }
   foreach(var typeName in new[]{"CGRGlobalHotkeys","CGRDraggableObjectsManager","CGRNodeSnappableDraggable","CGRInteractableSelectionManager","CGR3DInspectionManager","cgr_InspectionInputSystem","InteractableObjectsManager","RewiredSurfaceFollower","RewiredSurfaceFollowerTape","RewiredSurfaceFollowerTape_v2","RewiredSurfaceFollowerTapeScreenSpaceGrab","RewiredSurfaceFollowerTapeScreenSpaceGrab_v2","CGRFoamGrabber","CGRColliderGrabber","CGR_ObiRayCastClothCheck"}) {
    var type=AccessTools.TypeByName(typeName);if(type==null)continue;
    foreach(var methodName in new[]{"Update","FixedUpdate","LateUpdate"}) {
     var method=type.GetMethod(methodName,BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance|BindingFlags.DeclaredOnly);
     if(method!=null)count+=Patch(harmony,method,prefix,log);
    }
   }
   Type[] gameTypes;try {gameTypes=typeof(CollectionsScreen).Assembly.GetTypes();}catch(ReflectionTypeLoadException e){gameTypes=e.Types.Where(t=>t!=null).ToArray();}
   foreach(var type in gameTypes.Where(t=>typeof(MonoBehaviour).IsAssignableFrom(t)))
    foreach(var method in type.GetMethods(BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance|BindingFlags.DeclaredOnly).Where(m=>!m.IsAbstract&&!m.IsGenericMethod&&(m.Name=="OnMouseDown"||m.Name=="OnMouseUp"||m.Name=="OnMouseDrag")))
     count+=Patch(harmony,method,prefix,log);
   // PaintCore has its own pointer path, separate from Unity UI and Rewired.
   foreach(var assembly in AppDomain.CurrentDomain.GetAssemblies().Where(a=>a.GetName().Name=="PaintCore"||a.GetName().Name=="CW.Common")) {
    Type[] types;try {types=assembly.GetTypes();}catch(ReflectionTypeLoadException e){types=e.Types.Where(t=>t!=null).ToArray();}
    foreach(var type in types.Where(t=>t.Name.StartsWith("CwHit",StringComparison.Ordinal)||t.Name=="CwInputManager"))
     foreach(var method in type.GetMethods(BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance|BindingFlags.DeclaredOnly).Where(m=>!m.IsAbstract&&!m.IsGenericMethod&&(m.Name=="Update"||m.Name=="FixedUpdate"||m.Name=="LateUpdate"||m.Name=="HandleFingerUpdate")))
      count+=Patch(harmony,method,prefix,log);
   }
   log("Modal input guards installed: "+count);
  }
  static int Patch(Harmony harmony,MethodBase target,HarmonyMethod prefix,Action<string> log) {
   if(target==null)return 0;
   try {harmony.Patch(target,prefix:prefix);return 1;}catch(Exception e){log("Modal guard unavailable: "+target.DeclaringType.Name+"."+target.Name+": "+e.Message);return 0;}
  }
 }
}









