# Called from scripts/install.sh (WSL). Points the Startup shortcut at the copied
# AutoHotkey script and (re)starts it.
#
# Output is one ASCII token per line; install.sh translates them into Japanese messages,
# because Windows PowerShell writes to the WSL pipe in the OEM code page (cp932).
#   no-autohotkey         .ahk has no file association (AutoHotkey v2 not installed)
#   old-shortcut-removed  removed another Startup shortcut that launched the same script name
#   shortcut-created      created or re-targeted our Startup shortcut
#   restarted             stopped old instances of the script and started the copy
param(
    [Parameter(Mandatory = $true)][string]$Script,
    [Parameter(Mandatory = $true)][string]$ShortcutName,
    [switch]$Changed
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path 'Registry::HKEY_CLASSES_ROOT\AutoHotkeyScript\Shell\Open\Command')) {
    'no-autohotkey'
    exit 0
}

$startup = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startup $ShortcutName
$scriptName = Split-Path $Script -Leaf
$shell = New-Object -ComObject WScript.Shell

# The pre-dotfiles shortcut (e.g. one pointing into Dropbox) would start a second instance.
foreach ($link in Get-ChildItem $startup -Filter *.lnk) {
    if ($link.FullName -eq $shortcutPath) { continue }
    $target = $shell.CreateShortcut($link.FullName).TargetPath
    if (-not $target) { continue }
    if ((Split-Path $target -Leaf) -ne $scriptName) { continue }
    Remove-Item $link.FullName
    'old-shortcut-removed'
}

$shortcut = $shell.CreateShortcut($shortcutPath)
if ($shortcut.TargetPath -ne $Script) {
    $shortcut.TargetPath = $Script
    $shortcut.WorkingDirectory = Split-Path $Script
    $shortcut.Save()
    'shortcut-created'
}

# AutoHotkey treats the same script at another path as a different script, so the old
# Dropbox instance must be stopped explicitly. Instances are found by script file name.
$instances = @(Get-CimInstance Win32_Process -Filter "Name LIKE 'AutoHotkey%'" |
    Where-Object { $_.CommandLine -and $_.CommandLine.Contains($scriptName) })
$runningCopy = @($instances | Where-Object { $_.CommandLine.Contains($Script) })
if ($Changed -or $runningCopy.Count -eq 0 -or $instances.Count -ne $runningCopy.Count) {
    foreach ($process in $instances) { Stop-Process -Id $process.ProcessId -Force }
    Start-Process $Script
    'restarted'
}
