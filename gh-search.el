;;; gh-search.el --- repository search for gh.el
;; Copyright (C) 2016  Ivan Malison

;; Author: Ivan Malison <IvanMalison@gmail.com>

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

;;

;;; Code:

(require 'gh-repos)

(defclass gh-search-api (gh-api-v3)
  ((repo-cls :allocation :class :initform gh-repos-repo))
  "Users API")

(defmethod gh-search-repos ((search-api gh-search-api) query-string)
  (gh-api-authenticated-request
   search-api
   (apply-partially 'gh-process-repo-search-result search-api)
   "GET" "/search/repositories" nil `((q . ,query-string))))

(defmethod gh-process-repo-search-result ((search-api gh-search-api) data)
  (gh-object-list-read (oref search-api repo-cls) (cdar data)))

(provide 'gh-search)
;;; gh-search.el ends here
