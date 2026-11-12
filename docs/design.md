# html2md 设计文档

## 1. 目标

编写一个脚本，把**指定的**所有 HTML 文件转换为标准语法的 Markdown，便于后续阅读、归档与版本管理。

## 2. 现状

- 工作目录下共 93 个 `.html`（无 `.htm`）。
- 其中 47 个位于 `node_modules` / `build` / `dist` / `.pubcache` / `_probe` / `.dsh-diag` 等构建与缓存目录。
- 其余 46 个「干净」文件分三类：
  - `ffmpeg-*/doc/*.html`：31 个 FFmpeg 官方文档（转换价值最高）；
  - `FxVueLab/index.html`、`TradeSpar/index.html`：2 个前端 SPA 壳，转出内容近乎为空；
  - `merge-local/**/flutter/ephemeral/.plugin_symlinks/...`：13 个 Flutter 插件示例。
- 本机已装 pandoc 3.8，可直接 `pandoc -f html -t gfm`，无需自研 HTML 解析。

## 3. 方案

| 决策点 | 选择 | 理由 |
|--------|------|------|
| 转换工具 | pandoc | HTML→Markdown 事实标准，覆盖表格/代码块/链接/列表 |
| Markdown 方言 | GFM (`-t gfm`) | 事实标准，表格、代码块、链接兼容性最好 |
| 输出位置 | 统一新目录（默认 `md_output/`） | 不污染源目录，便于整体归档 |
| 输出结构 | 相对路径镜像源树 | 同名文件（如多个 `index.html`）不互相覆盖 |
| 范围控制 | 默认跳过构建/缓存目录，`-IncludeBuildArtifacts` 关闭 | 避免转换大量无意义内容 |
| 输入形式 | `-Source` 参数支持目录/单文件/通配符 | 满足「指定所有 html」的灵活需求 |

## 4. 实现要点

- 收集：`Get-ChildItem -Recurse -Include *.html,*.htm`，再按黑名单过滤。
- 相对路径：`$f.FullName.Substring($cwd.Length).TrimStart('\')`，输出树与源树一致。
- 转换：逐文件 `pandoc -f html -t gfm -o $out $f.FullName`，按 `$LASTEXITCODE` 统计成败。

## 5. 验证

- 实测 `ffmpeg-*\doc`：成功 32、失败 0，生成 32 个 `.md`。
- 输出树正确：`md_output\ffmpeg-2026-...\doc\*.md`，最大 `ffmpeg-all.md` 约 2.4 MB。
- 抽查 `ffmpeg.md`：标题、目录、链接均正确渲染为标准 GFM。

## 6. 已知限制与后续

- pandoc 对源 HTML 残留的 `<div>`/`<span>` 无法 100% 剥离（FFmpeg 文档结构杂），零星的这类标签不影响 Markdown 渲染，可在需要「完全纯净 md」时单独处理。
- 后续可迭代方向：并行转换、进度条、增量（跳过已存在且源未变的 md）、自定义黑名单。
