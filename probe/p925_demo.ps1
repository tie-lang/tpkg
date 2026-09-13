# p.9.2.5 scaffold tpkg new probe (Windows PowerShell)
# Probes: `tpkg new <project>` generates the standard skeleton (src/ + tie.pkg +
# README + .gitignore + LICENSE), name-parameterized; compiling the hello entry
# with tiec runs; manifest is correct; existing-dir / invalid-name rejected.
# Usage: powershell -ExecutionPolicy Bypass -File probe/p925_demo.ps1 [-Pkg <pkg.exe>] [-Tiec <dir>]
param([string]$Pkg = "", [string]$Tiec = "F:\Projects\tie-repo\tiec\compiler")
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
if ($Pkg -eq "") { $Pkg = Join-Path $here "..\pkg.exe" }

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
$work = Join-Path $env:TEMP ("tpkg_p925_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force $work | Out-Null
Write-Host "== tpkg p.9.2.5 scaffold probe  (work=$work) =="

# 1) new <project> (no --git) generates skeleton
$r = Invoke-Pkg $work @('new','myproj')
Assert ($r.Exit -eq 0) "new myproj exits 0"
$proj = Join-Path $work "myproj"
Assert (Test-Path "$proj\src\main.tie") "src/main.tie generated"
Assert (Test-Path "$proj\tie.pkg") "tie.pkg manifest generated"
Assert (Test-Path "$proj\README.md") "README.md generated"
Assert (Test-Path "$proj\.gitignore") ".gitignore generated"
Assert (Test-Path "$proj\LICENSE") "LICENSE generated"
Assert (-not (Test-Path "$proj\.git")) "no git init without --git"
$pkg = Get-Content "$proj\tie.pkg" -Raw
Assert (($pkg -match '"name": "myproj"')) "manifest name parameterized -> myproj"
Assert (($pkg -match '"main": "src/main.tie"')) "manifest main -> src/main.tie"

# 2) compile the generated hello with tiec and run it
$env:PATH = ($Tiec + ";" + $env:PATH)
function Run-Exe([string]$fp, [string]$dir, [string[]]$cl) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $fp
    $psi.WorkingDirectory = $dir
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.Arguments = ($cl -join ' ')
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return [pscustomobject]@{ ExitCode = $p.ExitCode; Out = $out + $err }
}
$ti = Run-Exe (Join-Path $Tiec "tiec.exe") $proj @('src/main.tie','-o','hello.exe','--no-cache')
if ($ti.ExitCode -ne 0) { Write-Host "  [tiec output] $($ti.Out)" }
Assert ($ti.ExitCode -eq 0) "tiec compiles scaffold hello"
if (Test-Path (Join-Path $proj "hello.exe")) {
    $run = Run-Exe (Join-Path $proj "hello.exe") $proj @()
    Assert ($run.ExitCode -eq 0) "scaffold hello runs (exit 0)"
} else {
    Assert $false "scaffold hello runs (hello.exe absent)"
}

# 3) rejection: existing dir / invalid name
$r2 = Invoke-Pkg $work @('new','myproj')
Assert ($r2.Exit -ne 0) "existing dir rejected (exit non-zero)"
$r3 = Invoke-Pkg $work @('new','a/b')
Assert ($r3.Exit -ne 0) "invalid name (path separator) rejected (exit non-zero)"

Write-Host ""
Write-Host "== tpkg p.9.2.5 probe done: $failures failure(s) =="
exit $failures