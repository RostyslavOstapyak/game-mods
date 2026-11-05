param(
    [string]$ModsDirectory = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$modsRoot = (Resolve-Path -LiteralPath $ModsDirectory).Path
$ourRoot = Join-Path $modsRoot 'LandsraadDonations'
$coreRoot = Join-Path $modsRoot 'NBSCore'
$mainPath = Join-Path $coreRoot 'Scripts\main.lua'
$hostPath = Join-Path $ourRoot 'Scripts\nbs_reader_host.lua'
if (-not (Test-Path -LiteralPath $hostPath)) { throw 'LandsraadDonations reader host is missing. Install the mod files first.' }
$coreVersion = (Get-Content -LiteralPath (Join-Path $coreRoot 'mod.json') -Raw | ConvertFrom-Json).version
$profiles = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'supported-core.json') -Raw | ConvertFrom-Json).profiles
$supported = @($profiles | Where-Object { $_.version -eq $coreVersion })
if ($supported.Count -ne 1) { throw "Unsupported NBS Core version: $coreVersion. No files changed." }
$supported = $supported[0]
function Get-TextHash([string]$Value) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))).Replace('-','').ToLowerInvariant() }
    finally { $algorithm.Dispose() }
}
$source = [IO.File]::ReadAllText($mainPath).Replace("`r`n","`n")
$sourceHash = Get-TextHash $source
if ($supported.patchedHashes -contains $sourceHash) { Write-Output 'Inventory reader hook already installed and verified. No files changed.'; return }
if ($supported.cleanHashes -notcontains $sourceHash) { throw 'NBS Core main.lua differs from the supported original. No files changed; keep your existing customizations.' }
$anchor = [regex]'(?m)^U\.start\(boot\)'
if ($anchor.Matches($source).Count -ne 1) { throw 'NBS Core startup anchor is ambiguous. No files changed.' }
$bridge = @'
-- LD_READ_ONLY_HOST_V1: local interoperability hook; no NBS implementation copied.
do
 local ok,why=pcall(function()
  local root=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/Scripts/[^/]+$')
  local host=dofile(assert(root)..'/../LandsraadDonations/Scripts/nbs_reader_host.lua')
  host(U.later,U.player,ModRef)
 end)
 if not ok then print('[LD_READER_HOST] unavailable: '..tostring(why)..'\n')end
end

'@
$inserted = $bridge + "`n" + 'U.start(boot)'
# Use a literal evaluator: Lua's end anchor followed by a quote contains $', a .NET replacement token.
$updated = $anchor.Replace($source, [Text.RegularExpressions.MatchEvaluator]{ param($match) return $inserted }, 1)
if ($CheckOnly) { Write-Output 'Supported NBS Core original verified; reader hook can be installed. No files changed.'; return }
if (Get-Process | Where-Object { $_.ProcessName -match '^DuneSandbox' }) { throw 'Close Dune Awakening before installing the inventory reader.' }
$backup = $mainPath + '.landsraad-backup-' + [guid]::NewGuid().ToString('N')
Copy-Item -LiteralPath $mainPath -Destination $backup
[IO.File]::WriteAllText($mainPath,$updated,[Text.UTF8Encoding]::new($false))
if ((Get-TextHash ([IO.File]::ReadAllText($mainPath).Replace("`r`n","`n"))) -ne (Get-TextHash $updated)) { throw "Reader hook verification failed. Backup: $backup" }
@{version=1;coreVersion=$coreVersion;originalHash=$sourceHash;patchedHash=(Get-TextHash $updated);backup=$backup} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ourRoot 'reader-install-state.json') -Encoding utf8
Write-Output "Inventory reader installed. Original main.lua backup: $backup"
Write-Output 'Restart the game. No inventory, Solari, saves or transaction logs were changed.'
