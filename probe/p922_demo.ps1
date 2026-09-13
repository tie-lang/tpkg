# p.9.2.2 package-manager formalization probe (Windows PowerShell)
# Probes: dep-tree resolve/install (path transitive) -> lock; version-constraint
# unsatisfiable -> error; TSHA1-f fingerprint -> pack + install + verify(ok) +
# tamper -> reject. Prints PASS/FAIL, exits non-zero on fail.
# Usage: powershell -ExecutionPolicy Bypass -File probe/p922_demo.ps1 [-Pkg <pkg.exe>]
param([string]$Pkg = "", [string]$Tiec = "F:\Projects\tie-repo\tiec\compiler")
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
if ($Pkg -eq "") { $Pkg = Join-Path $here "..\pkg.exe" }
# ensure `tiec` is on PATH for the pack subcommand (compiles .tieir via exec_code)
if ($Tiec -and (Test-Path $Tiec)) { $env:PATH = $Tiec + ";" + $env:PATH }

function Write-File([string]$path, [string[]]$lines) {
    $dir = Split-Path -Parent $path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    [System.IO.File]::WriteAllLines($path, $lines)
}

function Invoke-Pkg([string]$dir, [string[]]$cl) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Pkg
    $psi.WorkingDirectory = $dir
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.Arguments = ($cl -join ' ')
    # retry the spawn: the sandbox intermittently rejects process creation
    $p = $null
    $attempts = 0
    while ($p -eq $null -and $attempts -lt 5) {
        try {
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $psi
            [void]$p.Start()
        } catch { Start-Sleep -Milliseconds 400; $p = $null; $attempts++ }
    }
    if ($p -eq $null) { return [pscustomobject]@{ Exit = -999; Out = "spawn failed" } }
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return [pscustomobject]@{ Exit = $p.ExitCode; Out = $out + $err }
}

function Assert($cond, $msg) {
    if ($cond) { Write-Host "  [PASS] $msg" -ForegroundColor Green }
    else { Write-Host "  [FAIL] $msg" -ForegroundColor Red; $script:failures++ }
}

$failures = 0
$work = Join-Path $env:TEMP ("tpkg_p922_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force $work | Out-Null
Write-Host "== tpkg p.9.2.2 probe  (work=$work) =="

# ---------- Scenario A: dep tree resolve/install (path transitive) -> lock ----------
Write-Host "[A] dep-tree: path transitive resolve/install -> lock"
$A = Join-Path $work "A"
Write-File "$A\lib_math\tie.pkg"    @('// tie.pkg','// tie:data','[','    "name": "lib_math",','    "version": "1.0.0",','    "main": "lib_math.tie",','    "dependencies": [','    ],',']')
Write-File "$A\lib_math\lib_math.tie" @('// tie:logic','func math_add(x: i64, y: i64) -> i64 { return x + y }')
Write-File "$A\lib_util\tie.pkg"     @('// tie.pkg','// tie:data','[','    "name": "lib_util",','    "version": "1.0.0",','    "main": "lib_util.tie",','    "dependencies": [','        "lib_math": "path:../lib_math",','    ],',']')
Write-File "$A\lib_util\lib_util.tie" @('// tie:logic','func util_square(x: i64) -> i64 { return x * x }')
Write-File "$A\consumer\tie.pkg"     @('// tie.pkg','// tie:data','[','    "name": "consumer",','    "version": "0.1.0",','    "main": "main.tie",','    "dependencies": [','        "lib_util": "path:../lib_util",','    ],',']')
Write-File "$A\consumer\main.tie"    @('// tie:logic','func main() -> i64 { println("ok"); return 0 }')
$r = Invoke-Pkg "$A\consumer" @('install')
Assert ($r.Exit -eq 0) "install exits 0"
Assert (Test-Path "$A\consumer\.tie\deps\lib_util\tie.pkg") "transitive install lib_util"
Assert (Test-Path "$A\consumer\.tie\deps\lib_math\tie.pkg") "transitive dep lib_math pulled"
Assert (Test-Path "$A\consumer\tie.lock") "tie.lock generated"
Assert ((Get-Content "$A\consumer\tie.lock" -Raw) -match 'lib_math') "lock records transitive dep"
$r2 = Invoke-Pkg "$A\consumer" @('install')
Assert ($r2.Exit -eq 0) "idempotent re-install exits 0"

# ---------- Scenario B: version-constraint unsatisfiable -> error ----------
Write-Host "[B] version constraint: local HTTP registry index -> unsat error"
$B = Join-Path $work "B"
Write-File "$B\reg\index.tie" @('mocklib|1.0.0|mock lib','mocklib|1.5.0|mock lib 1.5','mocklib|2.0.0|mock lib 2')
$port = Get-Random -Minimum 8300 -Maximum 8999
$srv = Start-Process python -ArgumentList '-m','http.server',"$port",'--directory',"$B\reg" -NoNewWindow -PassThru
Start-Sleep -Seconds 2
Write-File "$B\con\tie.pkg"  @('// tie.pkg','// tie:data','[','    "name": "con_const",','    "version": "0.1.0",','    "main": "main.tie",','    "dependencies": [','        "mocklib": ">=9.0",','    ],',']')
Write-File "$B\con\main.tie" @('// tie:logic','func main() -> i64 { return 0 }')
$env:TIE_REGISTRY = "http://127.0.0.1:$port"
$r = Invoke-Pkg "$B\con" @('install')
Remove-Item Env:TIE_REGISTRY -ErrorAction SilentlyContinue
Stop-Process -Id $srv.Id -Force -ErrorAction SilentlyContinue
Assert ($r.Exit -ne 0) "unsatisfiable >=9.0 rejected (exit non-zero)"

# ---------- Scenario C: TSHA1-f integrity ----------
Write-Host "[C] TSHA1-f: pack signed unit, install, verify ok, tamper rejects"
$C = Join-Path $work "C"
Write-File "$C\lolib\tie.pkg"   @('// tie.pkg','// tie:data','[','    "name": "lolib",','    "version": "1.0.0",','    "main": "lolib.tie",','    "dependencies": [','    ],',']')
Write-File "$C\lolib\lolib.tie" @('// tie:logic','func main() -> i64 { println("lolib"); return 0 }')
$rp = Invoke-Pkg "$C\lolib" @('pack')
Assert ($rp.Exit -eq 0) "pack builds signed unit (tar.gz + TSHA1-f signature)"
Assert (Test-Path "$C\lolib\signature") "signature written"
Assert ((Get-Content "$C\lolib\signature" -Raw) -match '(?m)^fp: ') "signature holds TSHA1-f fp field"
Write-File "$C\con\tie.pkg"  @('// tie.pkg','// tie:data','[','    "name": "con_app",','    "version": "0.1.0",','    "main": "main.tie",','    "dependencies": [','        "lolib": "path:../lolib",','    ],',']')
Write-File "$C\con\main.tie" @('// tie:logic','func main() -> i64 { println("app"); return 0 }')
$r = Invoke-Pkg "$C\con" @('install')
Assert ($r.Exit -eq 0) "install of signed dep verifies poll (TSHA1-f ok)"
$v1 = Invoke-Pkg "$C\con" @('verify','lolib')
Assert ($v1.Exit -eq 0) "verify lolib -> PASS"
$tieir = "$C\con\.tie\deps\lolib\lolib-1.0.0.tieir"
$fs = [System.IO.File]::Open($tieir,[System.IO.FileMode]::Append); $fs.WriteByte(0); $fs.Dispose()
$v2 = Invoke-Pkg "$C\con" @('verify','lolib')
Assert ($v2.Exit -ne 0) "tampered tieir -> REJECTED (exit non-zero)"

Write-Host ""
Write-Host "== tpkg p.9.2.2 probe done: $failures failure(s) =="
exit $failures