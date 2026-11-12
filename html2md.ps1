<#
.SYNOPSIS
    把指定路径下的所有 HTML 文件批量转换为 GFM 语法的 Markdown。

.DESCRIPTION
    依赖 pandoc（本机已装 3.8）。用法示例：

        .\html2md.ps1                          # 当前目录下所有干净 html → md_output/
        .\html2md.ps1 -Source "ffmpeg-*\doc"   # 只转该目录
        .\html2md.ps1 -Source "TradeSpar\*.html" -OutDir "out"

    默认跳过 node_modules / build / dist / .pubcache / _probe / .dsh-diag 等
    构建与缓存目录；用 -IncludeBuildArtifacts 可关闭该跳过。
#>

[CmdletBinding()]
param(
    [string]$Source = ".",
    [string]$OutDir = "md_output",
    [switch]$IncludeBuildArtifacts
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
    Write-Error "未找到 pandoc。请先安装 pandoc 并加入 PATH。"
    exit 1
}

# 1) 收集源文件
$root = (Resolve-Path $Source).Path
if (Test-Path -Path $root -PathType Container) {
    $files = Get-ChildItem -Path $root -Recurse -File -Include *.html,*.htm
}
else {
    # 通配符或单文件：按字面解析
    $files = Get-ChildItem -Path $Source -File -Filter *.htm* | Where-Object { $_.Name -match '\.html?$' }
}

if (-not $IncludeBuildArtifacts) {
    $skip = '\\node_modules\\|\\build\\|\\dist\\|\\\.pubcache\\|\\_probe\\|\\\.dsh-diag\\|\\\.git\\'
    $files = $files | Where-Object { $_.FullName -notmatch $skip }
}

$files = @($files)
if ($files.Count -eq 0) {
    Write-Host "没有找到 html 文件（Source=$Source）。" -ForegroundColor Yellow
    exit 0
}

Write-Host "待转换 $($files.Count) 个文件 → $OutDir/" -ForegroundColor Cyan

# 2) 逐文件转换
$ok = 0; $fail = 0
$outRoot = Join-Path (Get-Location) $OutDir

$cwdPath = (Get-Location).Path

foreach ($f in $files) {
    # 始终相对当前工作目录保留完整源路径，输出树与源树镜像
    $rel = $f.FullName.Substring($cwdPath.Length).TrimStart('\')
    $out = Join-Path $outRoot ($rel -replace '\.html?$', '.md')
    $outDirName = Split-Path $out -Parent
    New-Item -ItemType Directory -Force -Path $outDirName | Out-Null

    pandoc -f html -t gfm -o $out $f.FullName
    if ($LASTEXITCODE -eq 0) {
        $ok++
        Write-Host "  OK  $rel" -ForegroundColor Green
    } else {
        $fail++
        Write-Warning "  失败($LASTEXITCODE)  $rel"
    }
}

Write-Host "完成：成功 $ok，失败 $fail。" -ForegroundColor Cyan
