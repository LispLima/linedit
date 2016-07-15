;; Copyright (c) 2003 Nikodemus Siivola
;;
;; Permission is hereby granted, free of charge, to any person obtaining
;; a copy of this software and associated documentation files (the
;; "Software"), to deal in the Software without restriction, including
;; without limitation the rights to use, copy, modify, merge, publish,
;; distribute, sublicense, and/or sell copies of the Software, and to
;; permit persons to whom the Software is furnished to do so, subject to
;; the following conditions:
;;
;; The above copyright notice and this permission notice shall be included
;; in all copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
;; IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
;; CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
;; TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
;; SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

(in-package :linedit)

;;; BUFFER offers a simple browsable from of storage. It is used to
;;; implement both the kill-ring and history.

(defclass buffer ()
  ((prev :initarg :prev :accessor %buffer-prev :initform nil)
   (next :initarg :next :accessor %buffer-next :initform nil)
   (list :initarg :list :accessor %buffer-list :initform nil)))

(defun copy-buffer (buffer)
  (make-instance 'buffer
                 :prev (%buffer-prev buffer)
                 :next (%buffer-next buffer)
                 :list (%buffer-list buffer)))

(defun buffer-push (string buffer)
  (unless (equal string (car (%buffer-list buffer)))
    (push string (%buffer-list buffer))
    (setf (%buffer-next buffer) nil
          (%buffer-prev buffer) (%buffer-list buffer))))

(defun buffer-find-previous-if (test buffer)
  (awhen (position-if test (%buffer-prev buffer))
    (loop repeat (1+ it)
          do (push (pop (%buffer-prev buffer))
                   (%buffer-next buffer)))
    (car (%buffer-next buffer))))

(defun buffer-previous (string buffer)
  (when (%buffer-prev buffer)
    (push string (%buffer-next buffer))
    (pop (%buffer-prev buffer))))

(defun buffer-peek (buffer)
  (aif (%buffer-prev buffer)
       (car it)))

(defun buffer-find-next-if (test buffer)
  (awhen (position-if test (%buffer-next buffer))
    (loop repeat (1+ it)
          do (push (pop (%buffer-next buffer)) (%buffer-prev buffer)))
    (car (%buffer-prev buffer))))

(defun buffer-next (string buffer)
  (when (%buffer-next buffer)
    (push string (%buffer-prev buffer))
    (pop (%buffer-next buffer))))

(defun buffer-cycle (buffer)
  (flet ((wrap-buffer ()
           (unless (%buffer-prev buffer)
             (setf (%buffer-prev buffer) (reverse (%buffer-next buffer))
                   (%buffer-next buffer) nil))))
    (wrap-buffer)
    (push (pop (%buffer-prev buffer)) (%buffer-next buffer))
    (wrap-buffer)
    t))
