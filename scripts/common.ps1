<#
.SYNOPSIS
    Shared helpers for the ICPC lab scripts. Dot-source it:  . "$PSScriptRoot\common.ps1"
.DESCRIPTION
    Everything a contestant needs must live in a location that EVERY account can read
    (C:\Program Files, C:\mingw64, ...). Anything under C:\Users\<someone> is private to that
    person, so a compiler installed there works for the Administrator but NOT for the contestant.
    The helpers below enforce that rule.
#>

$script:RepoRoot       = Split-Path -Parent $PSScriptRoot
$script:IcpcDataDir    = Join-Path $env:ProgramData 'ICPC'
$script:IcpcBackupDir  = Join-Path $script:IcpcDataDir 'backup'
$script:IcpcExtCache   = Join-Path $script:IcpcDataDir 'vscode-extensions'
$script:UsbExtSeed     = Join-Path $script:RepoRoot 'installers\vscode-extensions'
$script:UsersRoot      = Split-Path -Parent $env:PUBLIC          # normally C:\Users
$script:DefaultPassword = 'ICPC2026!UoP'

# -------------------------------------------------------------------------------------------
# Accounts
# -------------------------------------------------------------------------------------------
function Resolve-ContestAccount {
    param(
        [int]$PcNumber = 0,
        [string]$Username = 'contestant',
        [string]$Password = $script:DefaultPassword
    )
    $acct = [pscustomobject]@{
        Username    = $Username
        Password    = $Password
        FullName    = 'ICPC Contestant'
        TeamDisplay = 'ICPC Contestant'
        Seat        = $null
    }
    if ($PcNumber -eq 0) { return $acct }

    if ($PcNumber -lt 1 -or $PcNumber -gt 60) {
        Write-Host "[WARNING] PC number $PcNumber is outside 1-60. Using generic '$Username' account." -ForegroundColor Yellow
        return $acct
    }
    $csvPath = Join-Path $script:RepoRoot 'contestant_credentials.csv'
    if (-not (Test-Path -LiteralPath $csvPath)) {
        Write-Host "[WARNING] contestant_credentials.csv not found next to RUN_SETUP.bat. Using generic '$Username' account." -ForegroundColor Yellow
        return $acct
    }
    $seat = 'PC-{0:D2}' -f $PcNumber
    $row = Import-Csv -LiteralPath $csvPath | Where-Object { $_.seat -eq $seat } | Select-Object -First 1
    if ($null -eq $row) {
        Write-Host "[WARNING] Seat $seat not found in contestant_credentials.csv. Using generic '$Username' account." -ForegroundColor Yellow
        return $acct
    }
    $acct.Username    = $row.username
    $acct.Password    = $Password
    $acct.FullName    = $row.username
    $acct.TeamDisplay = "$($row.team_name) - $($row.institution)"
    $acct.Seat        = $seat
    return $acct
}

function Get-UserProfilePath([string]$Username) {
    $user = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
    if ($null -eq $user) { return $null }
    $sid = $user.SID.Value
    $p = Get-CimInstance -ClassName Win32_UserProfile -Filter "SID='$sid'" -ErrorAction SilentlyContinue
    if ($p -and $p.LocalPath -and (Test-Path -LiteralPath $p.LocalPath)) { return $p.LocalPath }
    return $null
}

function Initialize-UserProfile([string]$Username) {
    <#
        Windows normally creates C:\Users\<name> only at the FIRST interactive logon. Until then
        there is no Desktop / AppData / .vscode folder to put anything in, which is why the old
        script silently skipped the workspace, settings and extensions for every new account.
        CreateProfile() builds the real, registered profile right now (copied from C:\Users\Default).
    #>
    $user = Get-LocalUser -Name $Username -ErrorAction Stop
    $sid  = $user.SID.Value

    $existing = Get-UserProfilePath $Username
    if ($existing) { return $existing }

    $target = Join-Path $script:UsersRoot $Username

    # Leftovers from an earlier contest (user deleted but profile registration / folder left behind)
    # would make Windows create "C:\Users\<name>.<PC>" instead. Clean them up first.
    $orphans = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalPath -ieq $target -and $_.SID -ne $sid }
    foreach ($o in $orphans) {
        if ($o.Loaded) {
            Write-Host "[WARNING] Stale profile $($o.LocalPath) is in use; reboot and run setup again." -ForegroundColor Yellow
            continue
        }
        Write-Host "[INFO] Removing stale profile registration for $($o.LocalPath) (old SID $($o.SID))..." -ForegroundColor Yellow
        Remove-CimInstance -InputObject $o -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $target) {
        $stale = "$target.stale-$(Get-Date -Format 'yyyyMMddHHmmss')"
        Write-Host "[INFO] Renaming leftover folder $target -> $stale" -ForegroundColor Yellow
        Rename-Item -LiteralPath $target -NewName (Split-Path -Leaf $stale) -ErrorAction SilentlyContinue
    }

    if (-not ('ICPC.UserEnv' -as [type])) {
        Add-Type -Namespace ICPC -Name UserEnv -MemberDefinition @'
[DllImport("userenv.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern int CreateProfile(string pszUserSid, string pszUserName, System.Text.StringBuilder pszProfilePath, uint cchProfilePath);
'@
    }
    $sb = New-Object System.Text.StringBuilder 260
    $hr = [ICPC.UserEnv]::CreateProfile($sid, $Username, $sb, [uint32]260)
    if ($hr -ne 0 -and $hr -ne -2147024713) {   # 0x800700B7 = already exists
        throw ("CreateProfile failed for '{0}' (HRESULT 0x{1:X8})" -f $Username, $hr)
    }
    $path = Get-UserProfilePath $Username
    if (-not $path) { throw "Profile for '$Username' was not created." }
    return $path
}

# -------------------------------------------------------------------------------------------
# PATH handling (machine-wide only - that is what the contestant sees)
# -------------------------------------------------------------------------------------------
$script:EnvKeyPath = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment'

function Get-MachinePathRaw {
    # Read WITHOUT expanding %SystemRoot% etc. so writing it back does not flatten the value.
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($script:EnvKeyPath, $false)
    try { return [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) }
    finally { $key.Close() }
}

function Set-MachinePathRaw([string[]]$Parts) {
    $value = (@($Parts | Where-Object { $_ }) -join ';')
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($script:EnvKeyPath, $true)
    try { $key.SetValue('Path', $value, [Microsoft.Win32.RegistryValueKind]::ExpandString) }
    finally { $key.Close() }
    Update-SessionPath
}

function Get-MachinePathDirs {
    @(Get-MachinePathRaw) -split ';' | Where-Object { $_ } |
        ForEach-Object { [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') }
}

function Update-SessionPath {
    $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $u = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$m;$u"
}

function Test-IsSharedPath([string]$Path) {
    # True if every account on the PC can use this location (i.e. not inside someone's profile).
    if (-not $Path) { return $false }
    try { $full = [IO.Path]::GetFullPath($Path) } catch { return $false }
    if ($full -match '\\WindowsApps\\') { return $false }   # Microsoft Store stubs / per-user aliases
    if ($full.StartsWith($script:UsersRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        return $full.StartsWith($env:PUBLIC + '\', [StringComparison]::OrdinalIgnoreCase)
    }
    return $true
}

function Add-ToMachinePath {
    param([string]$Folder, [string]$BeforePattern = '')
    if (-not $Folder -or -not (Test-Path -LiteralPath $Folder)) { return }
    $Folder = $Folder.TrimEnd('\')
    if (-not (Test-IsSharedPath $Folder)) {
        Write-Host "    [SKIP] Not adding $Folder to System PATH (inside a user profile - contestant cannot read it)." -ForegroundColor Yellow
        return
    }
    $parts = @((Get-MachinePathRaw) -split ';' | Where-Object { $_ })
    $expanded = @($parts | ForEach-Object { [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') })
    if ($expanded -contains $Folder) { return }

    $idx = -1
    if ($BeforePattern) {
        for ($i = 0; $i -lt $expanded.Count; $i++) { if ($expanded[$i] -match $BeforePattern) { $idx = $i; break } }
    }
    if ($idx -ge 0) {
        $new = @(); if ($idx -gt 0) { $new += $parts[0..($idx - 1)] }; $new += $Folder; $new += $parts[$idx..($parts.Count - 1)]
    } else {
        $new = $parts + $Folder
    }
    Set-MachinePathRaw $new
    Write-Host "    [OK] Added to System PATH: $Folder" -ForegroundColor Green
}

function Remove-UserProfileDirsFromMachinePath {
    # Older versions of this toolkit could put e.g. C:\Users\Admin\AppData\Local\Programs\Python\...
    # into the System PATH. Those entries only ever worked for that one admin account.
    $parts = @((Get-MachinePathRaw) -split ';' | Where-Object { $_ })
    $keep = @(); $removed = @()
    foreach ($p in $parts) {
        # Only hard-coded paths (e.g. C:\Users\Admin\...). %USERPROFILE%-style entries are left alone.
        $raw = $p.Trim()
        if ($raw.StartsWith($script:UsersRoot + '\', [StringComparison]::OrdinalIgnoreCase) -and
            -not $raw.StartsWith($env:PUBLIC, [StringComparison]::OrdinalIgnoreCase)) { $removed += $p } else { $keep += $p }
    }
    if ($removed.Count -gt 0) {
        Set-MachinePathRaw $keep
        foreach ($r in $removed) { Write-Host "    [FIXED] Removed per-user folder from System PATH: $r" -ForegroundColor Yellow }
    }
}

function Find-SharedExe {
    # Look for an executable ONLY in places the contestant can use: System PATH + given folders.
    param([string]$Exe, [string[]]$ExtraDirs = @())
    $dirs = @(Get-MachinePathDirs) + @($ExtraDirs)
    foreach ($d in $dirs) {
        if (-not $d) { continue }
        foreach ($dir in @(Resolve-Path -Path $d -ErrorAction SilentlyContinue)) {
            $candidate = Join-Path $dir.ProviderPath $Exe
            if ((Test-Path -LiteralPath $candidate) -and (Test-IsSharedPath $candidate)) {
                # Skip symlinks/redirect stubs (winget "Links" folder) - GCC breaks when started via a symlink.
                $item = Get-Item -LiteralPath $candidate -ErrorAction SilentlyContinue
                if ($item -and $item.LinkType) { continue }
                return $candidate
            }
        }
    }
    return $null
}

# -------------------------------------------------------------------------------------------
# VS Code
# -------------------------------------------------------------------------------------------
function Get-VSCodeSystemExe {
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if (-not $base) { continue }
        $exe = Join-Path $base 'Microsoft VS Code\Code.exe'
        if (Test-Path -LiteralPath $exe) { return $exe }
    }
    return $null
}

function Get-VSCodeCli {
    $exe = Get-VSCodeSystemExe
    if (-not $exe) { return $null }
    $cli = Join-Path (Split-Path -Parent $exe) 'bin\code.cmd'
    if (Test-Path -LiteralPath $cli) { return $cli }
    return $null
}

function Get-RequiredExtensions {
    $file = Join-Path $script:RepoRoot 'configs\vscode\extensions.txt'
    if (-not (Test-Path -LiteralPath $file)) { return @('formulahendry.code-runner') }
    @(Get-Content -LiteralPath $file | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') })
}

function Test-ExtensionPresent([string]$ExtDir, [string]$Id) {
    if (-not (Test-Path -LiteralPath $ExtDir)) { return $false }
    $hit = Get-ChildItem -LiteralPath $ExtDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "$Id-*" } | Select-Object -First 1
    return ($null -ne $hit)
}

function Repair-ExtensionsManifest([string]$ExtDir) {
    <#
        VS Code keeps a list of installed extensions in <extensions dir>\extensions.json with
        ABSOLUTE paths. Copying an extensions folder from one account to another (what the old
        script did) leaves those paths pointing at the Administrator's profile, so VS Code in the
        contestant account shows no extensions. Re-point every entry at the folder it now lives in.
    #>
    $manifest = Join-Path $ExtDir 'extensions.json'
    if (-not (Test-Path -LiteralPath $manifest)) { return }
    try {
        $parsed = ConvertFrom-Json -InputObject (Get-Content -LiteralPath $manifest -Raw)
    } catch {
        Remove-Item -LiteralPath $manifest -Force -ErrorAction SilentlyContinue   # VS Code rebuilds it
        return
    }
    $kept = New-Object System.Collections.ArrayList
    foreach ($e in @($parsed)) {
        if ($null -eq $e) { continue }
        $rel = $e.relativeLocation
        if (-not $rel -and $e.location) {
            $p = if ($e.location.fsPath) { $e.location.fsPath } else { $e.location.path }
            if ($p) { $rel = Split-Path -Leaf ($p -replace '/', '\') }
        }
        if (-not $rel) { continue }
        $full = Join-Path $ExtDir $rel
        if (-not (Test-Path -LiteralPath $full)) { continue }
        $uriPath = '/' + $full.Substring(0, 1).ToLower() + ($full.Substring(1) -replace '\\', '/')
        $loc = [ordered]@{ '$mid' = 1; 'path' = $uriPath; 'scheme' = 'file' }
        $e | Add-Member -NotePropertyName relativeLocation -NotePropertyValue $rel -Force
        $e | Add-Member -NotePropertyName location -NotePropertyValue ([pscustomobject]$loc) -Force
        [void]$kept.Add($e)
    }
    $json = ConvertTo-Json -InputObject @($kept.ToArray()) -Depth 32 -Compress
    [IO.File]::WriteAllText($manifest, $json, (New-Object System.Text.UTF8Encoding($false)))
}

# -------------------------------------------------------------------------------------------
# Run a script block as NT AUTHORITY\SYSTEM (needed for protected Windows Update services/tasks)
# -------------------------------------------------------------------------------------------
function Invoke-AsSystem {
    param([Parameter(Mandatory)][string]$ScriptText, [int]$TimeoutSec = 180)
    $work = Join-Path $script:IcpcDataDir 'tmp'
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    $id   = [guid]::NewGuid().ToString('N').Substring(0, 10)
    $ps1  = Join-Path $work "sys_$id.ps1"
    $log  = Join-Path $work "sys_$id.log"
    $done = '__ICPC_DONE__'
    $body = "`$ErrorActionPreference = 'Continue'`r`n& {`r`n$ScriptText`r`n} *>&1 | Out-File -FilePath '$log' -Encoding UTF8`r`n'$done' | Out-File -FilePath '$log' -Append -Encoding UTF8`r`n"
    [IO.File]::WriteAllText($ps1, $body, (New-Object System.Text.UTF8Encoding($true)))

    $taskName = "ICPC_AsSystem_$id"
    $action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ps1`""
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Seconds $TimeoutSec)
    Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settings -Force | Out-Null
    try {
        Start-ScheduledTask -TaskName $taskName
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
            Start-Sleep -Milliseconds 500
            if ((Test-Path -LiteralPath $log) -and ((Get-Content -LiteralPath $log -Raw -ErrorAction SilentlyContinue) -match $done)) { break }
        }
    } finally {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    $out = @()
    if (Test-Path -LiteralPath $log) { $out = @(Get-Content -LiteralPath $log | Where-Object { $_ -ne $done }) }
    Remove-Item -LiteralPath $ps1, $log -Force -ErrorAction SilentlyContinue
    return $out
}

function Test-Online {
    foreach ($target in @(@('1.1.1.1', 443), @('8.8.8.8', 53), @('marketplace.visualstudio.com', 443))) {
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $iar = $tcp.BeginConnect($target[0], $target[1], $null, $null)
            $ok = $iar.AsyncWaitHandle.WaitOne(2500, $false) -and $tcp.Connected
            $tcp.Close()
            if ($ok) { return $true }
        } catch { }
    }
    return $false
}
