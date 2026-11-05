# Game mods

| Mod | Package | Status |
| --- | --- | --- |
| ObjectiveHighlight | [0.5.1 ZIP](ObjectiveHighlight-0.5.1-Nexus.zip) | [Crime Boss Nexus page](https://www.nexusmods.com/crimebossrockaycity/mods/73) |
| BagCapacity10x | [0.1.0-test ZIP](BagCapacity10x-0.1.0-test-Nexus.zip) | [Crime Boss Nexus page](https://www.nexusmods.com/crimebossrockaycity/mods/74) |
| Landsraad Donation | [0.2.0-beta.5 ZIP](LandsraadDonation-0.2.0-beta.5-Nexus.zip) | [Dune Nexus page](https://www.nexusmods.com/duneawakening/mods/90) |
| Endgame Overhaul | [Development source ZIP](EndgameOverhaul-development-source.zip) | Work in progress |

## BagCapacity10x DLL build

The [C source](BagCapacity10x.c) is the copy included in the Nexus submission. In the directory containing it, build with Tiny C Compiler 0.9.27 for Windows x64:

```powershell
tcc -shared -Wall -Werror -o BagCapacity10x.dll BagCapacity10x.c
```

Place the output at `BagCapacity10x/Scripts/native/BagCapacity10x.dll` in the package. The build targets Crime Boss Steam build 25106786.
