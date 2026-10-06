# AutoLISP 图块批量导出工具

`wblockm.lsp` 用于把当前 AutoCAD 图纸中的本地图块定义逐个导出为独立 DWG 文件。

## 功能

- 输出到与图纸同目录的 `图纸文件名_导出图块` 文件夹。
- 路径由 AutoCAD 的 `DWGPREFIX` 提供，支持包含中文的 Windows 路径。
- 跳过匿名块、依赖块和常见标注箭头块。
- 目标 DWG 已存在时逐个询问是否覆盖，默认不覆盖。
- 在输出目录生成 `wblockm.log`，记录成功、跳过和失败原因。
- 使用 `vl-catch-all-apply` 捕获单个图块导出异常，单个失败不会中断全部任务。

## 加载方法

1. 将 `wblockm.lsp` 保存到本地，例如 `D:\CADTools\wblockm.lsp`。
2. 打开 AutoCAD，输入 `APPLOAD` 并回车。
3. 选择 `wblockm.lsp`，点击“加载”。
4. 输入 `WBLOCKM` 并回车。
5. 确认导出后，到图纸同目录的 `文件名_导出图块` 文件夹查看 DWG 文件和日志。

如果希望每次启动自动加载，可在 APPLOAD 的“启动组”中添加此 LSP。生产环境建议先在副本图纸上测试。

## 覆盖和日志

目标文件已经存在时，命令行会询问 `文件已存在：...，覆盖吗（Y/N）<N>`。输入 `Y` 才会删除旧文件并重新导出；直接回车或输入其他内容则跳过。

日志文件位于输出目录的 `wblockm.log`。日志使用当前 AutoCAD 环境写入，中文路径不进行手工编码转换。

## 兼容性说明

程序使用 Visual LISP 扩展（`vl-load-com`、`vl-file-directory-p`、`vl-filename-base` 等），适用于支持 Visual LISP 的 AutoCAD Windows 版本。未在本地运行 AutoCAD，因此未完成真实 DWG 导出验证。

`WBLOCK` 的命令行参数行为可能随 AutoCAD 版本和语言设置变化。如果某个版本拒绝 `_.-WBLOCK` 的参数顺序，请在该版本中手动执行一次 `-WBLOCK`，确认命令提示后再调整 `wbm:export-one`。

## 来源与许可

本仓库基于用户提供的 AutoLISP 片段整理和修改，原片段署名信息为 `teacoffee`，并保留其提到的 DotSoft 免责声明。用户没有提供单独的许可证，因此本仓库不擅自授予 MIT 等开源许可；使用和再分发请确认原作者及相关权利人的许可。
