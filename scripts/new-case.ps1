# usage:  .\new-case.ps1 <名称>
# 建 cases\<YYYYMMDD>-<名称>\（含 sim\ 子目录），从 templates\model_plan.md 复制生成 model_plan.md 骨架
param(
  [Parameter(Mandatory=$true)][string]$Name
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$caseId = (Get-Date -Format 'yyyyMMdd') + '-' + $Name
$caseDir = Join-Path $root ('cases\' + $caseId)

if (Test-Path $caseDir) {
  Write-Error "case already exists: $caseDir"
  exit 1
}

New-Item -ItemType Directory -Path $caseDir | Out-Null
New-Item -ItemType Directory -Path (Join-Path $caseDir 'sim') | Out-Null

Copy-Item (Join-Path $root 'templates\model_plan.md') (Join-Path $caseDir 'model_plan.md')

Write-Host "created: $caseDir"
Write-Host '  model_plan.md <- 按模板逐节填写'
Write-Host '  sim\         <- Aspen 文件（engineer 建模产物）'
Write-Host 'next: 与用户对话起草 model_plan.md'