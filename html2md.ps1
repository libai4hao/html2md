<#
.SYNOPSIS
    把指定路径下的所有 HTML 文件批量转换为 GFM 语法的 Markdown。

.DESCRIPTION
    基于 pandoc，并行转换（默认按 CPU 逻辑核数），支持增量跳过已转换文件。

.EXAMPLE
    .\html2md.ps1
    当前目录下所有干净的 html → md_output/（镜像源目录结构）

.EXAMPLE
    .\html2md.ps1 "ffmpeg-*\doc"
    只转换该目录/通配符下的 html

.EXAMPLE
    .\html2md.ps1 -Source "TradeSpar\*.html" -OutDir "out" -Throttle 4
    指定输出目录并限制并行度为 4

.EXAMPLE
    .\html2md.ps1 -Incremental
    跳过已存在且源未变化的 md（再次运行提速）

.EXAMPLE
    .\html2md.ps1 -OutDir "D:\docs\md" -Log "convert.log"
    指定绝对输出目录，并把本次运行摘要追加写入日志文件
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Source = ".",

    [string]$OutDir = "md_output",

    # 并行度；0 = 自动（CPU 逻辑核数）
    [ValidateRange(0, 64)]
    [int]$Throttle = 0,

    # 跳过已存在且源文件未变化的目标 md
    [switch]$Incremental,

    # 一并转换构建/缓存目录下的 html
    [switch]$IncludeBuildArtifacts,

    # 静默：成功文件不逐条打印
    [switch]$Quiet,

    # 可选：把本次运行摘要追加写入日志文件（含时间戳/耗时/成败统计）
    [string]$Log
)

$ErrorActionPreference = "Stop"

# ── 1. 依赖检查 ────────────────────────────────────────────────
$pandoc = Get-Command pandoc -ErrorAction SilentlyContinue
if (-not $pandoc) {
    Write-Host "`n✖ 未找到 pandoc" -ForegroundColor Red
    Write-Host "  安装:  winget install JohnMacFarlane.Pandoc" -ForegroundColor DarkGray
    Write-Host "  或访问  https://pandoc.org/installing.html`n" -ForegroundColor DarkGray
    exit 1
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$cwd = (Get-Location).Path

# ── 2. 收集源文件 ──────────────────────────────────────────────
$cwdTrim = $cwd.TrimEnd('\')
$item = @(Get-Item -Path $Source -ErrorAction SilentlyContinue)[0]

if ($item -and $item.PSIsContainer) {
    # 目录源：递归收集
    $files = Get-ChildItem -Path $item.FullName -Recurse -File -Include *.html, *.htm
    $srcFull = $item.FullName.TrimEnd('\')
    # 基准目录：源在 cwd 之内 → 相对 cwd（完整镜像）；源在 cwd 之外 → 相对其父目录（保留源目录自身名字）
    $base = if ($srcFull -eq $cwdTrim -or $srcFull.StartsWith($cwdTrim + '\')) { $cwdTrim } else { Split-Path $srcFull -Parent }
}
else {
    # 通配符 / 单文件
    $files = Get-ChildItem -Path $Source -File | Where-Object { $_.Name -match '\.html?$' }
    $filesArr = @($files)
    $first = if ($filesArr.Count) { $filesArr[0].FullName } else { $cwdTrim }
    $base = if ($first.StartsWith($cwdTrim + '\')) { $cwdTrim } else { Split-Path $first -Parent }
}

if (-not $IncludeBuildArtifacts) {
    $skip = '\\node_modules\\|\\build\\|\\dist\\|\\\.pubcache\\|\\_probe\\|\\\.dsh-diag\\|\\\.git\\|\\\.venv\\'
    $files = $files | Where-Object { $_.FullName -notmatch $skip }
}

$files = @($files)
if ($files.Count -eq 0) {
    Write-Host "✖ 未找到 html 文件（Source=$Source）" -ForegroundColor Yellow
    exit 0
}

# ── 3. 计算目标路径（输出树镜像源树）────────────────────────────
# OutDir：绝对路径直接用；相对路径拼到 cwd
$outRoot = if ([System.IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $cwd $OutDir }
$jobs = foreach ($f in $files) {
    $rel = $f.FullName.Substring($base.Length).TrimStart('\', '/')
    [pscustomobject]@{
        Src = $f.FullName
        Out = Join-Path $outRoot ($rel -replace '\.html?$', '.md')
        Rel = $rel
    }
}

# 增量：跳过已存在且源未变化的目标
$skipped = @()
if ($Incremental) {
    $todo = @()
    foreach ($j in $jobs) {
        if ((Test-Path $j.Out) -and (Get-Item $j.Out).LastWriteTime -ge (Get-Item $j.Src).LastWriteTime) {
            $skipped += $j
        }
        else { $todo += $j }
    }
}
else {
    $todo = $jobs
}

# 预创建输出目录
$todo | ForEach-Object { New-Item -ItemType Directory -Force -Path (Split-Path $_.Out -Parent) | Out-Null }

# ── 4. 并行转换 ────────────────────────────────────────────────
$throttle = if ($Throttle -gt 0) { $Throttle } else { [Environment]::ProcessorCount }
$pandocPath = $pandoc.Source
$isQuiet = [bool]$Quiet

Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  html2md  ·  找到 $($files.Count) 个 html" -ForegroundColor Cyan
if ($Incremental) { Write-Host "  待转换 $($todo.Count) 个，跳过 $($skipped.Count) 个（已是最新）" -ForegroundColor Cyan }
else { Write-Host "  待转换 $($todo.Count) 个" -ForegroundColor Cyan }
Write-Host "  并行度 $throttle  ·  输出 → $outRoot\" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Cyan

if ($todo.Count -eq 0) {
    Write-Host "✔ 全部已是最新，无需转换。`n" -ForegroundColor Green
    exit 0
}

$results = $todo | ForEach-Object -Parallel {
    & $using:pandocPath -f html -t gfm -o $_.Out $_.Src
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        Write-Host "  ✖ 失败  $($_.Rel)" -ForegroundColor Red
    }
    elseif (-not $using:isQuiet) {
        Write-Host "  ✔  $($_.Rel)" -ForegroundColor Green
    }
    [pscustomobject]@{ Ok = ($code -eq 0) }
} -ThrottleLimit $throttle

$ok   = @($results | Where-Object Ok).Count
$fail = @($results | Where-Object { -not $_.Ok }).Count
$sw.Stop()
$elapsed = $sw.Elapsed

# 可选：追加运行日志
if ($Log) {
    $logPath = if ([System.IO.Path]::IsPathRooted($Log)) { $Log } else { Join-Path $cwd $Log }
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$stamp] Source=$Source 找到=$($files.Count) 待转换=$($todo.Count) 跳过=$($skipped.Count) 成功=$ok 失败=$fail 耗时=$($elapsed.TotalSeconds.ToString('0.00'))s 输出=$outRoot"
    Add-Content -Path $logPath -Value $line -Encoding utf8
}

# ── 5. 汇总 ────────────────────────────────────────────────────
Write-Host "`n─────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "  完成：✔ 成功 $ok   ✖ 失败 $fail" -ForegroundColor Cyan
if ($skipped.Count) { Write-Host "  跳过（已最新）：$($skipped.Count)" -ForegroundColor DarkGray }
Write-Host "  耗时 $($elapsed.TotalSeconds.ToString('0.00')) 秒 · 输出目录 $outRoot\" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────`n" -ForegroundColor Cyan

if ($fail -gt 0) { exit 1 }
