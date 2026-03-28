Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [switch]$DryRun,
  [switch]$Force
)

function Write-Step {
  param([string]$Message)
  Write-Host $Message
}

function Invoke-Action {
  param(
    [scriptblock]$Action,
    [string]$Preview
  )

  if ($DryRun) {
    Write-Host "[dry-run] $Preview"
    return
  }

  & $Action
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = Split-Path -Parent $scriptDir
$sourceFile = Join-Path $repoDir "vscode/instructions/personal-dev-rules.instructions.md"

if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
  throw "source file not found: $sourceFile"
}

$channels = @("Code", "Code - Insiders")

Write-Step "== dotfiles Windows setup =="
Write-Step "repo: $repoDir"

foreach ($channel in $channels) {
  $userDir = Join-Path $env:APPDATA "$channel/User"
  if (-not (Test-Path -LiteralPath $userDir -PathType Container)) {
    Write-Step "skip: $channel User directory not found"
    continue
  }

  $instructionsDir = Join-Path $userDir "instructions"
  $targetFile = Join-Path $instructionsDir "personal-dev-rules.instructions.md"

  Invoke-Action -Preview "mkdir -p $instructionsDir" -Action {
    New-Item -ItemType Directory -Path $instructionsDir -Force | Out-Null
  }

  if (Test-Path -LiteralPath $targetFile) {
    if (-not $Force) {
      Write-Step "skip: $targetFile already exists (use -Force to replace)"
      continue
    }

    Invoke-Action -Preview "remove $targetFile" -Action {
      Remove-Item -LiteralPath $targetFile -Force
    }
  }

  $createdAsLink = $false
  Invoke-Action -Preview "symlink $targetFile -> $sourceFile" -Action {
    try {
      New-Item -ItemType SymbolicLink -Path $targetFile -Target $sourceFile -Force | Out-Null
      $script:createdAsLink = $true
    }
    catch {
      $script:createdAsLink = $false
    }
  }

  if (-not $createdAsLink) {
    Invoke-Action -Preview "copy $sourceFile -> $targetFile" -Action {
      Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force
    }
    Write-Step "applied by copy: $channel"
  }
  else {
    Write-Step "applied by symlink: $channel"
  }
}

Write-Step "done"
Write-Step "run this again after updating personal-dev-rules to refresh copy-based targets"
