# Landsraad Donation - Turn Wealth Into Influence

Your fortune should buy more than another storage chest.

Build a Landsraad Terminal at your base and turn bank Solari, backpack Melange and eligible equipment into personal contribution, house progress and specialization XP. Pick a house, review what you will spend, and support its cause through a three-page interface inspired by Dune's imperial style.

## Public beta - compatibility matters

Requires NBS Core **1.6.12 or newer**. Install NBS Core through its normal installation process.

Historically tested: Steam build **26083551 (1.5.15)**, WPS Launcher **2.1.1**, WPS Framework **1.7.1**, NBS Core **1.6.7**, UE4SS **3.0.1-1140-gf58e8f84**. Multiplayer, Xbox PC and newer game builds are not validated.

## What you get

- A buildable Landsraad Terminal: interact with **E**, close with **Esc**. F6 is not used.
- Choose a house and use **Claim all** to collect its available contribution rewards at the terminal. Verified with Alexin on November 14, 2026.
- A 5 x 5 house board, personal contribution, faction progress and contribution rewards display.
- Solari donations from your bank and Melange donations from your backpack.
- Category-based T5/T6 equipment donations. Items assigned to quick-access slots may appear in the list. Check your selection before confirming.
- Combine different eligible items when you have exactly one unit of each template in your backpack and no matching unit equipped or in an ability slot.
- House-specific cycle requests with a **x2 reward**, not a requirement to donate two items.
- Requests can include an appropriate T6 item or duraluminum/plastanium ingots. Both ingots can be requested by any house; outside a request they are normally accepted by production houses.
- Matching specialization XP, with an optional switch and configurable rate.
- English and Ukrainian UI following the game's text language. Other languages fall back to English; translation packs are supported.

Captured/unavailable houses remain subject to the mod's house eligibility rules. Melange is accepted by every eligible house at its configured fixed rate, without the item-request bonus. This is not an unrestricted dump-all-resources system.

## Requirements - install separately

1. [WPS Dune Launcher](https://www.nexusmods.com/duneawakening/mods/18): declared minimum **2.1.0**, tested **2.1.1**. Use its matching **UE4SS 3.0.1-1140-gf58e8f84** runtime. Do not replace it with an arbitrary UE4SS build. The runtime is not bundled here.
2. [WPS Dune Framework](https://www.nexusmods.com/duneawakening/mods/21): declared minimum **1.7.0**, tested **1.7.1**. Newer releases are not certified by this beta.
3. [NBS Core](https://www.nexusmods.com/duneawakening/mods/37): **1.6.12 or newer**, without an upper version cap.

Windows PC, Steam, Singleplayer. **WPS Economy and The Stash Must Flow are not required.** No third-party mod, Core script, game asset or DLL is included.

## Installation

1. Save, quit the game completely and back up your save.
2. Install the dependencies using their own instructions. Check the minimum versions above first.
3. Import this ZIP in WPS Launcher, or copy the archive's **LandsraadDonations** folder into your launcher's **Mods** folder. Enable the dependencies and mod, then sort dependencies.
4. Launch Singleplayer through WPS. Find **Landsraad Terminal** in the NBS building set and build it. Press **E** nearby to open the menu.

Choose a house, payment method and contribution amount, or open **Donate items**. Review the actual cost and confirm once. Processing can take 15-20 seconds. Wait for the result instead of submitting again.

## Default economy and settings

- **1 contribution point costs 1,000 Solari.**
- **1 Melange is valued at 60,000 Solari**, giving 60 contribution at the default point price.
- **1 contribution = 1 specialization XP** by default.
- Up to **6,000 contribution per transaction**.
- Equipment value = **game base value x item_value_multiplier**, converted at the configured point price; the specific house request doubles the reward.

Melange is spent in whole units: requesting 1,000 points costs 17 Melange and yields 1,020 actual points at the defaults. The review shows the actual result. Base prices are a starting balance rule, not a claim about market rarity or endgame value.

Use the launcher's settings gear or edit **config.ini**: solari_per_point, solari_per_melange, item_value_multiplier, specialization_xp_enabled and specialization_xp_per_point. Restart after changes.

## Updating, disabling and removal

If a previous version installed a reader hook, reinstall stock NBS Core using its own instructions with the game closed before replacing the old mod files. This removes the old Core hook.

Preserve **config.ini**, **item-requests.tsv**, **transactions.log**, and **transaction-state.log** when updating. Never delete a journal to bypass an unresolved donation. Multiple gameplay actions are not atomic; a crash can leave a partially completed donation requiring review.

To disable temporarily, quit fully, disable Landsraad Donation in WPS and restart. Keep NBS Core enabled while any NBS structures remain in the world.

For permanent removal, dismantle every Landsraad Terminal while the mod is enabled, save and quit, then disable the mod. Keep dependencies needed by other mods.

## Tested honestly

Live development tests covered Solari/Melange payments, contribution and XP; one compactor (48 points/XP), two compactors (96), mixed types (109), selecting a single duplicate, and donating 3 ingots from 205 with 202 remaining. These numbers are test examples, not universal item prices. The user reviewed all three UI pages and English/Ukrainian language switching in game.

Beta 8 was tested on NBS Core 1.6.15. One item donation delivered 61 personal contribution and 61 specialization XP. For Spinette, Claim all delivered the inventory rewards and the available balances reached zero. The terminal could not verify the swatch through inventory and displayed a verification message. Rare crashes and incomplete enemy faction progress display remain known issues.

## Translations and credits

See **Locales/README.md**. Copy en.tsv to your language code, translate values, preserve keys/placeholders and restart. The mod follows the game's language; no separate language dropdown.

Thanks to Wasted Potential Studios for WPS Launcher and Framework, Null Boundary Studios/OddessaX for NBS Core, and the UE4SS project. Their work remains separate and must be downloaded from its authors. Dune: Awakening and its game content belong to their respective owners; this is an unofficial mod.

The gallery illustration and header are **AI-generated promotional artwork, not gameplay screenshots**. Development and translation were AI-assisted. Mark AI Content/Media accordingly on Nexus.
