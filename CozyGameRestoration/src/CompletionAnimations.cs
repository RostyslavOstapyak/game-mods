using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Reflection.Emit;
using HarmonyLib;
using UnityEngine;

namespace CozyTweaks {
 internal static class CompletionAnimations {
  internal static float Seconds(float seconds) {return Plugin.Active&&Plugin.FastCompletion.Value?Mathf.Max(0.02f,seconds/Plugin.CompletionSpeed.Value):seconds;}
  internal static void Install(Harmony harmony,Action<string> log) {
   foreach(var type in typeof(cgr_CelebrationScreenManager).GetNestedTypes(BindingFlags.NonPublic).Where(t=>t.Name.StartsWith("<GoToCollectionRoomScene>")||t.Name.StartsWith("<GoToInventoryScene>")))
    Patch(harmony,AccessTools.Method(type,"MoveNext"),"ExitTranspiler",log);
   Patch(harmony,AccessTools.Method(typeof(CGR_CollectionScreenManager),"Start"),"DelayTranspiler",log);
   Patch(harmony,AccessTools.Method(typeof(CollectionsScreen),"PlayCelebrationAnimation"),"CardTranspiler",log);
   foreach(var spec in new[]{new[]{"tween2d_onappear_fade","Play"},new[]{"tween2d_onappear_movein","Play"},new[]{"tween2d_onappear_scale","Play"},new[]{"tween3d_onappear_scale","Play"},new[]{"tween3d_onappear_fade","OnEnable"}}) {
    var type=AccessTools.TypeByName(spec[0]);if(type!=null)Patch(harmony,AccessTools.Method(type,spec[1]),"ComponentTranspiler",log);
   }
  }
  static void Patch(Harmony harmony,MethodBase method,string name,Action<string> log) {
   if(method==null){log("Completion animation target unavailable: "+name);return;}
   try {harmony.Patch(method,transpiler:new HarmonyMethod(typeof(CompletionAnimations),name));log("Completion animation: "+method.DeclaringType.Name+"."+method.Name);}catch(Exception e){log("Completion patch skipped: "+e.Message);}
  }
  static IEnumerable<CodeInstruction> ExitTranspiler(IEnumerable<CodeInstruction> input) {
   var code=input.ToList();var result=new List<CodeInstruction>();int count=0;
   for(int i=0;i<code.Count;i++) {
    result.Add(code[i]);if(code[i].opcode!=OpCodes.Ldc_R4||i+1>=code.Count)continue;
    float value=(float)code[i].operand;var field=code[i+1].operand as FieldInfo;
    bool duration=value==0.4f&&code[i+1].opcode==OpCodes.Stloc_2;
    bool hold=value==1f&&code[i+1].opcode==OpCodes.Stfld&&field!=null&&field.Name.Contains("snapshotHoldDuration");
    if(duration||hold){result.Add(new CodeInstruction(OpCodes.Call,AccessTools.Method(typeof(CompletionAnimations),"Seconds")));count++;}
   }
   if(count!=2)throw new InvalidOperationException("Unsupported completion transition layout: "+count);return result;
  }
  static IEnumerable<CodeInstruction> DelayTranspiler(IEnumerable<CodeInstruction> input) {
   var result=new List<CodeInstruction>();int count=0;
   foreach(var instruction in input){result.Add(instruction);var f=instruction.operand as FieldInfo;if(instruction.opcode==OpCodes.Ldfld&&f!=null&&f.DeclaringType==typeof(CGR_CollectionScreenManager)&&f.Name=="celebrationDelay"){result.Add(new CodeInstruction(OpCodes.Call,AccessTools.Method(typeof(CompletionAnimations),"Seconds")));count++;}}
   if(count!=1)throw new InvalidOperationException("Unsupported collection delay layout.");return result;
  }
  static IEnumerable<CodeInstruction> CardTranspiler(IEnumerable<CodeInstruction> input) {
   var code=input.ToList();var result=new List<CodeInstruction>();int count=0;
   for(int i=0;i<code.Count;i++) {
    result.Add(code[i]);if(code[i].opcode!=OpCodes.Ldc_R4||i+7>=code.Count)continue;
    var call=code[i+7].operand as MethodInfo;
    if(call!=null&&call.DeclaringType.FullName=="PrimeTween.Tween"&&call.Name=="Scale"&&code[i+2].opcode==OpCodes.Ldc_I4_1&&code[i+3].opcode==OpCodes.Ldc_I4_0){result.Add(new CodeInstruction(OpCodes.Call,AccessTools.Method(typeof(CompletionAnimations),"Seconds")));count++;}
   }
   if(count!=3)throw new InvalidOperationException("Unsupported collection celebration layout: "+count);return result;
  }
  static float ComponentSeconds(float seconds,Component owner) {
   if(seconds<=0||owner==null||!Plugin.Active||!Plugin.FastCompletion.Value)return seconds;
   string own=owner.gameObject.scene.name,active=UnityEngine.SceneManagement.SceneManager.GetActiveScene().name;
   return own=="cgr_CelebrationScene"||own=="cgr_AddedToCollectionScreen1"||active=="cgr_CelebrationScene"||active=="cgr_AddedToCollectionScreen1"?Seconds(seconds):seconds;
  }
  static IEnumerable<CodeInstruction> ComponentTranspiler(IEnumerable<CodeInstruction> input) {
   var result=new List<CodeInstruction>();int count=0;
   foreach(var instruction in input) {
    result.Add(instruction);var f=instruction.operand as FieldInfo;
    if(instruction.opcode!=OpCodes.Ldfld||f==null||f.FieldType!=typeof(float)||(f.Name!="duration"&&f.Name!="startDelay"))continue;
    result.Add(new CodeInstruction(OpCodes.Ldarg_0));result.Add(new CodeInstruction(OpCodes.Call,AccessTools.Method(typeof(CompletionAnimations),"ComponentSeconds")));count++;
   }
   if(count==0)throw new InvalidOperationException("Completion component has no duration sites.");return result;
  }
 }
}







