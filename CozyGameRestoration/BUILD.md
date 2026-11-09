# Build from source

Install a .NET SDK with Roslyn and provide local paths to your own game and BepInEx 5 x64 / Mono installation. The loader directory can be either the BepInEx folder itself or the directory containing it.

```powershell
./build/Build.ps1 -GameDirectory 'D:/Games/Cozy Game Restoration' -BepInExDirectory 'D:/Games/Cozy Game Restoration/BepInEx'
```

The script compiles CozyTweaks.dll and CollectorOrders.dll into bin/. It does not install, launch the game or run tests. The game/loader assemblies are build references only and must not be uploaded. CollectorOrders requires the core DLL from the same build. Existing packages were built against Unity 2022.3.62f3, BepInEx 5.4.23.6 and .NET SDK 9.0.308.
