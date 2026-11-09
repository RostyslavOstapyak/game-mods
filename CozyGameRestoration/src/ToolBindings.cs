using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Reflection.Emit;
using BepInEx.Configuration;
using HarmonyLib;
using UnityEngine;

namespace CozyTweaks {
 internal static class ToolBindings {
  static ConfigEntry<bool> enabled;
  static ConfigEntry<KeyboardShortcut>[] keys;
  static int capture=-1,ignoreThroughFrame;
  static string message="";
  static CGR_Toolbar_CleaningToolSelector selector;
  internal static void Initialize(ConfigFile config) {
   enabled=config.Bind("Tools","CustomBindings",false,"Enable the eight custom keyboard/mouse tool bindings. Controller mappings remain native.");
   L.LanguageChanged+=()=>{message="";};
   keys=new ConfigEntry<KeyboardShortcut>[8];
   for(int i=0;i<8;i++)keys[i]=config.Bind("ToolBindings","Tool"+(i+1),new KeyboardShortcut((KeyCode)((int)KeyCode.Alpha1+i)),"Custom shortcut for toolbar slot "+(i+1)+". None disables this slot's keyboard shortcut.");
  }
  internal static IEnumerable<CodeInstruction> InputTranspiler(IEnumerable<CodeInstruction> source) {
   int count=0;var result=new List<CodeInstruction>();
   foreach(var instruction in source) {
    var call=instruction.operand as MethodInfo;
    if(call!=null&&call.DeclaringType==typeof(Rewired.Player)&&call.Name=="GetButtonDown"&&call.GetParameters().Length==1&&call.GetParameters()[0].ParameterType==typeof(string)) {
     result.Add(new CodeInstruction(OpCodes.Call,AccessTools.Method(typeof(ToolBindings),"GetButtonDown")){labels=instruction.labels,blocks=instruction.blocks});count++;
    } else result.Add(instruction);
   }
   if(count!=12)throw new InvalidOperationException("Unsupported hotkey layout: "+count+" action reads.");
   return result;
  }
  static bool GetButtonDown(Rewired.Player player,string action) {
   if(ModalInput.Blocked||Time.frameCount<=ignoreThroughFrame)return false;
   if(!Plugin.Active||!enabled.Value)return player.GetButtonDown(action);
   if(!action.StartsWith("HotKeyTool",StringComparison.Ordinal)) {
    bool native=player.GetButtonDown(action);
    if(native&&!player.IsCurrentInputSource(action,Rewired.ControllerType.Joystick)&&keys.Any(k=>k.Value.MainKey!=KeyCode.None&&k.Value.IsDown()))return false;
    return native;
   }
   int slot;if(!int.TryParse(action.Substring(10),out slot)||slot<1||slot>8)return player.GetButtonDown(action);
   if(player.GetButtonDown(action)&&player.IsCurrentInputSource(action,Rewired.ControllerType.Joystick))return true;
   return keys[slot-1].Value.MainKey!=KeyCode.None&&keys[slot-1].Value.IsDown();
  }
  internal static void SelectorPostfix(CGR_Toolbar_CleaningToolSelector __instance) {selector=__instance;}
  internal static bool InputPrefix() {return !ModalInput.Blocked&&!InventoryTable.PointerOverPanel;}
  internal static void CancelCapture() {capture=-1;}
  internal static void Draw() {
   enabled.Value=GUILayout.Toggle(enabled.Value,L.T("Власні клавіші інструментів"));
   GUILayout.Label(L.T("Натисни кнопку навпроти інструмента, потім клавішу або кнопку миші."));
   GUILayout.Label(L.T("Підтримуються Ctrl / Shift / Alt. Esc — скасувати; Delete — прибрати прив’язку."));
   if(capture>=0)CaptureEvent();
   for(int i=0;i<8;i++) {
    GUILayout.BeginHorizontal();
    string name=L.T("Інструмент ")+(i+1);
    if(selector!=null&&selector.cleaningTools!=null&&i<selector.cleaningTools.Length&&selector.cleaningTools[i]!=null)name=(i+1)+". "+selector.cleaningTools[i].name;
    GUILayout.Label(name,GUILayout.Width(270));
    if(GUILayout.Button(capture==i?L.T("Натисни нову клавішу…"):keys[i].Value.ToString(),GUILayout.Width(210))){capture=i;message="";}
    GUILayout.EndHorizontal();
   }
   if(message.Length>0)GUILayout.Label(message);
   GUILayout.Label(L.T("Назви беруться з панелі інструментів після входу на робочий стіл."));
   if(GUILayout.Button(L.T("Відновити клавіші 1–8")))for(int i=0;i<8;i++)keys[i].Value=new KeyboardShortcut((KeyCode)((int)KeyCode.Alpha1+i));
  }
  static void CaptureEvent() {
   var e=Event.current;if(e==null)return;
   KeyCode main=KeyCode.None;
   if(e.type==EventType.KeyDown) {
    if(e.keyCode==KeyCode.Escape){capture=-1;e.Use();return;}
    if(e.keyCode==KeyCode.Delete){keys[capture].Value=KeyboardShortcut.Empty;capture=-1;e.Use();return;}
    main=e.keyCode;
   } else if(e.type==EventType.MouseDown)main=(KeyCode)((int)KeyCode.Mouse0+e.button);
   if(main==KeyCode.None||main==KeyCode.LeftControl||main==KeyCode.RightControl||main==KeyCode.LeftAlt||main==KeyCode.RightAlt||main==KeyCode.LeftShift||main==KeyCode.RightShift)return;
   if(main==KeyCode.F10||main==KeyCode.F8){message=L.T("F10 та F8 залишені для керування модом. Обери іншу клавішу.");e.Use();return;}
   var mods=new List<KeyCode>();
   foreach(var k in new[]{KeyCode.LeftControl,KeyCode.RightControl,KeyCode.LeftShift,KeyCode.RightShift,KeyCode.LeftAlt,KeyCode.RightAlt})if(Input.GetKey(k))mods.Add(k);
   var shortcut=new KeyboardShortcut(main,mods.ToArray());
   for(int i=0;i<8;i++)if(i!=capture&&keys[i].Value.Equals(shortcut)){message=L.T("Ця комбінація вже зайнята інструментом ")+(i+1)+L.T(". Обери іншу.");e.Use();return;}
   keys[capture].Value=shortcut;enabled.Value=true;message=L.T("Збережено: ")+shortcut;capture=-1;ignoreThroughFrame=Time.frameCount+1;e.Use();
  }
 }
}










