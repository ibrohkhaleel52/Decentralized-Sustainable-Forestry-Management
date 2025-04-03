;; replanting.clar
;; Tracks reforestation efforts

(define-data-var last-replanting-id uint u0)

(define-map replanting-records
  { replanting-id: uint }
  {
    parcel-id: uint,
    harvest-plan-id: uint,
    owner: principal,
    date: uint,
    species: (string-utf8 100),
    quantity: uint,
    verified: bool,
    verifier: (optional principal)
  }
)

(define-constant contract-owner tx-sender)

(define-map verifiers
  { address: principal }
  { active: bool }
)

(define-map parcel-owners
  { parcel-id: uint }
  { owner: principal }
)

(define-public (register-parcel-owner (parcel-id uint))
  (begin
    (map-set parcel-owners { parcel-id: parcel-id } { owner: tx-sender })
    (ok true)
  )
)

(define-public (register-replanting
    (parcel-id uint)
    (harvest-plan-id uint)
    (species (string-utf8 100))
    (quantity uint))
  (let
    (
      (new-id (+ (var-get last-replanting-id) u1))
      (parcel-owner (default-to { owner: tx-sender } (map-get? parcel-owners { parcel-id: parcel-id })))
    )
    ;; Verify the caller is the parcel owner
    (asserts! (is-eq tx-sender (get owner parcel-owner)) (err u3))

    (var-set last-replanting-id new-id)
    (map-set replanting-records
      { replanting-id: new-id }
      {
        parcel-id: parcel-id,
        harvest-plan-id: harvest-plan-id,
        owner: tx-sender,
        date: block-height,
        species: species,
        quantity: quantity,
        verified: false,
        verifier: none
      }
    )
    (ok new-id)
  )
)

(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u1))
    (map-set verifiers { address: verifier } { active: true })
    (ok true)
  )
)

(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u1))
    (map-delete verifiers { address: verifier })
    (ok true)
  )
)

(define-public (verify-replanting (replanting-id uint))
  (let
    (
      (record (unwrap! (get-replanting-record replanting-id) (err u1)))
      (is-verifier (default-to { active: false } (map-get? verifiers { address: tx-sender })))
    )
    ;; Verify the caller is an authorized verifier
    (asserts! (get active is-verifier) (err u2))
    ;; Verify the record is not already verified
    (asserts! (not (get verified record)) (err u3))

    (map-set replanting-records
      { replanting-id: replanting-id }
      (merge record {
        verified: true,
        verifier: (some tx-sender)
      })
    )
    (ok true)
  )
)

(define-read-only (get-replanting-record (replanting-id uint))
  (map-get? replanting-records { replanting-id: replanting-id })
)
