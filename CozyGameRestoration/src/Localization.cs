using System;
using System.Collections.Generic;
using System.Globalization;
using BepInEx.Configuration;
namespace CozyTweaks {
 public enum UiLanguage { Ukrainian, English }
 public static class L {
  static ConfigEntry<UiLanguage> language;
  public static event Action LanguageChanged;
  public static UiLanguage Language {get{return language==null?UiLanguage.Ukrainian:language.Value;}set{if(language==null||language.Value==value)return;language.Value=value;var handler=LanguageChanged;if(handler!=null)handler();}}
  public static CultureInfo Culture {get{return CultureInfo.GetCultureInfo(Language==UiLanguage.English?"en-US":"uk-UA");}}
  internal static void Initialize(ConfigFile config) {language=config.Bind("Interface","Language",UiLanguage.Ukrainian,"UI language: Ukrainian (default) or English. Change it in F10 using the always-visible language buttons.");}
  public static string T(string uk) {string value;return Language==UiLanguage.English&&English.TryGetValue(uk,out value)?value:uk;}
  static readonly Dictionary<string,string> English=new Dictionary<string,string> {
   {"Перемістити індикатор","Move indicator"},{"Завершити переміщення","Finish positioning"},{"Перетягни індикатор мишею. Позиція зберігається після відпускання.","Drag the indicator. Position is saved when you release the mouse."},{"Повернути стандартну позицію","Reset position"},{"Перетягни мене","Drag me"},{"Стан інструмента","Tool status"},{"Рідина","Liquid"},{"Поліроль","Polish"},{"Ватна паличка","Cotton swab"},{"Щітка","Brush"},{"Забруднення","Dirtiness"},{"Залишок","Remaining"},
   {"Показувати стан активного інструмента","Show active tool status"},{"Кольорова смуга під відсотками","Colored bar below percentage"},
   {"Рідина й поліроль: 100% — повний запас, 0% — порожньо.","Liquid and polish: 100% = full, 0% = empty."},
   {"Паличка й щітка: 0% — чисті, 100% — потрібно очистити.","Swab and brush: 0% = clean, 100% = needs cleaning."},
   {"Індикатор справа з’являється лише під час чищення для інструментів із запасом або забрудненням.","The indicator appears on the right only while cleaning with tools that have a supply or dirtiness value."},
   {" (1 — звичайна, 20 — найшвидша)"," (1 = normal, 20 = fastest)"},
   {" • баланс: $"," • balance: $"},{" • На полиці: "," • On shelf: "},
   {" від поточної ринкової ціни без магазинної знижки. Доставка одразу на стіл для чищення."," current market price, without shop discounts. Delivered directly to the cleaning desk."},
   {" с"," s"},{". Обери іншу.",". Choose another."},{"[На полиці] ","[On shelf] "},
   {"Адресні замовлення брудних ігор","Targeted orders for dirty games"},{"Анімації","Animations"},
   {"Більше = швидше. Зміни діють на наступну анімацію.","Higher = faster. Changes apply to the next animation."},
   {"Бонус жанру: ","Genre bonus: "},
   {"Бонус залежить від сусідства однакових жанрів і рідкості; тут показано тип.","Bonus strength depends on adjacent genres and rarity; this shows the bonus type."},
   {"Відновити клавіші 1–8","Restore keys 1–8"},{"Власні клавіші інструментів","Custom tool shortcuts"},
   {"Гра недоступна для цього місця. Обери місце ще раз.","This game is unavailable for this slot. Select the slot again."},
   {"Гру не знайдено в каталозі.","Game not found in the catalogue."},{"Для цієї гри немає доступного регіону.","No region is available for this game."},
   {"Експериментально: скоротити блокування інструментів","Experimental: shorten the tool input lock"},
   {"Є незавершене замовлення.","There is an unfinished order."},{"Жанр: ","Genre: "},{"Жанр","Genre"},
   {"Закрити (F10)","Close (F10)"},{"Замовлення збережене. Його можна продовжити без повторної оплати.","Order saved. You can resume it without paying again."},
   {"Замовлення: $","Order: $"},{"Замовлення","Orders"},
   {"Замовляй із хабу або крамниці посилок. За раз — одна гра.","Place orders from the hub or parcel shop. One unfinished order at a time."},
   {"Збережено: ","Saved: "},{"Зняти гру з вибраного місця","Remove the game from this shelf slot"},
   {"ІНВЕНТАР • ","INVENTORY • "},{"ІНВЕНТАР • ВИБІР ДЛЯ ПОЛИЦІ • ","INVENTORY • SHELF SELECTION • "},
   {"Інвентар","Inventory"},{"Інструмент ","Tool "},
   {"Інструмент 1: відразу режим обертання картриджа (2-й)","Tool 1: start in cartridge rotation mode (mode 2)"},
   {"Інструменти","Tools"},
   {"Його можна продовжити без повторної оплати. Колекція поповниться після чищення.","Resume without paying again. The game joins your collection after cleaning."},
   {"Купити брудну копію й перейти до чищення","Buy a dirty copy and start cleaning"},{"Купівлю не виконано: ","Purchase failed: "},
   {"Лише назви, ще не зібрані в цій рідкості","Only titles not yet collected at this rarity"},{"Місткість","Capacity"},
   {"на полиці","on shelf"},{"Назва","Name"},
   {"Назви беруться з панелі інструментів після входу на робочий стіл.","Tool names come from the toolbar after entering the cleaning desk."},
   {"Натисни кнопку навпроти інструмента, потім клавішу або кнопку миші.","Click a tool binding, then press a keyboard key or mouse button."},
   {"Натисни нову клавішу…","Press a new shortcut…"},{"Не вдалося відновити замовлення: ","Could not resume order: "},
   {"Недостатньо грошей.","Not enough money."},{"Обери гру в таблиці.","Select a game in the table."},{"Оновити","Refresh"},
   {"Оплачене незавершене замовлення: ","Paid unfinished order: "},{"Очікування інструментів: ","Tool input lock: "},
   {"Підтримуються Ctrl / Shift / Alt. Esc — скасувати; Delete — прибрати прив’язку.","Ctrl / Shift / Alt supported. Esc cancels; Delete clears the binding."},
   {"Площа чищення","Surface area"},{"поза полицею","off shelf"},{"Показувати тип бонусу жанру","Show genre bonus types"},
   {"Полиця: ","Shelf: "},{"Порядок","Sort"},{"Поставити на вибране місце","Place in the selected shelf slot"},{"Пошук","Search"},
   {"Прискорити відкриття кришок коробки","Speed up box flaps"},{"Прискорити екран після завершення чищення","Speed up the cleaning completion screen"},
   {"Прискорити затемнення між коробкою та столом","Speed up fades between parcel and desk scenes"},
   {"Прискорити появу предметів і паузи між ними","Speed up item arrivals and pauses between them"},
   {"Продаж гри з полиці доступний після її зняття.","Remove a shelved game before selling it."},
   {"Продано. Позицію прокручування збережено.","Sold. Scroll position preserved."},{"Продати за $","Sell for $"},
   {"Продовжити оплачене замовлення","Resume paid order"},{"Регіон","Region"},{"Рідкість: ","Rarity: "},{"Рідкість","Rarity"},
   {"Розміщено на вибраному місці.","Placed in the selected slot."},{"Сила чищення","Cleaning power"},{"Скинути","Reset"},
   {"Сортування, пошук і фільтри розташовані над таблицею.","Sorting, search and filters are above the table."},
   {"Спершу зніми з полиці","Remove from shelf first"},{"Спершу зніми цю гру з полиці.","Remove this game from the shelf first."},
   {"Спочатку завантаж збереження.","Load a save first."},{"Таблиця інвентарю зі звичайним прокручуванням","Scrollable inventory table"},
   {"Така сама таблиця й продаж під час вибору гри для полиці","Use this table and selling actions for shelf selection"},
   {"Увімкнути покращення (лівий Ctrl+F8)","Enable tweaks (Left Ctrl+F8)"},{"усі","all"},
   {"Цієї копії вже немає в інвентарі.","This copy is no longer in your inventory."},
   {"Ціна — фактична поточна ціна продажу за формулою гри.","Prices use the game's current sale-price calculation."},
   {"Ціна змінилася. Перевір її та натисни купівлю ще раз.","The price changed. Review it and confirm the purchase again."},
   {"Ціна: ×","Price: ×"},{"Ціна","Price"},{"Ця комбінація вже зайнята інструментом ","This shortcut is already assigned to tool "},
   {"Швидкість відкриття: ×","Opening speed: ×"},{"Швидкість завершення: ×","Completion speed: ×"},{"Швидкість появи: ×","Arrival speed: ×"},
   {"Cozy Tweaks 0.5.2  •  гра на паузі","Cozy Tweaks 0.5.2  •  game paused"},
   {"Ширина таблиці","Table width"},{"Згорнути","Collapse"},{"Розгорнути","Expand"},{"Ширина меню","Menu width"},{"Висота меню","Menu height"},
   {"Купівля доступна лише з хабу або магазину посилок. Закрий F10, перейди туди та відкрий замовлення знову.","Ordering is only available from the hub or parcel shop. Close F10, go there and reopen Orders."},
   {"Зачекай: обробка замовлення.","Please wait: processing order."},{"Спочатку заверши оплачене замовлення вище.","Finish the paid order above first."},{"Обери гру та регіон.","Select a game and region."},
   {"1. Рідкість → 2. Назва гри → 3. Регіон → 4. Купівля","1. Rarity → 2. Game title → 3. Region → 4. Purchase"},
   {"F10 та F8 залишені для керування модом. Обери іншу клавішу.","F10 and F8 are reserved for the mod. Choose another key."}
  };
 }
}











