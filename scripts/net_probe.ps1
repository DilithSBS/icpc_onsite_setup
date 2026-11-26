<#
.SYNOPSIS
    Checks that the internet is really unreachable (used by 04_verify_env.bat).
    Ping alone is not enough: a PC can block ping and still open web pages, so this tries real
    TCP/HTTPS connections, DNS and an HTTP request through the system proxy.
    Exit code = number of successful connections to the outside world (0 = locked down).
#>
param([string]$ServerIP = '')

function Test-Tcp([string]$HostName, [int]$Port, [int]$TimeoutMs = 2500) {
    try {
        $c = New-Object System.Net.Sockets.TcpClient
        $iar = $c.BeginConnect($HostName, $Port, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false) -and $c.Connected
        $c.Close()
        return [bool]$ok
    } catch { return $false }
}

$leaks = 0
foreach ($t in @(@('1.1.1.1', 443), @('8.8.8.8', 443), @('8.8.8.8', 53), @('9.9.9.9', 443), @('208.67.222.222', 443))) {
    if (Test-Tcp $t[0] $t[1]) { Write-Host "  [LEAK] Connected to $($t[0]):$($t[1])"; $leaks++ }
}

$resolved = $null
try { $resolved = [System.Net.Dns]::GetHostAddresses('www.google.com') | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1 } catch { }
if ($resolved) {
    Write-Host "  [NOTE] DNS still resolves www.google.com -> $resolved (possibly cached)"
    if (Test-Tcp $resolved.ToString() 443) { Write-Host "  [LEAK] Connected to www.google.com:443"; $leaks++ }
}

try {
    $r = Invoke-WebRequest -Uri 'http://www.msftconnecttest.com/connecttest.txt' -UseBasicParsing -TimeoutSec 6 -ErrorAction Stop
    if ($r.StatusCode -eq 200) { Write-Host "  [LEAK] HTTP request through the system proxy succeeded"; $leaks++ }
} catch { }

if ($ServerIP) {
    $web = (Test-Tcp $ServerIP 80) -or (Test-Tcp $ServerIP 443)
    if ($web) { Write-Host "  [INFO] DOMjudge web server $ServerIP answers on port 80/443." }
    else { Write-Host "  [INFO] DOMjudge web server $ServerIP does not answer on port 80/443 (offline or different IP?)." }
}
exit $leaks
