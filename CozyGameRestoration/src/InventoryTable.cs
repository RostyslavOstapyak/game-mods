using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using BepInEx.Configuration;
using HarmonyLib;
using UnityEngine;

namespace CozyTweaks {
 internal static class InventoryTable {
  static ConfigEntry<bool> enabled,shelfActions,bonusHints;
  static CollectionsScreen screen;
  static NodePlacementManager shelf;
  static List<GameItem> games=new List<GameItem>();
  static List<GameItem> visible=new List<GameItem>();
  static readonly Dictionary<string,float> prices=new Dictionary<string,float>();
  static readonly Dictionary<string,string> bonuses=new Dictionary<string,string>();
  static readonly HashSet<string> placedSeeds=new HashSet<string>(StringComparer.Ordinal);
  static string selectedSeed="",search="",genre="",rarity="",sort="name",notice="";
  static bool descending;
  static int shelfFilter;
  static Vector2 scroll;
  static float logicalWidth,scale=1;
  static Rect panel; static bool collapsed; static Vector2 panelOffset;
  static GUIStyle rowStyle,selectedStyle,shelvedStyle;
  static readonly Dictionary<int,CanvasGroup> hidden=new Dictionary<int,CanvasGroup>();
  static readonly Dictionary<int,bool> pagination=new Dictionary<int,bool>();
  static readonly FieldInfo currentGames=AccessTools.Field(typeof(CollectionsScreen),"currentGamesList");
  static readonly FieldInfo currentGrid=AccessTools.Field(typeof(CollectionsScreen),"currentGridUI");
  static readonly FieldInfo shelfGrid=AccessTools.Field(typeof(NodePlacementManager),"currentGridUI");
  static readonly FieldInfo shelfNode=AccessTools.Field(typeof(NodePlacementManager),"currentNode");
  static readonly MethodInfo clickItem=AccessTools.Method(typeof(CollectionsScreen),"OnGameItemClicked");
  static readonly MethodInfo createItem=AccessTools.Method(typeof(CollectionsScreen),"CreateCollectionGridItem");
  static bool UseTable(CollectionsScreen s) {return Plugin.Active&&enabled.Value&&s!=null&&s.showInventory;}
  internal static void Initialize(ConfigFile config) {
   enabled=config.Bind("Inventory","TableView",true,"Scrollable compact inventory table. Original item selection and sale functions are retained.");
   shelfActions=config.Bind("Inventory","ShelfActions",true,"Use the same table when choosing a game for a shelf; allow sale of games not currently displayed.");
   bonusHints=config.Bind("Inventory","BonusHints",true,"Show the native genre-to-tool-bonus mapping. This is a bonus type, not a prediction of the final shelf total.");
   L.LanguageChanged+=()=>{bonuses.Clear();notice="";};
  }
  internal static bool PointerOverPanel {
   get {if(!IsVisible||Plugin.SettingsOpen)return false;var p=Input.mousePosition;return panel.Contains(new Vector2(p.x/scale,(Screen.height-p.y)/scale));}
  }
  internal static void StateChangingPrefix(GameStateManager __instance,GameState __0) {
   if(__instance.CurrentGameState==__0)return;
   shelf=null;
  }
  static bool IsVisible {get{return Plugin.Active&&enabled.Value&&((screen!=null&&screen.isActiveAndEnabled&&screen.showInventory)||(shelfActions.Value&&shelf!=null&&shelf.isActiveAndEnabled&&CurrentNode!=null&&CurrentNode.nodeSize==NodeSize.Game));}}
  static NodePlacementNode CurrentNode {get{return shelf==null?null:(NodePlacementNode)shelfNode.GetValue(shelf);}}
  internal static void BeforeCollection(CollectionsScreen __instance) {
   if(!Plugin.Active||!enabled.Value||!__instance.showInventory)return;
   int id=__instance.GetInstanceID();if(!pagination.ContainsKey(id))pagination[id]=__instance.usePagination;
   __instance.usePagination=false;
  }
  internal static void AfterCollection(CollectionsScreen __instance) {
   if(!Plugin.Active||!enabled.Value||!__instance.showInventory)return;
   if(screen!=__instance){scroll=Vector2.zero;search="";genre="";rarity="";shelfFilter=0;selectedSeed="";}
   screen=__instance;shelf=null;
   games=((List<GameItem>)currentGames.GetValue(screen)??new List<GameItem>()).ToList();
   HideGrid((GameObject)currentGrid.GetValue(screen));RefreshDataCaches();Rebuild();
  }
  // The table needs the inventory records, but not all their native image cards.
  // Retain native grid setup/cleanup; create a real card only upon selection so
  // the established native selection, preview and selling path remains intact.
  internal static bool PageItemsPrefix(CollectionsScreen __instance,ref List<GameItem> __result) {
   if(!UseTable(__instance))return true;
   __result=new List<GameItem>();return false;
  }
  internal static bool PageSnapshotPrefix(CollectionsScreen __instance) {return !UseTable(__instance);}
  internal static void ShelfPostfix(NodePlacementManager __instance) {
   if(!Plugin.Active||!enabled.Value||!shelfActions.Value)return;
   var node=(NodePlacementNode)shelfNode.GetValue(__instance);if(node==null||node.nodeSize!=NodeSize.Game)return;
   if(shelf!=__instance){scroll=Vector2.zero;selectedSeed="";}
   shelf=__instance;screen=null;
   RefreshShelfGames();HideGrid((GameObject)shelfGrid.GetValue(shelf));HideGrid((GameObject)AccessTools.Field(typeof(NodePlacementManager),"currentOverlay").GetValue(shelf));
  }
  static void RefreshShelfGames() {
   if(GameCollectionManager.Instance==null)return;
   games=GameCollectionManager.Instance.GetPlayerGameInventory().ToList();RefreshDataCaches();Rebuild();
  }
  static void HideGrid(GameObject grid) {
   if(grid==null)return;int id=grid.GetInstanceID();CanvasGroup group;
   if(!hidden.TryGetValue(id,out group)||group==null){group=grid.AddComponent<CanvasGroup>();hidden[id]=group;}
   group.alpha=0;group.blocksRaycasts=false;group.interactable=false;
  }
  internal static void RestoreNative() {
   foreach(var group in hidden.Values)if(group!=null){group.alpha=1;group.blocksRaycasts=true;group.interactable=true;UnityEngine.Object.Destroy(group);}hidden.Clear();
   if(screen!=null){bool original;if(pagination.TryGetValue(screen.GetInstanceID(),out original))screen.usePagination=original;screen.RefreshCollection();}
   pagination.Clear();screen=null;shelf=null;
  }
  internal static void RefreshActive() {
   var s=UnityEngine.Object.FindObjectsOfType<CollectionsScreen>().FirstOrDefault(s=>s.showInventory&&s.isActiveAndEnabled);if(s!=null)s.RefreshCollection();
  }
  internal static void DisableAfterError() {enabled.Value=false;RestoreNative();}
  static int RarityRank(string s) {switch((s??"").ToLowerInvariant()){case "regular":case "common":return 0;case "uncommon":return 1;case "rare":return 2;case "epic":return 3;case "legendary":return 4;case "developer":return 5;default:return -1;}}
  static float Price(GameItem game) {float value;return prices.TryGetValue(game.seed??game.id,out value)?value:0f;}
  static string Genres(GameItem game) {return string.IsNullOrEmpty(game.genre2)?game.genre1:game.genre1+" / "+game.genre2;}
  internal static string Bonus(GameItem game) {
   string cached;if(bonuses.TryGetValue(game.seed??game.id,out cached))return cached;
   return CalculateBonus(game);
  }
  static string CalculateBonus(GameItem game) {
   var result=new List<string>();
   foreach(var g in new[]{game.genre1,game.genre2}.Where(g=>!string.IsNullOrEmpty(g))) {
    var stat=ShelfBonusCalculator.GetToolStatPropertyForGenre(g);if(!stat.HasValue)continue;
    string label=stat.Value==ToolStatProperty.Capacity?L.T("Місткість"):stat.Value==ToolStatProperty.Power?L.T("Сила чищення"):L.T("Площа чищення");
    if(!result.Contains(label))result.Add(label);
   }
   return result.Count==0?"—":string.Join(" / ",result.ToArray());
  }
  static void RefreshDataCaches() {
   prices.Clear();bonuses.Clear();
   foreach(var game in games.Where(g=>g!=null)){string key=game.seed??game.id;prices[key]=game.getSalePrice();bonuses[key]=CalculateBonus(game);}
   RefreshPlacementCache();
  }
  static void RefreshPlacementCache() {
   placedSeeds.Clear();
   if(ShelfBonusManager.Instance!=null) {
    foreach(var game in games.Where(g=>g!=null&&!string.IsNullOrEmpty(g.seed)))if(ShelfBonusManager.Instance.IsGameOnShelf(game.seed))placedSeeds.Add(game.seed);
   } else if(PlayerProgress.Instance!=null&&PlayerProgress.Instance.StationPlacementData!=null) {
    var state=PlayerProgress.Instance.StationPlacementData;
    foreach(var node in new[]{state.cleaningdesk,state.unwrappingdesk,state.displayshelf}.Where(list=>list!=null).SelectMany(list=>list))
     if(node!=null&&node.placedItemType==NodeSize.Game&&!string.IsNullOrEmpty(node.placedItemSeed))placedSeeds.Add(node.placedItemSeed);
   }
  }
  internal static void PlacementChangedPostfix() {
   if(!IsVisible)return;
   RefreshDataCaches();Rebuild();
  }
  static void Rebuild() {
   IEnumerable<GameItem> query=games.Where(g=>g!=null);
   if(search.Length>0)query=query.Where(g=>((g.title??"")+" "+g.platform+" "+g.id).IndexOf(search,StringComparison.OrdinalIgnoreCase)>=0);
   if(genre.Length>0)query=query.Where(g=>g.genre1==genre||g.genre2==genre);
   if(rarity.Length>0)query=query.Where(g=>g.rarity==rarity);
   if(shelfFilter==1)query=query.Where(g=>placedSeeds.Contains(g.seed));
   if(shelfFilter==2)query=query.Where(g=>!placedSeeds.Contains(g.seed));
   IOrderedEnumerable<GameItem> ordered;
   if(sort=="price")ordered=descending?query.OrderByDescending(Price):query.OrderBy(Price);
   else if(sort=="rarity")ordered=descending?query.OrderByDescending(g=>RarityRank(g.rarity)):query.OrderBy(g=>RarityRank(g.rarity));
   else if(sort=="genre")ordered=descending?query.OrderByDescending(Genres,StringComparer.OrdinalIgnoreCase):query.OrderBy(Genres,StringComparer.OrdinalIgnoreCase);
   else ordered=descending?query.OrderByDescending(g=>g.title,StringComparer.OrdinalIgnoreCase):query.OrderBy(g=>g.title,StringComparer.OrdinalIgnoreCase);
   visible=ordered.ThenBy(g=>g.title,StringComparer.OrdinalIgnoreCase).ThenBy(g=>g.seed,StringComparer.Ordinal).ToList();
   if(selectedSeed.Length>0&&!games.Any(g=>g.seed==selectedSeed))selectedSeed="";
  }
  internal static void DrawSettings() {
   bool value=GUILayout.Toggle(enabled.Value,L.T("Таблиця інвентарю зі звичайним прокручуванням"));
   if(value!=enabled.Value){enabled.Value=value;if(!value)RestoreNative();else {var s=UnityEngine.Object.FindObjectsOfType<CollectionsScreen>().FirstOrDefault(s=>s.showInventory&&s.isActiveAndEnabled);if(s!=null)s.RefreshCollection();}}
   bool useShelf=GUILayout.Toggle(shelfActions.Value,L.T("Така сама таблиця й продаж під час вибору гри для полиці"));if(useShelf!=shelfActions.Value){shelfActions.Value=useShelf;if(!useShelf)RestoreNative();else RefreshActive();}
   bonusHints.Value=GUILayout.Toggle(bonusHints.Value,L.T("Показувати тип бонусу жанру"));
   GUILayout.Label(L.T("Ціна — фактична поточна ціна продажу за формулою гри."));
   GUILayout.Label(L.T("Сортування, пошук і фільтри розташовані над таблицею."));
   GUILayout.Label(L.T("Продаж гри з полиці доступний після її зняття."));
  }
  internal static void Draw() {
   if(!IsVisible)return;
   scale=Mathf.Clamp(Screen.height/900f,0.8f,2f);logicalWidth=Screen.width/scale;
   var oldMatrix=GUI.matrix;GUI.matrix=Matrix4x4.Scale(new Vector3(scale,scale,1));
   float height=Screen.height/scale;float width=Mathf.Clamp(logicalWidth*0.45f,620,1100);
   panel=new Rect(Mathf.Clamp(16+panelOffset.x,0,logicalWidth-width),Mathf.Clamp(height*0.19f+panelOffset.y,0,height-36),width,collapsed?36:height*0.76f);
   var e=Event.current;int dragId=GUIUtility.GetControlID(741838,FocusType.Passive);
   var header=new Rect(panel.x,panel.y,panel.width-120,24);
   if(e.type==EventType.MouseDown&&e.button==0&&header.Contains(e.mousePosition)){GUIUtility.hotControl=dragId;e.Use();}
   if(e.type==EventType.MouseDrag&&GUIUtility.hotControl==dragId){panelOffset+=e.delta;e.Use();}
   if(e.type==EventType.MouseUp&&GUIUtility.hotControl==dragId){GUIUtility.hotControl=0;e.Use();}
   var oldColor=GUI.color;GUI.color=new Color(0.06f,0.075f,0.10f,0.98f);GUI.DrawTexture(panel,Texture2D.whiteTexture);GUI.color=oldColor;
   GUILayout.BeginArea(panel,GUI.skin.box);
   GUILayout.BeginHorizontal();GUILayout.Label((shelf!=null?L.T("ІНВЕНТАР • ВИБІР ДЛЯ ПОЛИЦІ • "):L.T("ІНВЕНТАР • "))+visible.Count+" / "+games.Count+L.T(" • На полиці: ")+games.Count(g=>placedSeeds.Contains(g.seed)));if(GUILayout.Button(collapsed?L.T("Розгорнути"):L.T("Згорнути"),GUILayout.Width(100)))collapsed=!collapsed;GUILayout.EndHorizontal();if(collapsed){GUILayout.EndArea();GUI.matrix=oldMatrix;return;}
   GUILayout.BeginHorizontal();GUILayout.Label(L.T("Пошук"),GUILayout.Width(46));string next=GUILayout.TextField(search,GUILayout.MinWidth(130));if(next!=search){search=next;scroll=Vector2.zero;Rebuild();}
   if(GUILayout.Button(L.T("Скинути"),GUILayout.Width(80))){search="";genre="";rarity="";shelfFilter=0;scroll=Vector2.zero;Rebuild();}GUILayout.EndHorizontal();
   GUILayout.BeginHorizontal();GUILayout.Label(L.T("Порядок"),GUILayout.Width(55));
   foreach(var key in new[]{"name","genre","rarity","price"}) { string label=key=="name"?L.T("Назва"):key=="genre"?L.T("Жанр"):key=="rarity"?L.T("Рідкість"):L.T("Ціна"); if(GUILayout.Button(label+(sort==key?(descending?" ↓":" ↑"):""))){if(sort==key)descending=!descending;else{sort=key;descending=key=="price"||key=="rarity";}scroll=Vector2.zero;Rebuild();} }
   GUILayout.EndHorizontal();
   GUILayout.BeginHorizontal();
   if(GUILayout.Button(L.T("Жанр: ")+(genre.Length==0?L.T("усі"):genre))) {var options=new[]{""}.Concat(games.SelectMany(g=>new[]{g.genre1,g.genre2}).Where(g=>!string.IsNullOrEmpty(g)).Distinct().OrderBy(g=>g)).ToArray();genre=options[(Array.IndexOf(options,genre)+1)%options.Length];scroll=Vector2.zero;Rebuild();}
   if(GUILayout.Button(L.T("Рідкість: ")+(rarity.Length==0?L.T("усі"):rarity))) {var options=new[]{""}.Concat(games.Select(g=>g.rarity).Where(g=>!string.IsNullOrEmpty(g)).Distinct().OrderBy(RarityRank)).ToArray();rarity=options[(Array.IndexOf(options,rarity)+1)%options.Length];scroll=Vector2.zero;Rebuild();}
   if(GUILayout.Button(L.T("Полиця: ")+new[]{L.T("усі"),L.T("на полиці"),L.T("поза полицею")}[shelfFilter])){shelfFilter=(shelfFilter+1)%3;scroll=Vector2.zero;Rebuild();}
   GUILayout.EndHorizontal();
   if(rowStyle==null){rowStyle=new GUIStyle(GUI.skin.button){alignment=TextAnchor.MiddleLeft,fontSize=13};selectedStyle=new GUIStyle(rowStyle);selectedStyle.normal.textColor=Color.yellow;shelvedStyle=new GUIStyle(rowStyle);shelvedStyle.normal.textColor=shelvedStyle.hover.textColor=shelvedStyle.active.textColor=new Color(0.4f,0.9f,0.8f);}
   float footer=bonusHints.Value?115:88;
   float scrollHeight=Mathf.Max(100,panel.height-110-footer);
   scroll=GUILayout.BeginScrollView(scroll,GUILayout.Height(scrollHeight));
   foreach(var game in visible) {
    GUILayout.BeginHorizontal();
    bool onDisplay=placedSeeds.Contains(game.seed);
    string label=(game.seed==selectedSeed?"▶ ":"")+(onDisplay?L.T("[На полиці] "):"")+(game.title??game.id)+"  •  "+Genres(game);
    if(GUILayout.Button(new GUIContent(label,bonusHints.Value?Bonus(game):""),game.seed==selectedSeed?selectedStyle:onDisplay?shelvedStyle:rowStyle,GUILayout.Height(22),GUILayout.Width(Mathf.Max(180,width-185))))Select(game);
    GUILayout.Label(game.rarity??"",GUILayout.Width(85));GUILayout.Label("$"+Price(game).ToString("0.00",L.Culture),GUILayout.Width(65));
    GUILayout.EndHorizontal();
   }
   GUILayout.EndScrollView();
   var selected=games.FirstOrDefault(g=>g.seed==selectedSeed);
   if(selected!=null) {
    GUILayout.Label(selected.title+" • "+Genres(selected));
    if(bonusHints.Value)GUILayout.Label(L.T("Бонус жанру: ")+Bonus(selected));
    GUILayout.BeginHorizontal();bool onShelf=IsOnShelf(selected);bool allowed=GUI.enabled;
    GUI.enabled=allowed&&!onShelf;
    if(GUILayout.Button(onShelf?L.T("Спершу зніми з полиці"):L.T("Продати за $")+Price(selected).ToString("0.00",L.Culture)))Sell(selected);
    GUI.enabled=allowed;
    if(shelf!=null) {GUI.enabled=allowed&&!onShelf;if(GUILayout.Button(L.T("Поставити на вибране місце")))Place(selected);GUI.enabled=allowed;}
    GUILayout.EndHorizontal();
   } else GUILayout.Label(L.T("Обери гру в таблиці."));
   if(shelf!=null&&CurrentNode!=null&&CurrentNode.placedOption!=null&&GUILayout.Button(L.T("Зняти гру з вибраного місця"))){shelf.RemoveCurrentNodeItem(CurrentNode);shelf.SaveButton();RefreshShelfGames();}
   if(notice.Length>0)GUILayout.Label(notice);
   else if(bonusHints.Value)GUILayout.Label(L.T("Бонус залежить від сусідства однакових жанрів і рідкості; тут показано тип."));
   GUILayout.EndArea();GUI.matrix=oldMatrix;
  }
  static bool IsOnShelf(GameItem game) {
   if(ShelfBonusManager.Instance!=null)return ShelfBonusManager.Instance.IsGameOnShelf(game.seed);
   // In inventory the room manager may not be loaded. Protect against stale
   // placements by consulting the same saved placement lists used by the game.
   if(PlayerProgress.Instance==null)return false;
   var state=PlayerProgress.Instance.StationPlacementData;
   if(state==null)return false;
   return new[]{state.cleaningdesk,state.unwrappingdesk,state.displayshelf}.Where(list=>list!=null).SelectMany(list=>list).Any(node=>node!=null&&node.placedItemType==NodeSize.Game&&node.placedItemSeed==game.seed);
  }
  static void Select(GameItem game) {
   selectedSeed=game.seed;notice="";
   if(screen!=null) {
    if(screen.GetGridItemBySeed(game.seed)==null) {
     var grid=(GameObject)currentGrid.GetValue(screen);
     var content=grid==null?null:grid.transform.Find("Scroll View/Viewport/Content");
     if(content==null)throw new InvalidOperationException("Native inventory content is missing.");
     createItem.Invoke(screen,new object[]{game,content});
    }
    clickItem.Invoke(screen,new object[]{game});
   }
  }
  static void Sell(GameItem game) {
   if(IsOnShelf(game)){notice=L.T("Спершу зніми цю гру з полиці.");return;}
   var existing=GameCollectionManager.Instance.GetPlayerGameInventory().FirstOrDefault(g=>g.seed==game.seed);
   if(existing==null){notice=L.T("Цієї копії вже немає в інвентарі.");return;}
   if(screen!=null){Select(existing);screen.SellSelectedGame();}
   else if(shelf!=null) {
    PlayerProgress.Instance.SellGame(existing);
    shelf.allOptions.RemoveAll(o=>o.size==NodeSize.Game&&o.seed==existing.seed);
    shelf.RefreshGridUIPlacementStates();RefreshShelfGames();
   }
   selectedSeed="";notice=L.T("Продано. Позицію прокручування збережено.");
  }
  static void Place(GameItem game) {
   if(shelf==null||CurrentNode==null||IsOnShelf(game))return;
   var option=shelf.allOptions.FirstOrDefault(o=>o.size==NodeSize.Game&&o.seed==game.seed);
   if(option==null){notice=L.T("Гра недоступна для цього місця. Обери місце ще раз.");return;}
   shelf.OnOptionClicked(option);shelf.SaveButton();notice=L.T("Розміщено на вибраному місці.");RefreshShelfGames();
  }
 }
}












