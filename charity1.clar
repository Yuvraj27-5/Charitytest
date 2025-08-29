(define-constant GOVERNMENT principal 'ST...GOVERNMENT-ADDRESS)

;; State storage
(define-map static-entities { uid: uint } { name: (string-ascii 64), bank: uint, validity: bool })
(define-map entities { aadhaar: uint } { name: (string-ascii 64), bank: uint, validity: bool })
(define-map schemes { sid: uint } 
  { name: (string-ascii 64)
    , description: (string-ascii 256)
    , total-amount: uint
    , bank: uint
    , superuser: principal
    , validity: bool
    , locked: bool
  })

;; Use separate maps to simulate nested mappings
(define-map scheme-authorized { sid: uint, uid: uint } { allocated: uint, money-received: uint, money-present: uint, benefits-given: bool })
(define-map total-money { uid: uint } { amount: uint })

;; Example: Add a static entity
(define-public (add-static-entity (uid uint) (name (string-ascii 64)) (bank uint))
  (asserts! (not (get validity (map-get? static-entities {uid: uid}))) (err "Already exists"))
  (map-insert static-entities { uid: uid } { name: name, bank: bank, validity: true })
  (ok "Entity Added"))

;; Example: Add a scheme (restricted to government)
(define-public (add-scheme (sid uint) (name (string-ascii 64)) (desc (string-ascii 256)) (amt uint) (bank uint) (superuser principal))
  (asserts! (is-eq tx-sender GOVERNMENT) (err "Unauthorized"))
  (asserts! (not (get validity (map-get? schemes {sid: sid}))) (err "Scheme exists"))
  (map-insert schemes { sid: sid } { name: name, description: desc, total-amount: amt, bank: bank, superuser: superuser, validity: true, locked: false })
  (ok "Scheme Created"))

;; Example: Add authorized person/company (no loops!)
(define-public (add-authorized (sid uint) (uid uint) (alloc uint))
  (let ((scheme (try! (map-get? schemes { sid: sid }))))
    (asserts! (get validity scheme) (err "Invalid scheme"))
    (asserts! (is-eq (get superuser scheme) tx-sender) (err "Not superuser"))
    (asserts! (not (get allocated (map-get? scheme-authorized { sid: sid, uid: uid }))) (err "Already authorized"))
    (map-insert scheme-authorized { sid: sid, uid: uid } { allocated: alloc, money-received: u0, money-present: u0, benefits-given: false })
    (ok "Authorized Added")))

;; Example: Lock scheme
(define-public (lock-scheme (sid uint))
  (let ((scheme (try! (map-get? schemes { sid: sid }))))
    (asserts! (is-eq (get superuser scheme) tx-sender) (err "Unauthorized"))
    (map-set schemes { sid: sid } (tuple (name (get name scheme))
                                        (description (get description scheme))
                                        (total-amount (get total-amount scheme))
                                        (bank (get bank scheme))
                                        (superuser (get superuser scheme))
                                        (validity true)
                                        (locked true)))
    (ok "Locked")))

;; Example: Transfer money
(define-public (transfer-money (sid uint) (from uint) (to uint) (amount uint))
  (let
    ((scheme (try! (map-get? schemes { sid: sid })))
     (auth-from (try! (map-get? scheme-authorized { sid: sid, uid: from })))
     (auth-to (try! (map-get? scheme-authorized { sid: sid, uid: to })))
     (tot-from (try! (map-get? total-money { uid: from })))
     (tot-to (or (map-get? total-money { uid: to }) { amount: u0 })))
    (asserts! (get validity scheme) (err "Invalid scheme"))
    (asserts! (get allocated auth-to) (err "Recipient not authorized"))
    ;; Arithmetic handled by Clarity—overflow aborts
    (map-set scheme-authorized { sid: sid, uid: from }
             (tuple (allocated (get allocated auth-from))
                    (money-received (get money-received auth-from))
                    (money-present (get money-present auth-from))
                    (benefits-given (get benefits-given auth-from))))
    (map-set scheme-authorized { sid: sid, uid: to }
             (tuple (allocated (get allocated auth-to))
                    (money-received amount)
                    (money-present (+ (get money-present auth-to) amount))
                    (benefits-given true)))
    (map-set total-money { uid: from } { amount: (- (get amount tot-from) amount) })
    (map-set total-money { uid: to } { amount: (+ (get amount tot-to) amount) })
    (ok "Transferred")))