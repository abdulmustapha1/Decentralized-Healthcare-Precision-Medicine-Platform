;; Provider Verification Contract
;; Validates healthcare entities and their credentials

(define-data-var admin principal tx-sender)

;; Provider status: 0 = unverified, 1 = verified, 2 = suspended
(define-map providers
  { provider-id: principal }
  {
    name: (string-utf8 100),
    specialty: (string-utf8 100),
    license-number: (string-utf8 50),
    status: uint,
    verification-date: uint
  }
)

;; Only allow admin to perform certain actions
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Register a new provider (self-registration)
(define-public (register-provider (name (string-utf8 100)) (specialty (string-utf8 100)) (license-number (string-utf8 50)))
  (begin
    (asserts! (not (is-some (map-get? providers {provider-id: tx-sender}))) (err u1)) ;; Provider already exists
    (ok (map-set providers
      {provider-id: tx-sender}
      {
        name: name,
        specialty: specialty,
        license-number: license-number,
        status: u0, ;; Initially unverified
        verification-date: u0
      }
    ))
  )
)

;; Verify a provider (admin only)
(define-public (verify-provider (provider-id principal))
  (begin
    (asserts! (is-admin) (err u403)) ;; Unauthorized
    (asserts! (is-some (map-get? providers {provider-id: provider-id})) (err u404)) ;; Provider not found
    (ok (map-set providers
      {provider-id: provider-id}
      (merge (unwrap-panic (map-get? providers {provider-id: provider-id}))
        {
          status: u1, ;; Set to verified
          verification-date: block-height
        }
      )
    ))
  )
)

;; Suspend a provider (admin only)
(define-public (suspend-provider (provider-id principal))
  (begin
    (asserts! (is-admin) (err u403)) ;; Unauthorized
    (asserts! (is-some (map-get? providers {provider-id: provider-id})) (err u404)) ;; Provider not found
    (ok (map-set providers
      {provider-id: provider-id}
      (merge (unwrap-panic (map-get? providers {provider-id: provider-id}))
        {
          status: u2 ;; Set to suspended
        }
      )
    ))
  )
)

;; Check if a provider is verified
(define-read-only (is-verified-provider (provider-id principal))
  (match (map-get? providers {provider-id: provider-id})
    provider (is-eq (get status provider) u1)
    false
  )
)

;; Get provider details
(define-read-only (get-provider-details (provider-id principal))
  (map-get? providers {provider-id: provider-id})
)

;; Transfer admin rights (admin only)
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err u403)) ;; Unauthorized
    (ok (var-set admin new-admin))
  )
)
