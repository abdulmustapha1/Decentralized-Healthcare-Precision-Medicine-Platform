;; Patient Identity Contract
;; Securely manages participant profiles and consent

(define-data-var admin principal tx-sender)

;; Patient profiles with privacy controls
(define-map patients
  { patient-id: principal }
  {
    name-hash: (buff 32), ;; Hash of patient name for privacy
    birth-year: uint,
    consent-version: uint,
    data-sharing-preferences: uint,
    last-updated: uint
  }
)

;; Authorized providers for each patient
(define-map patient-provider-authorizations
  { patient-id: principal, provider-id: principal }
  {
    authorized: bool,
    access-level: uint, ;; 1 = basic, 2 = full, 3 = full + genomic
    expiration-height: uint
  }
)

;; Only allow admin to perform certain actions
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Register a new patient (self-registration)
(define-public (register-patient (name-hash (buff 32)) (birth-year uint) (data-sharing-preferences uint))
  (begin
    (asserts! (not (is-some (map-get? patients {patient-id: tx-sender}))) (err u1)) ;; Patient already exists
    (ok (map-set patients
      {patient-id: tx-sender}
      {
        name-hash: name-hash,
        birth-year: birth-year,
        consent-version: u1,
        data-sharing-preferences: data-sharing-preferences,
        last-updated: block-height
      }
    ))
  )
)

;; Update patient profile (patient only)
(define-public (update-patient-profile (name-hash (buff 32)) (birth-year uint) (data-sharing-preferences uint))
  (begin
    (asserts! (is-some (map-get? patients {patient-id: tx-sender})) (err u404)) ;; Patient not found
    (ok (map-set patients
      {patient-id: tx-sender}
      (merge (unwrap-panic (map-get? patients {patient-id: tx-sender}))
        {
          name-hash: name-hash,
          birth-year: birth-year,
          data-sharing-preferences: data-sharing-preferences,
          last-updated: block-height
        }
      )
    ))
  )
)

;; Authorize a provider to access patient data
(define-public (authorize-provider (provider-id principal) (access-level uint) (expiration-blocks uint))
  (begin
    (asserts! (is-some (map-get? patients {patient-id: tx-sender})) (err u404)) ;; Patient not found
    (asserts! (<= access-level u3) (err u400)) ;; Invalid access level
    (ok (map-set patient-provider-authorizations
      {patient-id: tx-sender, provider-id: provider-id}
      {
        authorized: true,
        access-level: access-level,
        expiration-height: (+ block-height expiration-blocks)
      }
    ))
  )
)

;; Revoke provider authorization
(define-public (revoke-provider-authorization (provider-id principal))
  (begin
    (asserts! (is-some (map-get? patients {patient-id: tx-sender})) (err u404)) ;; Patient not found
    (ok (map-set patient-provider-authorizations
      {patient-id: tx-sender, provider-id: provider-id}
      {
        authorized: false,
        access-level: u0,
        expiration-height: block-height
      }
    ))
  )
)

;; Check if a provider is authorized to access patient data
(define-read-only (is-provider-authorized (patient-id principal) (provider-id principal))
  (match (map-get? patient-provider-authorizations {patient-id: patient-id, provider-id: provider-id})
    auth (and (get authorized auth) (> (get expiration-height auth) block-height))
    false
  )
)

;; Get provider's access level for a patient
(define-read-only (get-provider-access-level (patient-id principal) (provider-id principal))
  (match (map-get? patient-provider-authorizations {patient-id: patient-id, provider-id: provider-id})
    auth (if (and (get authorized auth) (> (get expiration-height auth) block-height))
          (get access-level auth)
          u0)
    u0
  )
)

;; Get patient profile (patient or authorized provider)
(define-read-only (get-patient-profile (patient-id principal))
  (begin
    (asserts! (or (is-eq tx-sender patient-id)
                 (is-provider-authorized patient-id tx-sender)
                 (is-admin))
             none)
    (map-get? patients {patient-id: patient-id})
  )
)

;; Transfer admin rights (admin only)
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err u403)) ;; Unauthorized
    (ok (var-set admin new-admin))
  )
)
