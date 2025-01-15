;;; terraform.el --- library to interact with terraform CLI. -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Manas Jayanth

;; Author: Manas Jayanth <prometheansacrifice@gmail.com>
;; Created: 28 December 2024
;; Keywords: Terraform
;; Package-Requires: ((emacs "25.1") (transient "0.3.7.50"))
;; Package-Version: 20230415
;; Homepage: http://example.com/foo

;;; Commentary:


;;; Change Log: TODO

;;; Code:
(require 'transient)

(defun colorize-compilation-buffer ()
  (ansi-color-apply-on-region compilation-filter-start (point)))

(define-derived-mode terraform-cli-mode comint-mode "Terraform CLI"
  "Major mode for the Terraform compilation buffer."
  (setq major-mode 'terraform-cli-mode)
  (setq mode-name "Terraform CLI")
  (add-hook 'compilation-filter-hook 'colorize-compilation-buffer 0 t))

(defun run-cmd (buffer-name cmd-and-args callback)
  (add-hook 'terraform-cli-mode-hook 'compilation-shell-minor-mode)
  (let ((compilation-buffer
		 (compilation-start (string-join cmd-and-args " ") 'terraform-cli-mode)))
    (if (get-buffer buffer-name) nil (with-current-buffer compilation-buffer (rename-buffer buffer-name)))))

(defun run-terraform (args callback)
  "Runs terraform command in *terraform* buffer"
  (let ((command (if args (push terraform-command args) (list terraform-command))))
  (run-cmd
   "*terraform*"
   command
   (lambda ()
     (with-current-buffer
	 "*terraform*"
       ;; TODO compilation matchers
       )))))

(defun propertized-flag (flag-value)
  "Given a boolean value, it turns into a human readable 'yes' | 'no' with appropriate faces"
  (propertize (if flag-value "yes" "no") 'face (if flag-value '(:foreground "green") '(:foreground "red"))))

(defun terraform-status ()
  "Show status (parsed from 'terraform status') of the current buffer"
  (interactive)
  (terraform/macro--with-terraform-project
   (current-buffer)
   project
   (let* ((terraform-status (plist-get project 'json))
	  (manifest (terraform/status--get-manifest-file-path terraform-status))
	  (manifest-propertized (propertize manifest 'face 'bold))
	  (is-project-propertized (propertized-flag (terraform/status--project-p terraform-status)))
	  (is-solved-propertized (propertized-flag (terraform/status--dependency-constraints-solved-p terraform-status)))
	  (is-fetched-propertized (propertized-flag (terraform/status--dependencies-installed-p terraform-status)))
	  (is-ready-for-dev-propertized (propertized-flag (terraform/status--ready-for-dev-p terraform-status))))
     (message
      "manifest: %s valid-project: %s solved: %s dependencies-fetched: %s ready-for-dev: %s"
      manifest-propertized is-project-propertized is-solved-propertized is-fetched-propertized is-ready-for-dev-propertized))))

(defun terraform/cmd-apply (&optional args)
  "Run terraform install"
  (interactive (list (transient-args 'terraform-apply)))
  (run-terraform (append '("apply") args) (lambda () (message "[terraform] Applied"))))

(defun terraform/cmd-destroy (&optional args)
  "Run terraform destroy"
  (interactive (list (transient-args 'terraform-destroy)))
  (run-terraform (append '("destroy") args) (lambda () (message "[terraform] Destroyed"))))

(defun terraform/cmd-init ()
  "Run terraform"
  (interactive)
  (run-terraform (append '("init") args) (lambda () (message "[terraform] Initialised"))))

(transient-define-prefix terraform-apply ()
  "Open terraform apply transient menu pop up."
    ["Arguments"
     ("-y" "Auto approve" "-auto-approve")
    ]
    [["Command"
      ("a" "Apply"       terraform/cmd-apply)]])

(transient-define-prefix terraform-destroy ()
  "Open terraform destroy transient menu pop up."
    ["Arguments"
     ("-y" "Auto approve" "-auto-approve")
    ]
    [["Command"
      ("d" "Destroy"       terraform/cmd-destroy)]])

(transient-define-prefix terraform-init ()
  "Open terraform init transient menu pop up."
    [["Command"
      ("i" "Initialise"       )]])

;; Entrypoint menu
(transient-define-prefix terraform-menu ()
  "Open terraform transient menu pop up."
    [["Command"
      ("i" "Init"        terraform/cmd-init)
      ("a" "Apply"       terraform-apply)
      ("d" "Destroy"     terraform-destroy)
    ]])

;;;###autoload
(defun terraform ()
  "Entrypoint function to the terraform-mode interactive functions
First checks if file backing the current buffer is a part of an terraform project, then opens the menu. Else, recommends initialising a new project"
  (interactive)
  (call-interactively #'terraform-menu))

(provide 'terraform)
