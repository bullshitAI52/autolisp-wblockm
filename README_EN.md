# AutoLISP WBLOCKM

This project contains AutoLISP utilities for exporting blocks from AutoCAD in batches. It is useful when a drawing contains many reusable blocks that need to be saved as separate DWG files.

## Usage

1. Load `wblockm.lsp` or `wblocku.lsp` with AutoCAD `APPLOAD`.
2. Run the command documented in the source file.
3. Select the blocks to export and choose an output folder.
4. Review the exported DWG files and any overwrite prompts.

Test on a copy first, especially when using Chinese paths or existing output files.
