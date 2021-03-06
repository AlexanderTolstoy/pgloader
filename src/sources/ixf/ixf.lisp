;;;
;;; Tools to handle IBM PC version of IXF file format
;;;
;;; http://www-01.ibm.com/support/knowledgecenter/SSEPGG_10.5.0/com.ibm.db2.luw.admin.dm.doc/doc/r0004667.html

(in-package :pgloader.source.ixf)

;;;
;;; Integration with pgloader
;;;
(defclass copy-ixf (db-copy)
  ((timezone    :accessor timezone	  ; timezone
	        :initarg :timezone
                :initform local-time:+utc-zone+))
  (:documentation "pgloader IXF Data Source"))

(defmethod initialize-instance :after ((source copy-ixf) &key)
  "Add a default value for transforms in case it's not been provided."
  (setf (slot-value source 'source)
        (let ((table-name (pathname-name (fd-path (source-db source)))))
          (make-table :source-name table-name
                      :name (apply-identifier-case table-name))))

  ;; force default timezone when nil
  (when (null (timezone source))
    (setf (timezone source) local-time:+utc-zone+)))

(defmethod map-rows ((copy-ixf copy-ixf) &key process-row-fn)
  "Extract IXF data and call PROCESS-ROW-FN function with a single
   argument (a list of column values) for each row."
  (let ((local-time:*default-timezone* (timezone copy-ixf)))
    (log-message :notice "Parsing IXF with TimeZone: ~a"
                 (local-time::timezone-name local-time:*default-timezone*))
    (with-connection (conn (source-db copy-ixf))
      (let ((ixf    (ixf:make-ixf-file :stream (conn-handle conn))))
        (ixf:read-headers ixf)
        (ixf:map-data ixf process-row-fn)))))

(defmethod instanciate-table-copy-object ((ixf copy-ixf) (table table))
  "Create an new instance for copying TABLE data."
  (let ((new-instance (change-class (call-next-method ixf table) 'copy-ixf)))
    (setf (timezone new-instance) (timezone ixf))
    new-instance))

(defmethod fetch-metadata ((ixf copy-ixf) (catalog catalog)
                           &key
                             materialize-views
                             only-tables
                             create-indexes
                             foreign-keys
                             including
                             excluding)
  "Collect IXF metadata and prepare our catalog from that."
  (declare (ignore materialize-views only-tables create-indexes foreign-keys
                   including excluding))
  (let* ((table  (or (target ixf) (source ixf)))
         (schema (add-schema catalog (table-name table))))
    (push-to-end table (schema-table-list schema))

    (with-connection (conn (source-db ixf))
      (list-all-columns (conn-handle conn) table))

    catalog))


