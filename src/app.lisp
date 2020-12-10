(defpackage #:github-webhook/app
  (:use #:cl
        #:github-webhook/signature
        #:lack.request)
  (:import-from #:github-webhook/handler
                #:make-hooks-handler)
  (:import-from #:babel
                #:string-to-octets
                #:octets-to-string)
  (:import-from #:yason
                #:parse)
  (:export #:make-app))
(in-package #:github-webhook/app)

(define-condition invalid-request (error) ())

(defun check-request (req)
  (let* ((headers (request-headers req))
         (content-type (gethash "content-type" headers))
         (event (gethash "x-github-event" headers)))
    (unless (and (eql (search "application/json" content-type) 0)
                 event)
      (error 'invalid-request))))

(defun main (handler event action payload content)
  (check-type handler function)
  (check-type event string)
  (check-type action string)
  (check-type payload hash-table)
  (check-type content string)
  (funcall handler
           event
           action
           payload
           content))

(defun make-app (&key hooks-dir secret exit-on-failure)
  (check-type hooks-dir pathname)
  (check-type secret (or null string))
  (let ((secret (and secret
                     (string-to-octets secret)))
        (handler (make-hooks-handler hooks-dir
                                     :exit-on-failure exit-on-failure)))
    (lambda (env)
      (block app
        (let ((req (make-request env)))
          ;; Accept only POST requests
          (unless (eq (request-method req) :post)
            (return-from app '(404 () ("Not Found"))))

          (handler-case
              (let ((headers (request-headers req))
                    (content (request-content req)))
                (when secret
                  (check-signature secret headers content))
                (check-request req)
                (let* ((event (gethash "x-github-event" (request-headers req)))
                       (payload (handler-case
                                    (yason:parse (octets-to-string content))
                                  (error () (error 'invalid-request))))
                       (action (gethash "action" payload)))
                  (main handler event action payload content))
                '(200 () ("OK")))
            (invalid-signature ()
              '(403 () ("Invalid signature")))
            (invalid-request ()
              '(400 () ("Invalid request")))))))))
