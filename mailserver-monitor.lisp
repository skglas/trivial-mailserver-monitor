;; Copyright (c) 2022 Sebastian Glas

;; This software is provided 'as-is', without any express or implied
;; warranty. In no event will the authors be held liable for any damages
;; arising from the use of this software.

;; Permission is granted to anyone to use this software for any purpose,
;; including commercial applications, and to alter it and redistribute it
;; freely, subject to the following restrictions:

;; 1. The origin of this software must not be misrepresented; you must not
;;    claim that you wrote the original software. If you use this software
;;    in a product, an acknowledgment in the product documentation would be
;;    appreciated but is not required.
;; 2. Altered source versions must be plainly marked as such, and must not be
;;    misrepresented as being the original software.
;; 3. This notice may not be removed or altered from any source distribution.

;; --------------------------------------------------------------------------
;; simple mail server monitoring loop
;; Assumptions: you have 3 e-mail accounts:
;;  the robot (used to monitor) and the destination mail server mailbox
;;  (mail server to be monitored).
;;  The destination mail server mailbox is configured as a forwarder and
;;  returns all incoming e-mail to the robot mail account.
;;
;;  A third e-mail account is your personal notification e-mail address
;;  if the monitoring fails. 
;;
;; Every x (e.g. 15) minutes, the program uses the robot mail account to send
;;  and e-mail with a hash value to the destination mail server mailbox.
;; A monitoring success is defined as a returned e-mail within 10 minutes.
;; A monitoring failure is defined as a situation where the mail with the hash 
;; is not returned within that time. 
;; The interpreation is that the destination mail server is in a state
;; where it has not received the mail and/or not sent back the monitoring mail.
;; In case of a monitoring failure, the admin is notified.
;;
;; e-Mail sending is performed in Lisp through cl-smtp.
;; e-Mail receiving via Pop3 is facilitated via mpop.
;;  mpop must be configured in a way to save e-mails to ~/mpop-in/new 

(let ((quicklisp-init (merge-pathnames
                       "/Users/user/bin/sbcl-1.32/quicklisp/setup.lisp"
                       (user-homedir-pathname))))
  (when (probe-file quicklisp-init)
    (load quicklisp-init)))

(ql:quickload :cl-ppcre)
(ql:quickload :local-time)
(ql:quickload :cl-smtp)
(ql:quickload :ironclad)
(ql:quickload :trivial-timeout)
(ql:quickload :cl-fad)
(ql:quickload :alexandria)

(defun timestamp ()
  (subseq (local-time:format-timestring nil (local-time:now )) 0 19))

(defun make-check-string (instring)
  "Calculate and return sha256 hash based in instring
   returns e.g. ''6737fb3707d3959f7018acabd14bd21e7934a787e9b94c0bf6b9531c21652ca7'' "
  (let ((digester (ironclad:make-digest :sha256)))
    (ironclad:byte-array-to-hex-string
     (ironclad:digest-sequence digester
			       (flexi-streams:string-to-octets instring)))))

(defun send-monitoring-msg ()
   (let* ((msg-id (format nil "~A~A~A~A" (random 500) (random 500) (random 500) (random 500)))
	  (hash (make-check-string msg-id)))
     (format *terminal-io* "~A Sending Monitoring mail (hash=~A)~%" (timestamp) hash)
      (cl-smtp:send-email "smtp.yourisp.example" "monitoring-robot@yourisp.example" "your-responder@host-to-be-monitored.example"
			  hash (format nil "Monitoring as of ~A." (timestamp)) :ssl t
						:authentication '("username" "password")
						:local-hostname "system")
     hash))

(defun notify-admin ()
  (cl-smtp:send-email "smtp.yourisp.example"
		      "monitoring-robot@yourisp.example"
		      "your-admin-mailaddress@yourisp.example"
		      "Mail Server Monitoring failed!"
		      (format nil "Monitoring as of ~A." (timestamp))
		      :ssl t
		      :authentication '("username" "password")
		      :local-hostname "system"))

(defun try-to-find-mail-response (hash)
  "In this current implementation, use mpop on linux, as cl-pop does not support tls. 
   Go through all mails in the new mail directory and parse each one for the hash."
  (let ((result nil))
    (handler-case
	(trivial-timeout:with-timeout (60)
	  (format *terminal-io* "~A Trying to fetch mails...~%" (timestamp) )
	  (uiop:run-program "mpop"))
      (trivial-timeout:timeout-error (c)
	(format *terminal-io* "Timeout 60sec. exceeded during mpop action (~a).~%" c)))
    
    (dolist (mail-file (cl-fad:list-directory "~/mpop-in/new"))
      (dolist (line (cl-ppcre:split "\\n" (alexandria:read-file-into-string mail-file)))
	(when (cl-ppcre:scan-to-strings "^Subject:" line)
	  (when (string= hash (second (cl-ppcre:split " " line)))
	    (progn (format *terminal-io* "Hash ~A found in mail ~A.~%Monitoring success. Deleting mail file link.~%" hash mail-file)
		   (delete-file mail-file)
		   (setf result 1))))))
    result))
	      
    
(defun monitoring-loop (interval-min)
  (format *terminal-io* "~A Monitoring program started.~%" (timestamp))
  (loop
    (format *terminal-io* "~A Monitoring loop started.~%" (timestamp))
    (let* ( (hash (send-monitoring-msg))
	    (i 0)
	    (result nil))
      (loop 
	    while (and (not result)
		       (< i 10))
	    do (progn (sleep 60) ; every minute, we check for a returned mail.
		      (if (try-to-find-mail-response hash)
			  (setf result 1)
					;else
			  (format *terminal-io* "Mail not yet returned. Try # ~A~%" i))
		      (incf i)))
      (if result (format *terminal-io* "~A e-Mail returned within 10 minutes. Success.~%" (timestamp))
					; else
	  (progn 
	    (format *terminal-io* "~A Notification condition. E-Mail not returned within 10m." (timestamp))
	    (notify-admin))))
    (format *terminal-io* "~A Monitoring Pause. Sleeping for ~A minutes.~%" (timestamp) interval-min)
    (sleep (* 60 interval-min))))
      
		      
		      




    
