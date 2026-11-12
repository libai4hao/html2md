# html2md 设计文档

## 1. 目标

编写一个脚本，把**指定的**所有 HTML 文件转换为标准语法（GFM）的 Markdown，便于阅读、归档与版本管理。

## 2. 现状

- 工作目录下共 93 个 `.html`（无 `.htm`）。
- 其中 47 个位于 `node_modules` / `build` / `dist` / `.pubcache` / `_probe` / `.dsh-diag` 等构建与缓存目录。
- 其余 46 个「干净」文件分三类：FFmpeg 官方文档（31 个，转换价值最高）、前端 SPA 壳（2 个）、Flutter 插件示例（13 个）。
- 本机已装 pandoc 3.8，可直接 `pandoc -f html -t gfm`。

## 3. 方案决策

| 决策点 | 选择 | 理由 |
|--------|------|------|
| 转换工具 | pandoc | HTML→Markdown 事实标准，覆盖表格/代码块/链接/列表 |
| Markdown 方言 | GFM (`-t gfm`) | 事实标准，兼容性最好 |
| 输出位置 | 统一新目录（默认 `md_output/`） | 不污染源目录 |
| 输出结构 | 相对路径镜像源树 | 同名文件（多个 `index.html`）不互相覆盖 |
| 性能 | `ForEach-Object -Parallel` | 并行转换，默认用满 CPU 逻辑核 |
| 增量 | `-Incremental` 按 mtime 跳过 | 大批量重复运行提速 |
| 输出目录 | `-OutDir` 相对拼 cwd、绝对原样用 | 支持任意目标位置 |
| 日志 | `-Log` 追加一行运行摘要 | 含时间戳/耗时/成败统计，事后可追溯 |
| 范围控制 | 黑名单 + `-IncludeBuildArtifacts` | 避免转换大量无意义内容 |
| 输入形式 | 目录 / 单文件 / 通配符 | 满足「指定所有 html」的灵活需求 |

## 4. 实现要点

- **收集**：`Get-ChildItem -Recurse -Include *.html,*.htm`，再按黑名单正则过滤。
- **相对路径基准**（关键逻辑）：
  - 源在 cwd 之内 → 相对 cwd，完整镜像；
  - 源在 cwd 之外 → 相对其父目录，保留源目录自身名字，避免不同源目录同名文件冲突。
- **并行**：`ForEach-Object -Parallel -ThrottleLimit`，每个线程内 `& pandocPath -f html -t gfm -o $_.Out $_.Src`，用 `$using:` 传 pandoc 路径与开关。
- **增量**：`(目标 md 的 LastWriteTime) >= (源 html 的 LastWriteTime)` 视为已最新，跳过。
- **输出目录**：`[System.IO.Path]::IsPathRooted($OutDir)` 判断，绝对路径直接用，相对路径 `Join-Path $cwd $OutDir`。
- **日志**：`-Log` 时用 `Add-Content -Encoding utf8` 追加一行摘要（时间戳、源、找到/待转/跳过/成功/失败数、耗时、输出目录）。
- **退出码**：有失败则 `exit 1`，便于脚本化。

## 5. 验证

- 绝对路径目录源（cwd 外）：成功 32、失败 0，输出树 `md_output\doc\*.md` 正确镜像。
- 增量复跑：`待转换 0，跳过 32`，秒级返回。
- 通配符源（`TradeSpar\*.html`）：成功 1，输出 `md_output\index.md`。
- 绝对路径 `-OutDir`：输出正确落在指定盘符目录，无 `Join-Path` 拼错。
- `-Log`：追加一行含时间戳/耗时/成败统计的摘要日志。
- 32 个 FFmpeg 文档并行转换（16 核）约 14–15 秒，此前串行约 3 倍以上耗时。

## 6. 已知限制与后续

- pandoc 对源 HTML 残留的 `<div>`/`<span>` 无法 100% 剥离，需要「完全纯净 md」时另行处理。
- 后续可迭代：进度条（转换中百分比）、自定义黑名单参数、DryRun 预览、输出扁平化选项。
