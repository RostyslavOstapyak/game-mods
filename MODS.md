# Mod catalog

- [ObjectiveHighlight 0.5.1](CrimeBoss/ObjectiveHighlight/ObjectiveHighlight-0.5.1-Nexus.zip) · [Nexus](https://www.nexusmods.com/crimebossrockaycity/mods/73)
- [BagCapacity10x 0.1.0-test](CrimeBoss/BagCapacity10x/BagCapacity10x-0.1.0-test-Nexus.zip) · [Nexus](https://www.nexusmods.com/crimebossrockaycity/mods/74)
- [Landsraad Donation beta.5](DuneAwakening/LandsraadDonation/LandsraadDonation-0.2.0-beta.5-Nexus.zip) · [Nexus](https://www.nexusmods.com/duneawakening/mods/90)
- [Endgame Overhaul](DuneAwakening/EndgameOverhaul) · development snapshots

## BagCapacity10x build

[BagCapacity10x.c](CrimeBoss/BagCapacity10x/BagCapacity10x.c) is the C source included in the Nexus submission. From its directory, build using Tiny C Compiler 0.9.27 for Windows x64.

```powershell
tcc -shared -Wall -Werror -o BagCapacity10x.dll BagCapacity10x.c
```

Place the DLL at `BagCapacity10x/Scripts/native/BagCapacity10x.dll` in the package. The build targets Crime Boss Steam build 25106786.

## Landsraad Donation manual review

[Browse the unpacked beta.5 package](DuneAwakening/LandsraadDonation/beta.5/LandsraadDonations).
The inventory reader installer is available as [PowerShell source](DuneAwakening/LandsraadDonation/beta.5/LandsraadDonations/Tools/Install-InventoryReader.ps1) and a [CMD launcher](DuneAwakening/LandsraadDonation/beta.5/LandsraadDonations/Tools/Install-InventoryReader.cmd).
