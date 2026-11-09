param(
 [Parameter(Mandatory=$true)][string]$GameDirectory,
 [Parameter(Mandatory=$true)][string]$BepInExDirectory,
 [string]$OutputDirectory = (Join-Path $PSScriptRoot '../bin'),
 [string]$CompilerPath
)
$ErrorActionPreference='Stop'
$managed=Join-Path $GameDirectory 'CozyGameRestoration_Data/Managed'
$loader=Join-Path $BepInExDirectory 'core'
if(!(Test-Path (Join-Path $loader 'BepInEx.dll'))){$loader=Join-Path $BepInExDirectory 'BepInEx/core'}
if(!$CompilerPath){
 $sdkLine=@(& dotnet --list-sdks)[-1]
 if($sdkLine -notmatch '^([^ ]+) \[(.+)\]$'){throw 'Install a .NET SDK or supply -CompilerPath pointing to Roslyn csc.dll.'}
 $CompilerPath=Join-Path (Join-Path $Matches[2] $Matches[1]) 'Roslyn/bincore/csc.dll'
}
$refs=@('mscorlib.dll','System.dll','System.Core.dll','netstandard.dll','UnityEngine.dll','UnityEngine.CoreModule.dll','UnityEngine.IMGUIModule.dll','UnityEngine.InputLegacyModule.dll','Assembly-CSharp.dll','Rewired_Core.dll','UnityEngine.UI.dll','Unity.TextMeshPro.dll','UnityEngine.UIModule.dll','UnityEngine.TextRenderingModule.dll','Gilzoide.SqliteNet.dll') | ForEach-Object {Join-Path $managed $_}
$refs+=@(Join-Path $loader 'BepInEx.dll';Join-Path $loader '0Harmony.dll')
foreach($ref in $refs){if(!(Test-Path -LiteralPath $ref)){throw "Missing dependency: $ref"}}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$OutputDirectory=(Resolve-Path -LiteralPath $OutputDirectory).Path
$src=Join-Path $PSScriptRoot '../src'
$common=@('/nologo','/target:library','/nostdlib+','/optimize+')+@($refs | ForEach-Object {'/reference:"'+(Resolve-Path -LiteralPath $_).Path+'"'})
$core=Join-Path $OutputDirectory 'CozyTweaks.dll'
$coreSources=@('Plugin.cs','ToolBindings.cs','InventoryTable.cs','ModalInput.cs','DarkTheme.cs','CompletionAnimations.cs','Localization.cs','ToolStatusHud.cs') | ForEach-Object {'"'+(Join-Path $src $_)+'"'}
$coreRsp=Join-Path $OutputDirectory 'core.rsp'
@($common;'/out:"'+$core+'"';$coreSources) | Set-Content -LiteralPath $coreRsp -Encoding utf8
& dotnet $CompilerPath ('@'+$coreRsp)
if($LASTEXITCODE -ne 0){throw 'Cozy Tweaks compilation failed.'}
$ordersRsp=Join-Path $OutputDirectory 'orders.rsp'
@($common;'/out:"'+(Join-Path $OutputDirectory 'CollectorOrders.dll')+'"';'/reference:"'+$core+'"';'"'+(Join-Path $src 'CollectorOrders.cs')+'"') | Set-Content -LiteralPath $ordersRsp -Encoding utf8
& dotnet $CompilerPath ('@'+$ordersRsp)
if($LASTEXITCODE -ne 0){throw 'Collector Orders compilation failed.'}
Write-Output "Compiled both plugins into $OutputDirectory. No game launch or tests were performed."
