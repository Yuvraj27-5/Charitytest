(define-data-var owner principal tx-sender)
(define-data-var last-completed-migration uint u0)

(define-private (is-owner (caller principal))
  (is-eq caller (var-get owner))
)

(define-public (set-completed (completed uint))
  (begin
    (if (is-owner tx-sender)
        (begin
          (var-set last-completed-migration completed)
          (ok completed)
        )
        (err u403) ;; Unauthorized
    )
  )
)