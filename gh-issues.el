;;; gh-issues.el --- issues api for github

;; Copyright (C) 2012  Raimon Grau

;; Author: Raimon Grau <raimonster@gmail.com>
;; Keywords:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Basic usage:

;; (setf api (gh-issues-api "api" :sync nil :cache nil :num-retries 1))
;; (setf issues (gh-issues-list api "user" "repo"))
;; (last (oref issues data)) ; get one issue
;; (setq mi (make-instance 'gh-issues-issue :body "issue body" :title "issue title" ))
;; (gh-issues-issue-new api "user" "repo" mi)

;;; Code:

(eval-when-compile
  (require 'cl))

;;;###autoload
(require 'eieio)

(require 'gh-api)
(require 'gh-auth)
(require 'gh-common)

(require 'gh-repos)

(defclass gh-issues-api (gh-api-v3)
  ((req-cls :allocation :class :initform gh-issues-issue)
   (milestone-cls :allocation :class :initform gh-issues-milestone))
  "Github Issues api")

(defclass gh-issues-issue (gh-object)
  ((url :initarg :url)
   (html-url :initarg :html-url)
   (number :initarg :number)
   (state :initarg :state)
   (title :initarg :title)
   (body :initarg :body)
   (user :initarg :user :initform nil)
   (labels :initarg :labels :initform nil)
   (assignee :initarg :assignee :initform nil)
   (milestone :initarg :milestone :initform nil)
   (open_issues :initarg :open_issues)
   (closed_issues :initarg :closed_issues)
   (created_at :initarg :created_at)
   (due_on :initarg :due_on)

   (user-cls :allocation :class :initform gh-user)
   (milestone-cls :allocation :class :initform gh-issues-milestone))
  "issues request")

(defclass gh-issues-label (gh-object)
  ((url :initarg :url)
   (name :initarg :name)
   (color :initarg :color)))

(defclass gh-issues-milestone (gh-object)
  ((url :initarg :url)
   (number :initarg :number)
   (state :initarg :state)
   (title :initarg :title)
   (description :initarg :description)
   (creator :initarg :creator :initform nil)
   (open_issues :initarg :open_issues)
   (closed_issues :initarg :closed_issues)
   (created_at :initarg :created_at)
   (due_on :initarg :due_on)

   (user-cls :allocation :class :initform gh-user))
  "github milestone")

(defmethod gh-object-read-into ((issue gh-issues-issue) data)
  (call-next-method)
  (with-slots (url html-url number state title body
                   user labels assignee milestone open_issues
                   closed_issues created_at due_on)
      issue
    (setq url (gh-read data 'url)
          html-url (gh-read data 'html-url)
          number (gh-read data 'number)
          state (gh-read data 'state)
          title (gh-read data 'title)
          body (gh-read data 'body)
          user (gh-object-read  (or
                                 (oref issue :user)
                                 (oref issue user-cls))
                                (gh-read data 'user))
          labels (gh-read data 'labels)
          assignee (gh-object-read  (or
                                     (oref issue :assignee)
                                     (oref issue user-cls))
                                    (gh-read data 'assignee))
          milestone (gh-object-read (or
                                     (oref issue :milestone)
                                     (oref issue milestone-cls))
                                    (gh-read data 'milestone))
          open_issues (gh-read data 'open_issues)
          closed_issues (gh-read data 'closed_issues)
          created_at (gh-read data 'created_at)
          due_on (gh-read data 'due_on))))


(defmethod gh-object-read-into ((milestone gh-issues-milestone) data)
  (call-next-method)
  (with-slots (url number state title description creator
                   open_issues closed_issues
                   created_at due_on)
      milestone
    (setq url (gh-read data 'url)
          number (gh-read data 'number)
          state (gh-read data 'state)
          title (gh-read data 'title)
          description (gh-read data 'description)
          creator (gh-object-read (or
                                 (oref milestone :creator)
                                 (oref milestone user-cls))
                                (gh-read data 'creator))

          open_issues (gh-read data 'open_issues)
          closed_issues (gh-read data 'closed_issues)
          created_at (gh-read data 'created_at)
          due_on (gh-read data 'due_on))))

(defmethod gh-issues-issue-list ((api gh-issues-api) user repo)
  (gh-api-authenticated-request
   api (gh-object-list-reader (oref api req-cls)) "GET"
   (format "/repos/%s/%s/issues" user repo)))

(defmethod gh-issues-milestone-list ((api gh-issues-api) user repo)
  (gh-api-authenticated-request
   api (gh-object-list-reader (oref api milestone-cls)) "GET"
   (format "/repos/%s/%s/milestones" user repo)))

(defmethod gh-issues-issue-get ((api gh-issues-api) user repo id)
  (gh-authenticated-request
   api (gh-object-reader (oref api req-cls)) "GET"
   (format "/repos/%s/%s/issues/%s" user repo id)))

(defmethod gh-issues-issue-req-to-update ((req gh-issues-issue))
  (let ((assignee (oref req assignee))
        ;; (labels (oref req labels))
        (milestone (oref req milestone))
        (to-update `(("title" . ,(oref req title))
                     ("state" . ,(oref req state))
                     ("body" . ,(oref req body)))))

    ;; (when labels (nconc to-update `(("labels" . ,(oref req labels) ))))
    (when milestone (nconc to-update `(("milestone" . ,(oref milestone number)))))
    (when assignee (nconc to-update `(("assignee" . ,(oref assignee login) ))))
    to-update))

(defmethod gh-issues-issue-update ((api gh-issues-api) user repo id req)
  (gh-api-authenticated-request
   api (gh-object-reader (oref api req-cls)) "PATCH"
   (format "/repos/%s/%s/issues/%s" user repo id)
   (gh-issues-issue-req-to-update req)))

(defmethod gh-issues-issue-new ((api gh-issues-api) user repo issue)
  (gh-api-authenticated-request
   api (gh-object-reader (oref api req-cls)) "POST"
   (format "/repos/%s/%s/issues" user repo)
   (gh-issues-issue-req-to-update issue)))

(provide 'gh-issues)
;;; gh-issues.el ends here
