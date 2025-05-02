;; Digital Manager Contract


;; ==========================================
;; ERROR CODE DECLARATIONS
;; ==========================================
;; Standardized response codes for error situations
(define-constant ENTRY-MISSING (err u404))
(define-constant ENTRY-ALREADY-EXISTS (err u409))
(define-constant ENTRY-DATA-MALFORMED (err u400))

;; ==========================================
;; DATA STORAGE DEFINITIONS
;; ==========================================
;; Repository for task importance classifications
;; Enables sorting and filtering by significance level
(define-map task-importance
    principal
    {
        importance-rating: uint
    }
)

;; Repository for task time constraints
;; Tracks when tasks should be completed by
(define-map task-time-limits
    principal
    {
        target-block: uint,
        notification-status: bool
    }
)

;; Primary repository for task information
;; Associates blockchain identities with their task details
(define-map task-repository
    principal
    {
        task-content: (string-ascii 100),
        is-completed: bool
    }
)

;; ==========================================
;; TASK CREATION FUNCTIONS
;; ==========================================
;; Public function enabling users to create a new task entry
(define-public (create-task 
    (task-content (string-ascii 100)))
    (let
        (
            (identity tx-sender)
            (existing-entry (map-get? task-repository identity))
        )
        (if (is-none existing-entry)
            (begin
                (if (is-eq task-content "")
                    (err ENTRY-DATA-MALFORMED)
                    (begin
                        (map-set task-repository identity
                            {
                                task-content: task-content,
                                is-completed: false
                            }
                        )
                        (ok "Task successfully created in repository.")
                    )
                )
            )
            (err ENTRY-ALREADY-EXISTS)
        )
    )
)

;; ==========================================
;; TASK MODIFICATION FUNCTIONS
;; ==========================================
;; Public function allowing users to update their existing task
(define-public (update-task
    (task-content (string-ascii 100))
    (is-completed bool))
    (let
        (
            (identity tx-sender)
            (existing-entry (map-get? task-repository identity))
        )
        (if (is-some existing-entry)
            (begin
                (if (is-eq task-content "")
                    (err ENTRY-DATA-MALFORMED)
                    (begin
                        (if (or (is-eq is-completed true) (is-eq is-completed false))
                            (begin
                                (map-set task-repository identity
                                    {
                                        task-content: task-content,
                                        is-completed: is-completed
                                    }
                                )
                                (ok "Task successfully updated in repository.")
                            )
                            (err ENTRY-DATA-MALFORMED)
                        )
                    )
                )
            )
            (err ENTRY-MISSING)
        )
    )
)

;; Public function enabling users to delete their task
(define-public (delete-task)
    (let
        (
            (identity tx-sender)
            (existing-entry (map-get? task-repository identity))
        )
        (if (is-some existing-entry)
            (begin
                (map-delete task-repository identity)
                (ok "Task successfully removed from repository.")
            )
            (err ENTRY-MISSING)
        )
    )
)

;; ==========================================
;; TASK QUERY FUNCTIONS
;; ==========================================
;; Read-only function to retrieve comprehensive task information
(define-read-only (fetch-task-information (identity principal))
    (match (map-get? task-repository identity)
        entry (ok {
            task-content: (get task-content entry),
            is-completed: (get is-completed entry)
        })
        ENTRY-MISSING
    )
)

;; Specialized function to check only completion status
(define-read-only (check-task-completion (identity principal))
    (match (map-get? task-repository identity)
        entry (ok (get is-completed entry))
        ENTRY-MISSING
    )
)

;; Public function for validation before operations
;; Allows clients to verify task existence without modifying state
(define-public (verify-task-validity)
    (let
        (
            (identity tx-sender)
            (existing-entry (map-get? task-repository identity))
        )
        (if (is-some existing-entry)
            (let
                (
                    (current-entry (unwrap! existing-entry ENTRY-MISSING))
                    (task-detail (get task-content current-entry))
                    (completion-flag (get is-completed current-entry))
                )
                (ok {
                    exists: true,
                    content-size: (len task-detail),
                    finished-state: completion-flag
                })
            )
            (ok {
                exists: false,
                content-size: u0,
                finished-state: false
            })
        )
    )
)

;; ==========================================
;; TASK MANAGEMENT EXTENSIONS
;; ==========================================
;; Public function to establish task time constraints
;; Sets a specific blockchain height target for completion
(define-public (set-task-deadline (blocks-remaining uint))
    (let
        (
            (identity tx-sender)
            (existing-entry (map-get? task-repository identity))
            (completion-target (+ block-height blocks-remaining))
        )
        (if (is-some existing-entry)
            (if (> blocks-remaining u0)
                (begin
                    (map-set task-time-limits identity
                        {
                            target-block: completion-target,
                            notification-status: false
                        }
                    )
                    (ok "Task deadline successfully established.")
                )
                (err ENTRY-DATA-MALFORMED)
            )
            (err ENTRY-MISSING)
        )
    )
)

;; Public function to classify task importance
;; Supports three-tier priority system (1=low, 2=medium, 3=high)
(define-public (set-task-importance (importance-level uint))
    (let
        (
            (identity tx-sender)
            (existing-entry (map-get? task-repository identity))
        )
        (if (is-some existing-entry)
            (if (and (>= importance-level u1) (<= importance-level u3))
                (begin
                    (map-set task-importance identity
                        {
                            importance-rating: importance-level
                        }
                    )
                    (ok "Task importance level successfully updated.")
                )
                (err ENTRY-DATA-MALFORMED)
            )
            (err ENTRY-MISSING)
        )
    )
)

;; ==========================================
;; COLLABORATION FUNCTIONS
;; ==========================================
;; Public function enabling task delegation to other users
;; Allows authorized users to create tasks for others
(define-public (delegate-task
    (target-identity principal)
    (task-content (string-ascii 100)))
    (let
        (
            (existing-entry (map-get? task-repository target-identity))
        )
        (if (is-none existing-entry)
            (begin
                (if (is-eq task-content "")
                    (err ENTRY-DATA-MALFORMED)
                    (begin
                        (map-set task-repository target-identity
                            {
                                task-content: task-content,
                                is-completed: false
                            }
                        )
                        (ok "Task successfully delegated to recipient.")
                    )
                )
            )
            (err ENTRY-ALREADY-EXISTS)
        )
    )
)

