;;; WBLOCKM - 导出当前图纸中的本地图块定义
;;; 整理版：支持中文路径、覆盖确认和错误日志。
;;; 命令：WBLOCKM

(vl-load-com)

(defun wbm:log (logfile message / fp)
  (if (setq fp (open logfile "a"))
    (progn
      (write-line
        (strcat (menucmd "M=$(edtime,$(getvar,date),YYYY-MM-DD HH:MM:SS)") " " message)
        fp
      )
      (close fp)
    )
  )
)

(defun wbm:yes-p (value)
  (member (strcase (vl-string-trim " \t" value)) '("Y" "YES" "是" "确认"))
)

(defun wbm:exportable-block-p (name / excluded)
  ;; 匿名块、依赖块和 AutoCAD 标注箭头块不导出。
  (and name
       (/= (substr name 1 1) "*")
       (not (vl-string-search "|" name))
       (not (wcmatch name "_ArchTick,_BoxBlank,_BoxFilled,_Closed,_ClosedBlank,_DatumBlank,_DatumFilled,_Dot,_DotBlank,_DotSmall,_Integral,_Oblique,_Open,_Open30,_Open90,_Origin,_Origin2,Small"))
  )
)

(defun wbm:block-names (/ item result)
  (setq item (tblnext "BLOCK" T))
  (while item
    (if (wbm:exportable-block-p (cdr (assoc 2 item)))
      (setq result (cons (cdr (assoc 2 item)) result))
    )
    (setq item (tblnext "BLOCK"))
  )
  (acad_strlsort result)
)

(defun wbm:target-folder (/ drawing-name folder)
  ;; DWGPREFIX 已由 AutoCAD 返回带中文字符的完整路径；不手工转码。
  (setq drawing-name (getvar "DWGNAME"))
  (setq folder (vl-filename-mktemp "" (getvar "DWGPREFIX")))
  (if folder (vl-file-delete folder))
  (strcat (getvar "DWGPREFIX")
          (vl-filename-base drawing-name)
          "_导出图块")
)

(defun wbm:export-one (source target logfile / answer result)
  (setq answer
    (if (findfile (strcat target ".dwg"))
      (getstring T (strcat "文件已存在：" target ".dwg，覆盖吗（Y/N）<N>: "))
      "Y"
    )
  )
  (if (wbm:yes-p answer)
    (progn
      (if (findfile (strcat target ".dwg"))
        (vl-file-delete (strcat target ".dwg"))
      )
      (setq result (vl-catch-all-apply 'command (list "_.-WBLOCK" target source)))
      (if (vl-catch-all-error-p result)
        (progn
          (wbm:log logfile (strcat "失败 | " source " | " (vl-catch-all-error-message result)))
          nil
        )
        (progn
          (wbm:log logfile (strcat "成功 | " source " | " target ".dwg"))
          T
        )
      )
    )
    (progn
      (wbm:log logfile (strcat "跳过 | " source " | 用户未确认覆盖"))
      nil
    )
  )
)

(defun c:WBLOCKM (/ oldecho names count answer folder logfile done skipped name target)
  (setq oldecho (getvar "CMDECHO"))
  (setvar "CMDECHO" 0)
  (setq names (wbm:block-names) count (length names))
  (princ (strcat "\n当前图纸可导出的块定义数量：" (itoa count)))
  (setq answer (getstring "\n是否导出这些图块（Y/N）<N>: "))
  (if (wbm:yes-p answer)
    (progn
      (setq folder (wbm:target-folder))
      (if (not (vl-file-directory-p folder)) (vl-mkdir folder))
      (setq logfile (strcat folder "\\wblockm.log"))
      (wbm:log logfile (strcat "开始 | 图纸：" (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (setq done 0 skipped 0)
      (foreach name names
        (setq target (strcat folder "\\" name))
        (if (wbm:export-one name target logfile)
          (setq done (1+ done))
          (setq skipped (1+ skipped))
        )
      )
      (wbm:log logfile (strcat "结束 | 成功：" (itoa done) " | 跳过或失败：" (itoa skipped)))
      (princ (strcat "\n完成：成功导出 " (itoa done) " 个，跳过或失败 " (itoa skipped) " 个。"))
      (princ (strcat "\n日志：" logfile))
      (startapp "explorer.exe" folder)
    )
    (princ "\n已取消。")
  )
  (setvar "CMDECHO" oldecho)
  (princ)
)

(princ "\nWBLOCKM 已加载。输入 WBLOCKM 开始导出图块。")
(princ)
