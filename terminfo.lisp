;;; -*- Mode: LISP; Syntax: ANSI-Common-Lisp; Package: TERMINFO -*-

;;; Copyright � 2001 Paul Foley (mycroft@actrix.gen.nz)
;;;
;;; Permission is hereby granted, free of charge, to any person obtaining
;;; a copy of this Software to deal in the Software without restriction,
;;; including without limitation the rights to use, copy, modify, merge,
;;; publish, distribute, sublicense, and/or sell copies of the Software,
;;; and to permit persons to whom the Software is furnished to do so,
;;; provided that the above copyright notice and this permission notice
;;; are included in all copies or substantial portions of the Software.
;;;
;;; THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
;;; OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;;; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
;;; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
;;; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
;;; OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
;;; BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;;; LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;;; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
;;; USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
;;; DAMAGE.
#+CMU (ext:file-comment "$Header: /project/linedit/cvsroot/src/terminfo.lisp,v 1.5 2003-11-01 20:35:42 nsiivola Exp $")

(in-package "COMMON-LISP-USER")

;; DEFPACKAGE would warn here, since we export things outside the definition
(eval-when (:compile-toplevel :load-toplevel)
  (unless (find-package "TERMINFO")
    (make-package "TERMINFO" :nicknames '("TI") :use '("CL"))))

(in-package "TERMINFO")

(export '(*terminfo-directories* *terminfo* capability tparm tputs
	  set-terminal))

(defvar *terminfo-directories* '("/usr/share/terminfo/"
				 "/usr/share/misc/terminfo/"))

(defvar *terminfo* nil)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defvar *capabilities* (make-hash-table :size 494)))

(flet ((required-argument ()
	 (error "A required argument was not supplied.")))
  (defstruct (terminfo
	       (:print-function
		(lambda (object stream depth)
		  (declare (ignore depth))
		  (print-unreadable-object (object stream :type t :identity t)
		    (format stream "~A" (first (terminfo-names object)))))))
    (names (required-argument) :type list :read-only t)
    (booleans (required-argument) :type (simple-array (member t nil) (*)))
    (numbers (required-argument) :type (simple-array (signed-byte 16) (*)))
    (strings (required-argument) :type (simple-array t (*)))))

#+CMU
(declaim (ext:start-block capability %capability))

(defun %capability (name terminfo)
  (let ((whatsit (gethash name *capabilities*)))
    (when (null whatsit)
      (error "Terminfo capability ~S doesn't exist." name))
    (if (or (null terminfo) (>= (cdr whatsit)
				(length (funcall (car whatsit) terminfo))))
	nil #| default |#
	(let ((value (aref (funcall (car whatsit) terminfo) (cdr whatsit))))
	  (if (and (numberp value) (minusp value))
	      nil
	      value)))))

(declaim (inline capability))
(defun capability (name &optional (terminfo *terminfo*))
  (%capability name terminfo))

#+CMU
(declaim (ext:end-block))

(define-compiler-macro capability (&whole form
				   name &optional (terminfo '*terminfo*))
  (if (not (keywordp name))
      form
      (let ((value (gensym))
	    (tmp (gensym)))
	(unless (gethash name *capabilities*)
	  (warn "Terminfo capability ~S doesn't exist." name))
	`(let ((,value (load-time-value (cons nil nil)))
	       (,tmp ,terminfo))
	   (if (eq (car ,value) ,tmp)
	       (cdr ,value)
	       (setf (car ,value) ,tmp
		     (cdr ,value) (%capability ,name ,tmp)))))))


(defmacro defcap (name type index)
  (let ((thing (ecase type
		 (boolean 'terminfo-booleans)
		 (integer 'terminfo-numbers)
		 (string 'terminfo-strings)))
	(symbol (intern (string name) "KEYWORD")))
    `(progn
       (eval-when (:compile-toplevel)
	 ;; Mark capability as valid for the compiler-macro; needed when
	 ;; compiling TPUTS.  If there's already a value present, leave
	 ;; it alone, else just put any non-NIL value there; it'll get
	 ;; fixed up when the file is loaded.
	 (setf (gethash ,symbol *capabilities*)
	       (gethash ,symbol *capabilities* t)))
       (setf (gethash ,symbol *capabilities*) (cons #',thing ,index))
       (define-symbol-macro ,name (capability ,symbol *terminfo*))
       (export ',name "TERMINFO"))))

(defcap auto-left-margin boolean 0)
(defcap auto-right-margin boolean 1)
(defcap no-esc-ctlc boolean 2)
(defcap ceol-standout-glitch boolean 3)
(defcap eat-newline-glitch boolean 4)
(defcap erase-overstrike boolean 5)
(defcap generic-type boolean 6)
(defcap hard-copy boolean 7)
(defcap has-meta-key boolean 8)
(defcap has-status-line boolean 9)
(defcap insert-null-glitch boolean 10)
(defcap memory-above boolean 11)
(defcap memory-below boolean 12)
(defcap move-insert-mode boolean 13)
(defcap move-standout-mode boolean 14)
(defcap over-strike boolean 15)
(defcap status-line-esc-ok boolean 16)
(defcap dest-tabs-magic-smso boolean 17)
(defcap tilde-glitch boolean 18)
(defcap transparent-underline boolean 19)
(defcap xon-xoff boolean 20)
(defcap needs-xon-xoff boolean 21)
(defcap prtr-silent boolean 22)
(defcap hard-cursor boolean 23)
(defcap non-rev-rmcup boolean 24)
(defcap no-pad-char boolean 25)
(defcap non-dest-scroll-region boolean 26)
(defcap can-change boolean 27)
(defcap back-color-erase boolean 28)
(defcap hue-lightness-saturation boolean 29)
(defcap col-addr-glitch boolean 30)
(defcap cr-cancels-micro-mode boolean 31)
(defcap has-print-wheel boolean 32)
(defcap row-addr-glitch boolean 33)
(defcap semi-auto-right-margin boolean 34)
(defcap cpi-changes-res boolean 35)
(defcap lpi-changes-res boolean 36)

(defcap columns integer 0)
(defcap init-tabs integer 1)
(defcap lines integer 2)
(defcap lines-of-memory integer 3)
(defcap magic-cookie-glitch integer 4)
(defcap padding-baud-rate integer 5)
(defcap virtual-terminal integer 6)
(defcap width-status-line integer 7)
(defcap num-labels integer 8)
(defcap label-height integer 9)
(defcap label-width integer 10)
(defcap max-attributes integer 11)
(defcap maximum-windows integer 12)
(defcap max-colors integer 13)
(defcap max-pairs integer 14)
(defcap no-color-video integer 15)
(defcap buffer-capacity integer 16)
(defcap dot-vert-spacing integer 17)
(defcap dot-horz-spacing integer 18)
(defcap max-micro-address integer 19)
(defcap max-micro-jump integer 20)
(defcap micro-col-size integer 21)
(defcap micro-line-size integer 22)
(defcap number-of-pins integer 23)
(defcap output-res-char integer 24)
(defcap output-res-line integer 25)
(defcap output-res-horz-inch integer 26)
(defcap output-res-vert-inch integer 27)
(defcap print-rate integer 28)
(defcap wide-char-size integer 29)
(defcap buttons integer 30)
(defcap bit-image-entwining integer 31)
(defcap bit-image-type integer 32)

(defcap back-tab string 0)
(defcap bell string 1)
(defcap carriage-return string 2)
(defcap change-scroll-region string 3)
(defcap clear-all-tabs string 4)
(defcap clear-screen string 5)
(defcap clr-eol string 6)
(defcap clr-eos string 7)
(defcap column-address string 8)
(defcap command-character string 9)
(defcap cursor-address string 10)
(defcap cursor-down string 11)
(defcap cursor-home string 12)
(defcap cursor-invisible string 13)
(defcap cursor-left string 14)
(defcap cursor-mem-address string 15)
(defcap cursor-normal string 16)
(defcap cursor-right string 17)
(defcap cursor-to-ll string 18)
(defcap cursor-up string 19)
(defcap cursor-visible string 20)
(defcap delete-character string 21)
(defcap delete-line string 22)
(defcap dis-status-line string 23)
(defcap down-half-line string 24)
(defcap enter-alt-charset-mode string 25)
(defcap enter-blink-mode string 26)
(defcap enter-bold-mode string 27)
(defcap enter-ca-mode string 28)
(defcap enter-delete-mode string 29)
(defcap enter-dim-mode string 30)
(defcap enter-insert-mode string 31)
(defcap enter-secure-mode string 32)
(defcap enter-protected-mode string 33)
(defcap enter-reverse-mode string 34)
(defcap enter-standout-mode string 35)
(defcap enter-underline-mode string 36)
(defcap erase-chars string 37)
(defcap exit-alt-charset-mode string 38)
(defcap exit-attribute-mode string 39)
(defcap exit-ca-mode string 40)
(defcap exit-delete-mode string 41)
(defcap exit-insert-mode string 42)
(defcap exit-standout-mode string 43)
(defcap exit-underline-mode string 44)
(defcap flash-screen string 45)
(defcap form-feed string 46)
(defcap from-status-line string 47)
(defcap init-1string string 48)
(defcap init-2string string 49)
(defcap init-3string string 50)
(defcap init-file string 51)
(defcap insert-character string 52)
(defcap insert-line string 53)
(defcap insert-padding string 54)
(defcap key-backspace string 55)
(defcap key-catab string 56)
(defcap key-clear string 57)
(defcap key-ctab string 58)
(defcap key-dc string 59)
(defcap key-dl string 60)
(defcap key-down string 61)
(defcap key-eic string 62)
(defcap key-eol string 63)
(defcap key-eos string 64)
(defcap key-f0 string 65)
(defcap key-f1 string 66)
(defcap key-f10 string 67)
(defcap key-f2 string 68)
(defcap key-f3 string 69)
(defcap key-f4 string 70)
(defcap key-f5 string 71)
(defcap key-f6 string 72)
(defcap key-f7 string 73)
(defcap key-f8 string 74)
(defcap key-f9 string 75)
(defcap key-home string 76)
(defcap key-ic string 77)
(defcap key-il string 78)
(defcap key-left string 79)
(defcap key-ll string 80)
(defcap key-npage string 81)
(defcap key-ppage string 82)
(defcap key-right string 83)
(defcap key-sf string 84)
(defcap key-sr string 85)
(defcap key-stab string 86)
(defcap key-up string 87)
(defcap keypad-local string 88)
(defcap keypad-xmit string 89)
(defcap lab-f0 string 90)
(defcap lab-f1 string 91)
(defcap lab-f10 string 92)
(defcap lab-f2 string 93)
(defcap lab-f3 string 94)
(defcap lab-f4 string 95)
(defcap lab-f5 string 96)
(defcap lab-f6 string 97)
(defcap lab-f7 string 98)
(defcap lab-f8 string 99)
(defcap lab-f9 string 100)
(defcap meta-off string 101)
(defcap meta-on string 102)
(defcap newline string 103)
(defcap pad-char string 104)
(defcap parm-dch string 105)
(defcap parm-delete-line string 106)
(defcap parm-down-cursor string 107)
(defcap parm-ich string 108)
(defcap parm-index string 109)
(defcap parm-insert-line string 110)
(defcap parm-left-cursor string 111)
(defcap parm-right-cursor string 112)
(defcap parm-rindex string 113)
(defcap parm-up-cursor string 114)
(defcap pkey-key string 115)
(defcap pkey-local string 116)
(defcap pkey-xmit string 117)
(defcap print-screen string 118)
(defcap prtr-off string 119)
(defcap prtr-on string 120)
(defcap repeat-char string 121)
(defcap reset-1string string 122)
(defcap reset-2string string 123)
(defcap reset-3string string 124)
(defcap reset-file string 125)
(defcap restore-cursor string 126)
(defcap row-address string 127)
(defcap save-cursor string 128)
(defcap scroll-forward string 129)
(defcap scroll-reverse string 130)
(defcap set-attributes string 131)
(defcap set-tab string 132)
(defcap set-window string 133)
(defcap tab string 134)
(defcap to-status-line string 135)
(defcap underline-char string 136)
(defcap up-half-line string 137)
(defcap init-prog string 138)
(defcap key-a1 string 139)
(defcap key-a3 string 140)
(defcap key-b2 string 141)
(defcap key-c1 string 142)
(defcap key-c3 string 143)
(defcap prtr-non string 144)
(defcap char-padding string 145)
(defcap acs-chars string 146)
(defcap plab-norm string 147)
(defcap key-btab string 148)
(defcap enter-xon-mode string 149)
(defcap exit-xon-mode string 150)
(defcap enter-am-mode string 151)
(defcap exit-am-mode string 152)
(defcap xon-character string 153)
(defcap xoff-character string 154)
(defcap ena-acs string 155)
(defcap label-on string 156)
(defcap label-off string 157)
(defcap key-beg string 158)
(defcap key-cancel string 159)
(defcap key-close string 160)
(defcap key-command string 161)
(defcap key-copy string 162)
(defcap key-create string 163)
(defcap key-end string 164)
(defcap key-enter string 165)
(defcap key-exit string 166)
(defcap key-find string 167)
(defcap key-help string 168)
(defcap key-mark string 169)
(defcap key-message string 170)
(defcap key-move string 171)
(defcap key-next string 172)
(defcap key-open string 173)
(defcap key-options string 174)
(defcap key-previous string 175)
(defcap key-print string 176)
(defcap key-redo string 177)
(defcap key-reference string 178)
(defcap key-refresh string 179)
(defcap key-replace string 180)
(defcap key-restart string 181)
(defcap key-resume string 182)
(defcap key-save string 183)
(defcap key-suspend string 184)
(defcap key-undo string 185)
(defcap key-sbeg string 186)
(defcap key-scancel string 187)
(defcap key-scommand string 188)
(defcap key-scopy string 189)
(defcap key-screate string 190)
(defcap key-sdc string 191)
(defcap key-sdl string 192)
(defcap key-select string 193)
(defcap key-send string 194)
(defcap key-seol string 195)
(defcap key-sexit string 196)
(defcap key-sfind string 197)
(defcap key-shelp string 198)
(defcap key-shome string 199)
(defcap key-sic string 200)
(defcap key-sleft string 201)
(defcap key-smessage string 202)
(defcap key-smove string 203)
(defcap key-snext string 204)
(defcap key-soptions string 205)
(defcap key-sprevious string 206)
(defcap key-sprint string 207)
(defcap key-sredo string 208)
(defcap key-sreplace string 209)
(defcap key-sright string 210)
(defcap key-srsume string 211)
(defcap key-ssave string 212)
(defcap key-ssuspend string 213)
(defcap key-sundo string 214)
(defcap req-for-input string 215)
(defcap key-f11 string 216)
(defcap key-f12 string 217)
(defcap key-f13 string 218)
(defcap key-f14 string 219)
(defcap key-f15 string 220)
(defcap key-f16 string 221)
(defcap key-f17 string 222)
(defcap key-f18 string 223)
(defcap key-f19 string 224)
(defcap key-f20 string 225)
(defcap key-f21 string 226)
(defcap key-f22 string 227)
(defcap key-f23 string 228)
(defcap key-f24 string 229)
(defcap key-f25 string 230)
(defcap key-f26 string 231)
(defcap key-f27 string 232)
(defcap key-f28 string 233)
(defcap key-f29 string 234)
(defcap key-f30 string 235)
(defcap key-f31 string 236)
(defcap key-f32 string 237)
(defcap key-f33 string 238)
(defcap key-f34 string 239)
(defcap key-f35 string 240)
(defcap key-f36 string 241)
(defcap key-f37 string 242)
(defcap key-f38 string 243)
(defcap key-f39 string 244)
(defcap key-f40 string 245)
(defcap key-f41 string 246)
(defcap key-f42 string 247)
(defcap key-f43 string 248)
(defcap key-f44 string 249)
(defcap key-f45 string 250)
(defcap key-f46 string 251)
(defcap key-f47 string 252)
(defcap key-f48 string 253)
(defcap key-f49 string 254)
(defcap key-f50 string 255)
(defcap key-f51 string 256)
(defcap key-f52 string 257)
(defcap key-f53 string 258)
(defcap key-f54 string 259)
(defcap key-f55 string 260)
(defcap key-f56 string 261)
(defcap key-f57 string 262)
(defcap key-f58 string 263)
(defcap key-f59 string 264)
(defcap key-f60 string 265)
(defcap key-f61 string 266)
(defcap key-f62 string 267)
(defcap key-f63 string 268)
(defcap clr-bol string 269)
(defcap clear-margins string 270)
(defcap set-left-margin string 271)
(defcap set-right-margin string 272)
(defcap label-format string 273)
(defcap set-clock string 274)
(defcap display-clock string 275)
(defcap remove-clock string 276)
(defcap create-window string 277)
(defcap goto-window string 278)
(defcap hangup string 279)
(defcap dial-phone string 280)
(defcap quick-dial string 281)
(defcap tone string 282)
(defcap pulse string 283)
(defcap flash-hook string 284)
(defcap fixed-pause string 285)
(defcap wait-tone string 286)
(defcap user0 string 287)
(defcap user1 string 288)
(defcap user2 string 289)
(defcap user3 string 290)
(defcap user4 string 291)
(defcap user5 string 292)
(defcap user6 string 293)
(defcap user7 string 294)
(defcap user8 string 295)
(defcap user9 string 296)
(defcap orig-pair string 297)
(defcap orig-colors string 298)
(defcap initialize-color string 299)
(defcap initialize-pair string 300)
(defcap set-color-pair string 301)
(defcap set-foreground string 302)
(defcap set-background string 303)
(defcap change-char-pitch string 304)
(defcap change-line-pitch string 305)
(defcap change-res-horz string 306)
(defcap change-res-vert string 307)
(defcap define-char string 308)
(defcap enter-doublewide-mode string 309)
(defcap enter-draft-quality string 310)
(defcap enter-italics-mode string 311)
(defcap enter-leftward-mode string 312)
(defcap enter-micro-mode string 313)
(defcap enter-near-letter-quality string 314)
(defcap enter-normal-quality string 315)
(defcap enter-shadow-mode string 316)
(defcap enter-subscript-mode string 317)
(defcap enter-superscript-mode string 318)
(defcap enter-upward-mode string 319)
(defcap exit-doublewide-mode string 320)
(defcap exit-italics-mode string 321)
(defcap exit-leftward-mode string 322)
(defcap exit-micro-mode string 323)
(defcap exit-shadow-mode string 324)
(defcap exit-subscript-mode string 325)
(defcap exit-superscript-mode string 326)
(defcap exit-upward-mode string 327)
(defcap micro-column-address string 328)
(defcap micro-down string 329)
(defcap micro-left string 330)
(defcap micro-right string 331)
(defcap micro-row-address string 332)
(defcap micro-up string 333)
(defcap order-of-pins string 334)
(defcap parm-down-micro string 335)
(defcap parm-left-micro string 336)
(defcap parm-right-micro string 337)
(defcap parm-up-micro string 338)
(defcap select-char-set string 339)
(defcap set-bottom-margin string 340)
(defcap set-bottom-margin-parm string 341)
(defcap set-left-margin-parm string 342)
(defcap set-right-margin-parm string 343)
(defcap set-top-margin string 344)
(defcap set-top-margin-parm string 345)
(defcap start-bit-image string 346)
(defcap start-char-set-def string 347)
(defcap stop-bit-image string 348)
(defcap stop-char-set-def string 349)
(defcap subscript-characters string 350)
(defcap superscript-characters string 351)
(defcap these-cause-cr string 352)
(defcap zero-motion string 353)
(defcap char-set-names string 354)
(defcap key-mouse string 355)
(defcap mouse-info string 356)
(defcap req-mouse-pos string 357)
(defcap get-mouse string 358)
(defcap set-a-foreground string 359)
(defcap set-a-background string 360)
(defcap pkey-plab string 361)
(defcap device-type string 362)
(defcap code-set-init string 363)
(defcap set0-des-seq string 364)
(defcap set1-des-seq string 365)
(defcap set2-des-seq string 366)
(defcap set3-des-seq string 367)
(defcap set-lr-margin string 368)
(defcap set-tb-margin string 369)
(defcap bit-image-repeat string 370)
(defcap bit-image-newline string 371)
(defcap bit-image-carriage-return string 372)
(defcap color-names string 373)
(defcap define-bit-image-region string 374)
(defcap end-bit-image-region string 375)
(defcap set-color-band string 376)
(defcap set-page-length string 377)
(defcap display-pc-char string 378)
(defcap enter-pc-charset-mode string 379)
(defcap exit-pc-charset-mode string 380)
(defcap enter-scancode-mode string 381)
(defcap exit-scancode-mode string 382)
(defcap pc-term-options string 383)
(defcap scancode-escape string 384)
(defcap alt-scancode-esc string 385)
(defcap enter-horizontal-hl-mode string 386)
(defcap enter-left-hl-mode string 387)
(defcap enter-low-hl-mode string 388)
(defcap enter-right-hl-mode string 389)
(defcap enter-top-hl-mode string 390)
(defcap enter-vertical-hl-mode string 391)
(defcap set-a-attributes string 392)
(defcap set-pglen-inch string 393)

;;#+INTERNAL-CAPS-VISIBLE
(progn
  (defcap termcap-init2 string 394)
  (defcap termcap-reset string 395)
  (defcap magic-cookie-glitch-ul integer 33)
  (defcap backspaces-with-bs boolean 37)
  (defcap crt-no-scrolling boolean 38)
  (defcap no-correctly-working-cr boolean 39)
  (defcap carriage-return-delay integer 34)
  (defcap new-line-delay integer 35)
  (defcap linefeed-if-not-lf string 396)
  (defcap backspace-if-not-bs string 397)
  (defcap gnu-has-meta-key boolean 40)
  (defcap linefeed-is-newline boolean 41)
  (defcap backspace-delay integer 36)
  (defcap horizontal-tab-delay integer 37)
  (defcap number-of-function-keys integer 38)
  (defcap other-non-function-keys string 398)
  (defcap arrow-key-map string 399)
  (defcap has-hardware-tabs boolean 42)
  (defcap return-does-clr-eol boolean 43)
  (defcap acs-ulcorner string 400)
  (defcap acs-llcorner string 401)
  (defcap acs-urcorner string 402)
  (defcap acs-lrcorner string 403)
  (defcap acs-ltee string 404)
  (defcap acs-rtee string 405)
  (defcap acs-btee string 406)
  (defcap acs-ttee string 407)
  (defcap acs-hline string 408)
  (defcap acs-vline string 409)
  (defcap acs-plus string 410)
  (defcap memory-lock string 411)
  (defcap memory-unlock string 412)
  (defcap box-chars-1 string 413))


(defun load-terminfo (name)
  (let ((name (concatenate 'string (list (char name 0) #\/) name)))
    (dolist (path (list* #+(or CMU SBCL) "home:.terminfo/"
			 #+Allegro "~/.terminfo/"
			 *terminfo-directories*))
      (with-open-file (stream (merge-pathnames name path)
			      :direction :input
			      :element-type '(unsigned-byte 8)
			      :if-does-not-exist nil)
	(when stream
	  (flet ((read-short (stream)
		   (let ((n (+ (read-byte stream) (* 256 (read-byte stream)))))
		     (if (> n 32767)
			 (- n 65536)
			 n)))
		 (read-string (stream)
		   (do ((c (read-byte stream) (read-byte stream))
			(s '()))
		       ((zerop c) (coerce (nreverse s) 'string))
		     (push (code-char c) s))))
	    (let* ((magic (read-short stream))
		   (sznames (read-short stream))
		   (szbooleans (read-short stream))
		   (sznumbers (read-short stream))
		   (szstrings (read-short stream))
		   (szstringtable (read-short stream))
		   (names (let ((string (read-string stream)))
			    (loop for i = 0 then (1+ j)
				    as j = (position #\| string :start i)
			       collect (subseq string i j) while j)))
		   (booleans (make-array szbooleans
					 :element-type '(or t nil)
					 :initial-element nil))
		   (numbers (make-array sznumbers
					:element-type '(signed-byte 16)
					:initial-element -1))
		   (strings (make-array szstrings
					:element-type '(signed-byte 16)
					:initial-element -1))
		   (stringtable (make-string szstringtable))
		   (count 0))
	      (unless (= magic #o432)
		(error "Invalid file format"))
	      (dotimes (i szbooleans)
		(setf (aref booleans i) (not (zerop (read-byte stream)))))
	      (when (oddp (+ sznames szbooleans))
		(read-byte stream))
	      (dotimes (i sznumbers)
		(setf (aref numbers i) (read-short stream)))
	      (dotimes (i szstrings)
		(unless (minusp (setf (aref strings i) (read-short stream)))
		  (incf count)))
	      (dotimes (i szstringtable)
		(setf (char stringtable i) (code-char (read-byte stream))))
	      (let ((xtrings (make-array szstrings :initial-element nil)))
		(dotimes (i szstrings)
		  (unless (minusp (aref strings i))
		    (setf (aref xtrings i)
			  (subseq stringtable (aref strings i)
				  (position #\Null stringtable
					    :start (aref strings i))))))
		(setq strings xtrings))
	      (return (make-terminfo :names names :booleans booleans
				     :numbers numbers :strings strings)))))))))

(defun tparm (string &rest args)
  (when (null string) (return-from tparm ""))
  (with-output-to-string (out)
    (with-input-from-string (in string)
      (do ((stack '()) (flags 0) (width 0) (precision 0) (number 0)
	   (dvars (make-array 26 :element-type '(unsigned-byte 8)
			      :initial-element 0))
	   (svars (load-time-value
		   (make-array 26 :element-type '(unsigned-byte 8)
			       :initial-element 0)))
	   (c (read-char in nil) (read-char in nil)))
	  ((null c))
	(cond ((char= c #\%)
	       (setq c (read-char in) flags 0 width 0 precision 0)
	       (tagbody
		state0
		  (case c
		    (#\% (princ c out) (go terminal))
		    (#\: (setq c (read-char in)) (go state2))
		    (#\+ (go state1))
		    (#\- (go state1))
		    (#\# (go state2))
		    (#\Space (go state2))
		    ((#\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9) (go state3))
		    (#\d (go state5))
		    (#\o (go state6))
		    ((#\X #\x) (go state7))
		    (#\s (go state8))
		    (#\c (princ (code-char (pop stack)) out) (go terminal))
		    (#\p (go state9))
		    (#\P (go state10))
		    (#\g (go state11))
		    (#\' (go state12))
		    (#\{ (go state13))
		    (#\l (push (length (pop stack)) stack) (go terminal))
		    (#\* (push (* (pop stack) (pop stack)) stack)
			 (go terminal))
		    (#\/ (push (/ (pop stack) (pop stack)) stack)
			 (go terminal))
		    (#\m (push (mod (pop stack) (pop stack)) stack)
			 (go terminal))
		    (#\& (push (logand (pop stack) (pop stack)) stack)
			 (go terminal))
		    (#\| (push (logior (pop stack) (pop stack)) stack)
			 (go terminal))
		    (#\^ (push (logxor (pop stack) (pop stack)) stack)
			 (go terminal))
		    (#\= (push (if (= (pop stack) (pop stack)) 1 0) stack)
			 (go terminal))
		    (#\> (push (if (> (pop stack) (pop stack)) 1 0) stack)
			 (go terminal))
		    (#\< (push (if (< (pop stack) (pop stack)) 1 0) stack)
			 (go terminal))
		    (#\A (push (if (and (pop stack) (pop stack)) 1 0) stack)
			 (go terminal))
		    (#\O (push (if (or (pop stack) (pop stack)) 1 0) stack)
			 (go terminal))
		    (#\! (push (if (zerop (pop stack)) 1 0) stack)
			 (go terminal))
		    (#\~ (push (logand #xFF (lognot (pop stack))) stack)
			 (go terminal))
		    (#\i (when args
			   (incf (first args))
			   (when (cdr args)
			     (incf (second args))))
			 (go terminal))
		    (#\? (go state14))
		    (otherwise (error "Unknown %-control character: ~C" c)))
		state1
		  (let ((next (peek-char nil in nil)))
		    (when (position next "0123456789# +-doXxs")
		      (go state2)))
		  (if (char= c #\+)
		      (push (+ (pop stack) (pop stack)) stack)
		      (push (- (pop stack) (pop stack)) stack))
		  (go terminal)
		state2
		  (case c
		    (#\# (setf flags (logior flags 1)))
		    (#\+ (setf flags (logior flags 2)))
		    (#\Space (setf flags (logior flags 4)))
		    (#\- (setf flags (logior flags 8)))
		    ((#\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9)
		     (go state3))
		    (t (go blah)))
		  (setf c (read-char in))
		  (go state2)
		state3
		  (setf width (digit-char-p c))
		state3-loop
		  (setf c (read-char in))
		  (case c
		    ((#\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9)
		     (setf width (+ (* width 10) (digit-char-p c)))
		     (go state3-loop))
		    (#\. (setf c (read-char in)) (go state4)))
		  (go blah)
		state4
		  (setf precision (digit-char-p c))
		state4-loop
		  (setf c (read-char in))
		  (case c
		    ((#\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9)
		     (setf precision (+ (* precision 10) (digit-char-p c)))
		     (go state4-loop)))
		  (go blah)
		blah
		  (case c
		    (#\d (go state5))
		    (#\o (go state6))
		    ((#\X #\x) (go state7))
		    (#\s (go state8))
		    (otherwise (error "Unknown %-control character: ~C" c)))
		state5
		  (let ((value (pop stack)))
		    (format out (if (logbitp 3 flags)
				    "~@v<~:[~*~;~C~]~v,'0D~>"
				    "~v<~:[~*~;~C~]~v,'0D~>")
			    width
			    (or (minusp value) (logbitp 1 flags)
				(logbitp 2 flags))
			    (if (minusp value)
				#\-
				(if (logbitp 1 flags)
				    #\+
				    #\Space))
			    precision
			    (abs value)))
		  (go terminal)
		state6
		  (format out (if (logbitp 3 flags)
				  "~@v<~@[0~*~]~v,'0O~>"
				  "~v<~@[0~*~]~v,'0O~>")
			  width (logbitp 0 flags) precision
			  (pop stack))
		  (go terminal)
		state7
		  (format out (if (logbitp 3 flags)
				  "~@v<~:[~*~;0~C~]~v,'0X~>"
				  "~v<~:[~*~;0~C~]~v,'0X~>")
			  width (logbitp 0 flags) c precision
			  (pop stack))
		  (go terminal)
		state8
		  (format t "~&;; Width ~D, Precision ~D, flags=#x~X: string"
			  width precision flags)
		  (go terminal)
		state9
		  (let* ((i (digit-char-p (read-char in)))
			 (a (nth (1- i) args)))
		    (etypecase a
		      (character (push (char-code a) stack))
		      (integer (push a stack))))
		  (go terminal)
		state10
		  (let ((var (read-char in)))
		    (cond ((char<= #\a var #\z)
			   (setf (aref dvars (- (char-code var)
						(char-code #\a)))
				 (pop stack)))
			  ((char<= #\A var #\Z)
			   (setf (aref svars (- (char-code var)
						(char-code #\A)))
				 (pop stack)))
			  (t (error "Illegal variable name: ~C" var))))
		  (go terminal)
		state11
		  (let ((var (read-char in)))
		    (cond ((char<= #\a var #\z)
			   (push (aref dvars (- (char-code var)
						(char-code #\a)))
				 stack))
			  ((char<= #\A var #\Z)
			   (push (aref svars (- (char-code var)
						(char-code #\A)))
				 stack))
			  (t (error "Illegal variable name: ~C" var))))
		  (go terminal)
		state12
		  (push (char-code (read-char in)) stack)
		  (unless (char= (read-char in) #\')
		    (error "Invalid character constant"))
		  (go terminal)
		state13
		  (setq number 0)
		state13-loop
		  (setq c (read-char in))
		  (let ((n (digit-char-p c)))
		    (cond (n (setq number (+ (* 10 number) n))
			     (go state13-loop))
			  ((char= c #\})
			   (push number stack)
			   (go terminal))))
		  (error "Invalid integer constant")
		state14
		  (error "Conditional expression parser not yet written.")

		terminal
		  #| that's all, folks |#))
	      (t (princ c out)))))))

(defun stream-fileno (stream)
  (typecase stream
    #+CMU
    (sys:fd-stream
     (sys:fd-stream-fd stream))
    (two-way-stream
     (stream-fileno (two-way-stream-output-stream stream)))
    (synonym-stream
     (stream-fileno (symbol-value (synonym-stream-symbol stream))))
    (echo-stream
     (stream-fileno (echo-stream-output-stream stream)))
    (broadcast-stream
     (stream-fileno (first (broadcast-stream-streams stream))))
    (otherwise nil)))

(defun stream-baud-rate (stream)
  #+CMU
  (alien:with-alien ((termios (alien:struct unix:termios)))
    (declare (optimize (ext:inhibit-warnings 3)))
    (when (unix:unix-tcgetattr (stream-fileno stream) termios)
      (let ((baud (logand unix:tty-cbaud
			  (alien:slot termios 'unix:c-cflag))))
	(if (< baud unix::tty-cbaudex)
	  (aref #(0 50 75 110 134 150 200 300 600 1200
		  1800 2400 4800 9600 19200 38400)
		baud)
	  (aref #(57600 115200 230400 460800 500000 576000
		  921600 1000000 1152000 1500000 2000000
		  2500000 3000000 3500000 4000000)
		(logxor baud unix::tty-cbaudex)))))))

(defun tputs (string &rest args)
  (when string
    (let* ((stream (if (streamp (first args)) (pop args) *terminal-io*))
	   (terminfo (if (terminfo-p (first args)) (pop args) *terminfo*)))
      (with-input-from-string (string (apply #'tparm string args))
	(do ((c (read-char string nil) (read-char string nil)))
	    ((null c))
	  (cond ((and (char= c #\$)
		      (eql (peek-char nil string nil) #\<))
		 (let ((time 0) (force nil) (rate nil) (pad #\Null))

		   ;; Find out how long to pad for:
		   (read-char string) ; eat the #\<
		   (loop
		     (setq c (read-char string))
		     (let ((n (digit-char-p c)))
		       (if n
			   (setq time (+ (* time 10) n))
			   (return))))
		   (if (char= c #\.)
		       (setq time (+ (* time 10)
				     (digit-char-p (read-char string)))
			     c (read-char string))
		       (setq time (* time 10)))
		   (when (char= c #\*)
		     ;; multiply time by "number of lines affected"
		     ;; but how do I know that??
		     (setq c (read-char string)))
		   (when (char= c #\/)
		     (setq force t c (read-char string)))
		   (unless (char= c #\>)
		     (error "Invalid padding specification."))

		   ;; Decide whether to apply padding:
		   (when (or force (not (capability :xon-xoff terminfo)))
		     (setq rate (stream-baud-rate stream))
		     (when (let ((pb (capability :padding-baud-rate terminfo)))
			     (and rate (or (null pb) (> rate pb))))
		       (cond ((capability :no-pad-char terminfo)
			      (finish-output stream)
			      (sleep (/ time 10000.0)))
			     (t
			      (let ((tmp (capability :pad-char terminfo)))
				(when tmp (setf pad (schar tmp 0))))
			      (dotimes (i (ceiling (* rate time) 100000))
				(princ pad stream))))))))

		(t
		 (princ c stream))))))
    t))

(defun set-terminal (&optional name)
  (setf *terminfo* (load-terminfo (or name
				      #+CMU
				      (cdr (assoc "TERM" ext:*environment-list*
						  :test #'string=))
				      #+Allegro
				      (sys:getenv "TERM")
				      #+SBCL
				      (sb-ext:posix-getenv "TERM")
				      #| if all else fails |#
				      "dumb"))))

;;(if (null *terminfo*)
;;    (set-terminal))

(provide :terminfo)
