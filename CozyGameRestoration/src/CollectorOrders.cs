using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using BepInEx.Configuration;
using HarmonyLib;
using UnityEngine;
using BepInEx;

namespace CozyTweaks {
 [BepInPlugin(Id,"Collector Orders","0.5.2")]
 [BepInDependency(Plugin.Id,"0.5.2")]
 [BepInProcess("CozyGameRestoration.exe")]
 public sealed class CollectorOrdersPlugin:BaseUnityPlugin {
  public const string Id="cozytweaks.collectororders";
  Harmony harmony;
  void Awake() {
   CollectorOrders.Initialize(Config);
   Plugin.RegisterSettingsPage(Id,()=>L.T("Замовлення"),CollectorOrders.Draw);
   harmony=new Harmony(Id);
   harmony.Patch(AccessTools.Method(typeof(PlayerProgress),"CollectGame"),postfix:new HarmonyMethod(typeof(CollectorOrders),"CollectedPostfix"));
   Logger.LogInfo("Collector Orders 0.5.2 loaded; open F10 / Orders. Depends on Cozy Tweaks 0.5.2 or newer.");
  }
  void OnDestroy(){if(harmony!=null)harmony.UnpatchSelf();Plugin.UnregisterSettingsPage(Id);}
 }
 internal static class CollectorOrders {
  static ConfigEntry<bool> enabled;
  static ConfigEntry<float> premium;
  static readonly string[] rarities={"regular","uncommon","rare","epic","legendary"};
  static readonly string[] rarityLabels={"Regular","Uncommon","Rare","Epic","Legendary"};
  static List<GameItem> catalog=new List<GameItem>();
  static readonly HashSet<string> owned=new HashSet<string>();
  static string saveKey="",search="",selectedId="",country="",message="";
  static int rarityIndex;
  static bool missingOnly=true,busy;
  static Vector2 scroll;
  static GameItem quoteItem;
  static float quote;
  static Order pending;
  const string Table="cozytweaks_collector_orders";
  internal sealed class Collected {public string id{get;set;}public string rarity{get;set;}}
  internal sealed class Order {public int id{get;set;}public string game_id{get;set;}public string seed{get;set;}public string rarity{get;set;}public string country{get;set;}public float price{get;set;}}
  internal static void Initialize(ConfigFile config) {
   enabled=config.Bind("CollectorOrders","Enabled",true,"Optional targeted orders for dirty games, paid with in-game money. No automatic completion or rarity forcing for random parcels.");
   premium=config.Bind("CollectorOrders","PriceMultiplier",3f,new ConfigDescription("Order price = current undiscounted market price times this premium. Random parcel shop is unchanged.",new AcceptableValueRange<float>(1.5f,20f)));
   L.LanguageChanged+=()=>{message="";};
  }
  static bool CanOrder {get {if(PlayerProgress.Instance==null||SelectionManager.Instance==null||GameStateManager.Instance==null)return false;var s=GameStateManager.Instance.CurrentGameState;return s==GameState.HubMenu||s==GameState.PackageSelectionStation||s==GameState.ShopPackageSelectionStation;}}
  static string UnavailableReason() {
   if(!CanOrder)return L.T("Купівля доступна лише з хабу або магазину посилок. Закрий F10, перейди туди та відкрий замовлення знову.");
   if(busy)return L.T("Зачекай: обробка замовлення.");
   if(pending!=null)return L.T("Спочатку заверши оплачене замовлення вище.");
   if(quoteItem==null)return L.T("Обери гру та регіон.");
   if(PlayerProgress.Instance.getPlayerCurrency()<quote)return L.T("Недостатньо грошей.");
   return "";
  }
  static bool LedgerExists() {return SaveSystem.SqlScalar<int>("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?",new object[]{Table})>0;}
  static void Refresh() {
   if(GameCollectionManager.Instance==null||PlayerProgress.Instance==null)return;
   saveKey=DatabaseUtility.ActiveDatabasePath;catalog=GameCollectionManager.Instance.FilterOutSpecialHiddenGames(GameCollectionManager.Instance.GetAllGames()).OrderBy(g=>g.title,StringComparer.OrdinalIgnoreCase).ToList();
   owned.Clear();foreach(var row in SaveSystem.SqlQuery<Collected>("SELECT DISTINCT id,rarity FROM collected_games",new object[0]))owned.Add(row.id+"|"+row.rarity);
   pending=LedgerExists()?SaveSystem.SqlQuery<Order>("SELECT * FROM "+Table+" WHERE id=1",new object[0]).FirstOrDefault():null;
   if(pending!=null&&SaveSystem.SqlScalar<int>("SELECT COUNT(*) FROM collected_games WHERE seed=?",new object[]{pending.seed})>0){FinishOrder(pending);pending=null;}
   quoteItem=null;quote=0;
  }
  internal static void Draw() {
   enabled.Value=GUILayout.Toggle(enabled.Value,L.T("Адресні замовлення брудних ігор"));
   if(!enabled.Value)return;GUILayout.Label(L.T("1. Рідкість → 2. Назва гри → 3. Регіон → 4. Купівля"));
   if(PlayerProgress.Instance==null||GameCollectionManager.Instance==null){GUILayout.Label(L.T("Спочатку завантаж збереження."));return;}
   if(saveKey!=DatabaseUtility.ActiveDatabasePath||catalog.Count==0)Refresh();
   if(pending!=null) {
    GUILayout.Label(L.T("Оплачене незавершене замовлення: ")+pending.game_id+" • "+pending.rarity+" • "+pending.country);
    GUILayout.Label(L.T("Його можна продовжити без повторної оплати. Колекція поповниться після чищення."));
    var previous=GUI.enabled;GUI.enabled=previous&&CanOrder&&!busy;
    if(GUILayout.Button(L.T("Продовжити оплачене замовлення")))Resume();GUI.enabled=previous;
   }
   GUILayout.BeginHorizontal();GUILayout.Label(L.T("Рідкість"),GUILayout.Width(65));int next=GUILayout.SelectionGrid(rarityIndex,rarityLabels,3);if(next!=rarityIndex){rarityIndex=next;selectedId="";quoteItem=null;}GUILayout.EndHorizontal();
   missingOnly=GUILayout.Toggle(missingOnly,L.T("Лише назви, ще не зібрані в цій рідкості"));
   GUILayout.BeginHorizontal();GUILayout.Label(L.T("Пошук"),GUILayout.Width(55));search=GUILayout.TextField(search);if(GUILayout.Button(L.T("Оновити"),GUILayout.Width(85)))Refresh();GUILayout.EndHorizontal();
   scroll=GUILayout.BeginScrollView(scroll,GUILayout.Height(160));
   foreach(var game in catalog.Where(g=>(!missingOnly||!owned.Contains(g.id+"|"+rarities[rarityIndex]))&&((g.title??"")+" "+g.platform).IndexOf(search,StringComparison.OrdinalIgnoreCase)>=0))
    if(GUILayout.Button((selectedId==game.id?"▶ ":"")+game.title+" • "+game.platform)){selectedId=game.id;country="";UpdateQuote();}
   GUILayout.EndScrollView();
   var template=catalog.FirstOrDefault(g=>g.id==selectedId);
   if(template!=null) {
    var regions=new List<string>();if(template.can_pal)regions.Add("pal");if(template.can_ntsc)regions.Add("ntsc");if(template.can_ntscj)regions.Add("ntscj");
    if(regions.Count==0){GUILayout.Label(L.T("Для цієї гри немає доступного регіону."));return;}
    if(!regions.Contains(country)){country=regions[0];UpdateQuote();}
    GUILayout.BeginHorizontal();GUILayout.Label(L.T("Регіон"),GUILayout.Width(65));foreach(var region in regions)if(GUILayout.Button((country==region?"✓ ":"")+region.ToUpperInvariant())){country=region;UpdateQuote();}GUILayout.EndHorizontal();
    if(quoteItem==null)UpdateQuote();
    GUILayout.Label(template.title+" • "+rarityLabels[rarityIndex]+" • "+country.ToUpperInvariant());
    GUILayout.Label(L.T("Замовлення: $")+quote.ToString("0.00",L.Culture)+L.T(" • баланс: $")+PlayerProgress.Instance.getPlayerCurrency().ToString("0.00",L.Culture));
    string reason=UnavailableReason();if(reason.Length>0)GUILayout.Label(reason,GUI.skin.box);var before=GUI.enabled;GUI.enabled=before&&reason.Length==0;
    if(GUILayout.Button(L.T("Купити брудну копію й перейти до чищення")))Buy();GUI.enabled=before;
   }
   GUILayout.Label(L.T("Замовляй із хабу або крамниці посилок. За раз — одна гра."));
   GUILayout.Label(L.T("Ціна: ×")+premium.Value.ToString("0.0",L.Culture)+L.T(" від поточної ринкової ціни без магазинної знижки. Доставка одразу на стіл для чищення."));
   if(message.Length>0)GUILayout.Label(message);
  }
  static GameItem CreateItem(GameItem template,string seed,string rarity,string region) {
   var item=new GameItem();
   foreach(var property in typeof(GameItem).GetProperties(BindingFlags.Public|BindingFlags.Instance).Where(p=>p.CanRead&&p.CanWrite&&p.GetIndexParameters().Length==0&&p.Name!="seed"))property.SetValue(item,property.GetValue(template,null),null);
   item.SetNewSeed(seed);item.seed=seed;item.cleaningStats.seed=seed;item.setRarityOverride(rarity);item.country=region;return item;
  }
  static void UpdateQuote() {
   quoteItem=null;var template=catalog.FirstOrDefault(g=>g.id==selectedId);if(template==null)return;
   quoteItem=CreateItem(template,Guid.NewGuid().ToString(),rarities[rarityIndex],country.Length==0?"pal":country);
   quote=Mathf.Max(1f,PlayerProgressStats.RoundCurrency(quoteItem.getPrice()*premium.Value));
  }
  static void EnsureLedger() {
   SaveSystem.SqlExecute("CREATE TABLE IF NOT EXISTS "+Table+" (id INTEGER PRIMARY KEY CHECK(id=1), game_id TEXT NOT NULL, seed TEXT NOT NULL UNIQUE, rarity TEXT NOT NULL, country TEXT NOT NULL, price REAL NOT NULL)",new object[0]);
  }
  static void Buy() {
   if(!CanOrder||pending!=null||busy||quoteItem==null)return;busy=true;
   float previousBalance=PlayerProgress.Instance.PlayerStats.currency;bool charged=false;
   try {
    // Recalculate once on confirmation, so a stale quote cannot overspend money.
    float fresh=Mathf.Max(1f,PlayerProgressStats.RoundCurrency(quoteItem.getPrice()*premium.Value));
    if(Mathf.Abs(fresh-quote)>0.005f){quote=fresh;message=L.T("Ціна змінилася. Перевір її та натисни купівлю ще раз.");return;}
    EnsureLedger();
    var order=new Order{id=1,game_id=quoteItem.id,seed=quoteItem.seed,rarity=quoteItem.rarity,country=quoteItem.country,price=quote};
    DatabaseUtility.GetConnection().RunInTransaction(()=>{
     if(SaveSystem.SqlScalar<int>("SELECT COUNT(*) FROM "+Table+" WHERE id=1",new object[0])!=0)throw new InvalidOperationException(L.T("Є незавершене замовлення."));
     if(!PlayerProgress.Instance.SpendPlayerCurrency(quote))throw new InvalidOperationException(L.T("Недостатньо грошей."));
     SaveSystem.SqlExecute("INSERT INTO "+Table+" (id,game_id,seed,rarity,country,price) VALUES (1,?,?,?,?,?)",new object[]{order.game_id,order.seed,order.rarity,order.country,order.price});
    });
    charged=true;pending=order;Deliver(quoteItem);
   } catch(Exception e) {
    if(!charged){PlayerProgress.Instance.PlayerStats.currency=previousBalance;AccessTools.Method(typeof(PlayerProgress),"UpdatePlayerCurrencyDisplay").Invoke(PlayerProgress.Instance,null);}
    message=charged?L.T("Замовлення збережене. Його можна продовжити без повторної оплати."):L.T("Купівлю не виконано: ")+e.Message;
    Plugin.LogMessage("Collector order: "+e);
   } finally {busy=false;}
  }
  static void Resume() {
   if(!CanOrder||pending==null||busy)return;busy=true;
   try {var template=GameCollectionManager.Instance.GetGameById(pending.game_id);if(template==null)throw new InvalidOperationException(L.T("Гру не знайдено в каталозі."));Deliver(CreateItem(template,pending.seed,pending.rarity,pending.country));}
   catch(Exception e){message=L.T("Не вдалося відновити замовлення: ")+e.Message;Plugin.LogMessage("Resume collector order: "+e);}finally{busy=false;}
  }
  static void Deliver(GameItem item) {
   SelectionManager.Instance.SetActiveGameItem(item);
   Plugin.CloseForOrder();GameStateManager.Instance.ClearMenus();GameStateManager.Instance.SetGameState(GameState.GamePrepaintingPreparation);
  }
  internal static void CollectedPostfix(GameItem __0) {
   if(__0==null||pending==null||pending.seed!=__0.seed||saveKey!=DatabaseUtility.ActiveDatabasePath)return;
   FinishOrder(pending);pending=null;owned.Add(__0.id+"|"+__0.rarity);quoteItem=null;
  }
  static void FinishOrder(Order order) {
   DatabaseUtility.GetConnection().RunInTransaction(()=>{
    SaveSystem.SqlExecute("UPDATE collected_games SET purchase_price=? WHERE seed=?",new object[]{order.price,order.seed});
    SaveSystem.SqlExecute("DELETE FROM "+Table+" WHERE id=1 AND seed=?",new object[]{order.seed});
   });
  }
 }
}









