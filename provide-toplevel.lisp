(proclaim '(optimize (speed 0) (safety 3) (debug 3)))

(defpackage provide-toplevel
  (:export add-hook)
  (:use cl))

(in-package provide-toplevel)

(defparameter *toplevel-hooks* nil)

(defun apply-hooks (form)
   (reduce (lambda (x xs) (funcall xs x)) *toplevel-hooks* :initial-value form))

(defun add-hook (function)
   (push function *toplevel-hooks*))

;; add hook for swank on eval-region form variable

;; repl hook

(defun repl-read-form (in out)
  (declare (type stream in out) (ignore out))
  ;; KLUDGE: *READ-SUPPRESS* makes the REPL useless, and cannot be
  ;; recovered from -- flip it here.
  (when sb-impl::*read-suppress*
    (warn "Setting *READ-SUPPRESS* to NIL to restore toplevel usability.")
    (setf sb-impl::*read-suppress* nil))
  (let* ((eof-marker (cons nil nil))
         (form (read in nil eof-marker)))
    (if (eq form eof-marker)
        (sb-ext::exit)
        (apply-hooks form))))

(setf sb-impl::*repl-read-form-fun* #'repl-read-form)

;; source file loading hook

(in-package sb-fasl)

(sb-ext:without-package-locks
 (defun load-as-source (stream &key verbose print (context "loading"))
   (maybe-announce-load stream verbose)
   (let* ((pathname (ignore-errors (translate-logical-pathname stream)))
          (native (when pathname (native-namestring pathname))))
     (with-simple-restart (abort "Abort ~A file ~S." context native)
       (labels ((condition-herald (c)
                  (declare (ignore c))  ; propagates up
                  (when (form-tracking-stream-p stream)
                    (let* ((startpos
                            (form-tracking-stream-form-start-char-pos stream))
                           (point (line/col-from-charpos stream startpos)))
                      (format *error-output* "~&While evaluating the form ~
starting at line ~D, column ~D~%  of ~S:"
                              (car point) (cdr point)
                              (or pathname stream)))))
                (eval-form (form index)
                  (with-simple-restart (continue "Ignore error and continue ~A file ~S."
                                                 context native)
                    (loop
                       (handler-bind ((serious-condition #'condition-herald))
                         (with-simple-restart (retry "Retry EVAL of current toplevel form.")
                           (if print
                               (let ((results (multiple-value-list (eval-tlf form index))))
                                 (load-fresh-line)
                                 (format t "~{~S~^, ~}~%" results))
                               (eval-tlf form index)))
                         (return))))))
         (if pathname
             (let* ((info (sb-c::make-file-source-info
                           pathname (stream-external-format stream)))
                    (sb-c::*source-info* info))
               (setf (sb-c::source-info-stream info) stream)
               (sb-c::do-forms-from-info ((form current-index) info
                                          'sb-c::input-error-in-load)
                 (sb-c::with-source-paths
                   (sb-c::find-source-paths form current-index)
                   (eval-form (provide-toplevel::apply-hooks form) current-index))))
             (let ((sb-c::*source-info* nil))
               (do ((form (read stream nil *eof-object*)
                          (read stream nil *eof-object*)))
                   ((eq form *eof-object*))
                 (sb-c::with-source-paths
                   (eval-form form nil))))))))
   t))

(when (find-package 'swank) 
      (in-package swank)
      (defun swank::eval-region (string)
      "Evaluate STRING.
      Return the results of the last form as a list and as secondary value the 
      last form."
       (with-input-from-string (stream string)
         (let (- values)
           (loop
              (let ((form (provide-toplevel::apply-hooks (read stream nil stream))))
                (when (eq form stream)
                  (finish-output)
                  (return (values values -)))
                (setq - form)
                (setq values (multiple-value-list (eval form)))
                (finish-output)))))))
