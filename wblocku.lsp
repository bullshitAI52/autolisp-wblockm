;;; WBLOCKU - 从独立 DWG 文件批量更新当前图纸中的同名普通图块。
;;; Windows AutoCAD / Visual LISP。加载后输入 WBLOCKU。
(vl-load-com)

(defun wbu:write-log (path message / fp)
  (if (setq fp (open path "a"))
    (progn (write-line message fp) (close fp))))

(defun wbu:yes (prompt / answer)
  (initget "Yes No")
  (= "Yes" (getkword (strcat prompt " [是(Y)/否(N)] <N>: "))))

(defun wbu:block-risk (block / reason entity)
  (cond
    ((= :vlax-true (vla-get-IsXRef block)) (setq reason "外部参照"))
    ((and (vlax-property-available-p block 'IsDynamicBlock)
          (= :vlax-true (vla-get-IsDynamicBlock block)))
     (setq reason "动态图块")))
  (vlax-for entity block
    (if (= "AcDbAttributeDefinition" (vla-get-ObjectName entity))
      (setq reason "包含属性定义"))
    (if (and (vlax-property-available-p entity 'IsDynamicBlock)
             (= :vlax-true (vla-get-IsDynamicBlock entity)))
      (setq reason "包含动态图块")))
  reason)

(defun wbu:source-check (path / db result reason block)
  ;; ObjectDBX 只读检查源文件；无法检查时不猜测，不执行更新。
  (setq result
    (vl-catch-all-apply 'vla-GetInterfaceObject
      (list (vlax-get-acad-object)
        (strcat "ObjectDBX.AxDbDocument."
          (itoa (atoi (getvar "ACADVER")))))))
  (if (vl-catch-all-error-p result)
    "无法创建 ObjectDBX 检查器（需 Windows 完整版 AutoCAD）"
    (progn
      (setq db result)
      (setq result
        (vl-catch-all-apply
          '(lambda ()
             (vla-Open db path)
             (vlax-for block (vla-get-Blocks db)
               (if (wbu:block-risk block)
                 (setq reason "源文件含属性、动态块或外部参照，第一版跳过")))
             (if (= 0 (vla-get-Count (vla-get-ModelSpace db)))
               (setq reason "源文件模型空间为空")))
          nil))
      (vlax-release-object db)
      (if (vl-catch-all-error-p result)
        (strcat "源文件检查失败：" (vl-catch-all-error-message result))
        reason))))

(defun wbu:signature (name / entity data result)
  ;; 比较块定义实体（含句柄）以避免把命令返回 nil 当作更新成功。
  (setq entity (cdr (assoc -2 (tblsearch "BLOCK" name))))
  (while entity
    (setq data (entget entity))
    (if (= "ENDBLK" (cdr (assoc 0 data)))
      (setq entity nil)
      (progn (setq result (cons data result))
             (setq entity (entnext entity)))))
  result)

(defun wbu:redefine (name path / before)
  (setq before (wbu:signature name))
  ;; name=完整文件路径：显式重定义。取消插入点，不创建新参照。
  (command "_.-INSERT" (strcat name "=" path) nil)
  (if (> (getvar "CMDACTIVE") 0) (command))
  (not (equal before (wbu:signature name))))

(defun c:WBLOCKU (/ *error* doc blocks chosen folder files file name path
                    block flags reason check candidates selected item logfile
                    undo-open saved-echo result changed uncertain skipped)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        blocks (vla-get-Blocks doc)
        saved-echo (getvar "CMDECHO")
        changed 0 uncertain 0 skipped 0)
  (defun *error* (message)
    (if undo-open (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
    (setvar "CMDECHO" saved-echo)
    (if logfile (wbu:write-log logfile (strcat "中断 | " message)))
    (princ (strcat "\n已停止：" message))
    (if undo-open (princ "\n已完成的更新仍在图中；输入 U 可撤销本批次。"))
    (princ))
  (cond
    ((/= 0 (getvar "CMDACTIVE"))
     (princ "\n请先结束其他命令，再运行 WBLOCKU。"))
    ((or (= 0 (logand 1 (getvar "UNDOCTL")))
         (/= 0 (logand 2 (getvar "UNDOCTL")))
         (/= 0 (logand 8 (getvar "UNDOCTL"))))
     (princ "\n请先开启完整撤销并结束已有撤销组，再运行 WBLOCKU。"))
    ((setq chosen (getfiled "选择图块库中的任意 DWG（扫描该文件夹）"
                    (getvar "DWGPREFIX") "dwg" 0))
     (setq folder (vl-filename-directory chosen)
           files (vl-directory-files folder "*.dwg" 1)
           logfile (vl-filename-mktemp "wblocku-" (getvar "TEMPPREFIX") ".log"))
     (wbu:write-log logfile
       (strcat "目标图纸 | " (getvar "DWGPREFIX") (getvar "DWGNAME")))
     (wbu:write-log logfile (strcat "图块库 | " folder))
     (foreach file (acad_strlsort files)
       (setq name (vl-filename-base file)
             path (strcat folder "\\" file)
             reason nil)
       (if (tblsearch "BLOCK" name)
         (progn
           (setq flags (cdr (assoc 70 (tblsearch "BLOCK" name))))
           (cond
             ((or (= "*" (substr name 1 1))
                  (vl-string-search "|" name)
                  (/= 0 (logand flags 125)))
              (setq reason "匿名块、参照块或依赖块"))
             ((= (strcase path)
                  (strcase (strcat (getvar "DWGPREFIX") (getvar "DWGNAME"))))
              (setq reason "源文件就是当前图纸"))
             (T
              (setq block (vla-Item blocks name))
              (setq check (vl-catch-all-apply 'wbu:block-risk (list block)))
              (setq reason (if (vl-catch-all-error-p check)
                             "无法检查目标图块" check))
              (if (not reason) (setq reason (wbu:source-check path)))))
           (if reason
             (progn
               (setq skipped (1+ skipped))
               (princ (strcat "\n跳过：" name " — " reason))
               (wbu:write-log logfile (strcat "跳过 | " name " | " reason)))
             (setq candidates (cons (list name path) candidates))))))
     (setq candidates (reverse candidates))
     (if (not candidates)
       (princ "\n没有可更新的同名普通图块。")
       (progn
         (princ "\n以下文件可用于更新同名图块：")
         (foreach item candidates
           (princ (strcat "\n  " (car item) " <- " (cadr item))))
         (foreach item candidates
           (if (wbu:yes (strcat "\n选择更新「" (car item) "」吗？"))
             (setq selected (cons item selected))))
         (if (and selected
                  (wbu:yes
                    (strcat "\n将更新 " (itoa (length selected))
                      " 种图块的全部参照（含布局及嵌套使用）。请确认源文件基点、单位一致。开始？")))
           (progn
             (vla-StartUndoMark doc)
             (setq undo-open T)
             ;; 保留命令回显，让无法打开文件等原生命令错误可见。
             (setvar "CMDECHO" 1)
             (foreach item (reverse selected)
               (setq result
                 (vl-catch-all-apply 'wbu:redefine (list (car item) (cadr item))))
               (if (> (getvar "CMDACTIVE") 0) (command))
               (cond
                 ((vl-catch-all-error-p result)
                  (setq uncertain (1+ uncertain))
                  (wbu:write-log logfile
                    (strcat "异常，需检查 | " (car item) " | "
                      (vl-catch-all-error-message result))))
                 (result
                  (setq changed (1+ changed))
                  (wbu:write-log logfile (strcat "定义已变化 | " (car item))))
                 (T
                  (setq uncertain (1+ uncertain))
                  (wbu:write-log logfile
                    (strcat "未检测到变化，需检查 | " (car item)))))
               (princ (strcat "\n已处理：" (car item))))
             (vla-Regen doc 1)
             (vla-EndUndoMark doc)
             (setq undo-open nil)
             (setvar "CMDECHO" saved-echo)
             (princ (strcat "\n定义已变化：" (itoa changed)
                      "；需检查：" (itoa uncertain)
                      "；预检跳过：" (itoa skipped) "。"))
             (princ "\n未自动保存图纸。请检查效果；输入 U 可撤销本批次。"))
           (princ "\n已取消，未更新图块。"))))
     (princ (strcat "\n日志：" logfile)))
    (T (princ "\n已取消。")))
  (princ))

(princ "\nWBLOCKU 已加载。输入 WBLOCKU 更新同名普通图块。")
(princ)
