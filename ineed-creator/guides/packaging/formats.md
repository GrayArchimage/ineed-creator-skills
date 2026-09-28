# 支持的文件类型

以下白名单对应平台已发布实现，核对日期 2026-09-28。允许托管一种扩展名不代表浏览器能解码所有编码，也不代表平台已支持使用它的所有引擎。

## 普通静态资源

| 分类 | 支持扩展名 | 说明 |
|---|---|---|
| 页面与脚本 | .html .css .js .mjs | 静态生产产物，不运行服务端代码 |
| 数据与文本 | .json .webmanifest .txt .md .xml .csv | manifest 不保证安装为 PWA |
| 图片 | .svg .png .jpg .jpeg .gif .webp .avif .bmp .ico | 实际显示取决于浏览器 |
| 字体 | .woff .woff2 .ttf .otf | 同时核对许可证、动态文字覆盖和体积 |
| 音频 | .mp3 .wav .ogg .aac .flac .m4a | 需验证目标浏览器及用户手势后播放 |
| 视频与字幕 | .mp4 .mov .webm .vtt | 容器支持不等于所有编码可播放 |
| 三维与二进制 | .gltf .glb .bin .data .wasm .pck | WASM / PCK 不表示已开放任意引擎 SDK |
| 文档与下载附件 | .pdf .doc .docx .xls .xlsx .ppt .pptx .zip | 作为资源提供，不递归执行或解包其中程序 |

## Godot 压缩资源

仅在识别为 Godot 的包中，额外接受以下组合：

| 资源 | gzip | Brotli | 逻辑 Content-Type |
|---|---|---|---|
| WASM | .wasm.gz | .wasm.br | application/wasm |
| PCK | .pck.gz | .pck.br | application/octet-stream |
| JS | .js.gz | .js.br | text/javascript |

当前识别依据是包中存在 `.pck`、`.pck.gz` 或 `.pck.br`。平台兼容部分工具压缩后仍保留 `.wasm` 后缀的产物，实际解码和文件头验证必须成功。不要把任意二进制改名为 `.wasm` 规避审核。裸 `.pck` 和 `.js` 不应仅改字节为压缩数据而省略压缩后缀。

普通包的任意 `.br` / `.gz` 文件，以及 `.html.br`、`.css.gz` 等组合不在本次新增范围。详见[压缩要求](compression.md)。

## 当前不承诺支持

Unity SDK 接入、多线程 Godot、Godot C# Web、需要原生扩展的导出、服务端脚本，以及需要主站同源权限才能工作的应用。`.ts`、`.tsx`、`.vue` 等源文件应先构建为支持的静态资源；`.gd`、`.tscn`、`project.godot` 属于源工程而非上传目录。

未知类型先记录用途并交平台开发者评估，不静默删除游戏必需资源。新增类型不得通过放开所有扩展名或主站同源沙箱解决。
