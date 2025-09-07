;; BTC Time Capsule Smart Contract
;; Comprehensive contract for time-locked messages and NFTs with advanced features

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-capsule-not-found (err u101))
(define-constant err-capsule-locked (err u102))
(define-constant err-invalid-unlock-height (err u103))
(define-constant err-beneficiary-not-found (err u104))
(define-constant err-invalid-capsule-type (err u105))
(define-constant err-emergency-unlock-failed (err u106))
(define-constant err-transfer-failed (err u107))
(define-constant err-nft-not-found (err u108))
(define-constant err-insufficient-fee (err u109))

;; Capsule Types
(define-constant capsule-type-message u1)
(define-constant capsule-type-nft u2)
(define-constant capsule-type-hybrid u3)

;; Emergency unlock penalty (10% of locked value)
(define-constant emergency-penalty-percent u10)

;; Data Variables
(define-data-var next-capsule-id uint u1)
(define-data-var next-nft-id uint u1)
(define-data-var contract-uri (optional (string-utf8 256)) none)
(define-data-var emergency-unlock-enabled bool true)
(define-data-var creation-fee uint u1000000)

;; Data Maps
(define-map time-capsules
  { capsule-id: uint }
  {
    owner: principal,
    beneficiary: (optional principal),
    unlock-height: uint,
    message: (optional (string-utf8 1000)),
    nft-id: (optional uint),
    capsule-type: uint,
    category: (string-utf8 50),
    title: (string-utf8 100),
    is-unlocked: bool,
    created-at-height: uint,
    locked-value: uint,
    metadata-uri: (optional (string-utf8 256))
  }
)

(define-map nft-metadata
  { nft-id: uint }
  {
    name: (string-utf8 50),
    description: (string-utf8 200),
    image: (string-utf8 256),
    capsule-id: uint
  }
)

(define-map capsule-owners
  { nft-id: uint }
  { owner: principal }
)

(define-map user-capsules
  { user: principal }
  { capsule-ids: (list 100 uint) }
)

(define-map emergency-unlocks
  { capsule-id: uint }
  {
    unlocked-by: principal,
    penalty-paid: uint,
    unlock-height: uint
  }
)

;; SIP-009 NFT Functions
(define-read-only (get-last-token-id)
  (ok (- (var-get next-nft-id) u1))
)

(define-read-only (get-token-uri (nft-id uint))
  (ok (map-get? nft-metadata { nft-id: nft-id }))
)

(define-read-only (get-owner (nft-id uint))
  (ok (map-get? capsule-owners { nft-id: nft-id }))
)

;; Read-only functions
(define-read-only (get-capsule (capsule-id uint))
  (map-get? time-capsules { capsule-id: capsule-id })
)

(define-read-only (get-current-block-height)
  block-height
)

(define-read-only (is-capsule-unlockable (capsule-id uint))
  (match (map-get? time-capsules { capsule-id: capsule-id })
    capsule (>= block-height (get unlock-height capsule))
    false
  )
)

(define-read-only (get-user-capsules (user principal))
  (default-to (list) (get capsule-ids (map-get? user-capsules { user: user })))
)

(define-read-only (get-capsule-metadata (capsule-id uint))
  (match (map-get? time-capsules { capsule-id: capsule-id })
    capsule (ok {
      title: (get title capsule),
      category: (get category capsule),
      type: (get capsule-type capsule),
      unlock-height: (get unlock-height capsule),
      created-at: (get created-at-height capsule),
      locked-value: (get locked-value capsule)
    })
    err-capsule-not-found
  )
)

(define-read-only (calculate-emergency-penalty (locked-value uint))
  (/ (* locked-value emergency-penalty-percent) u100)
)

;; Public functions
(define-public (create-message-capsule 
  (unlock-height uint) 
  (message (string-utf8 1000))
  (title (string-utf8 100))
  (category (string-utf8 50))
  (beneficiary (optional principal)))
  (let (
    (capsule-id (var-get next-capsule-id))
    (fee (var-get creation-fee))
  )
    (asserts! (> unlock-height block-height) err-invalid-unlock-height)
    (try! (stx-transfer? fee tx-sender contract-owner))
    (map-set time-capsules
      { capsule-id: capsule-id }
      {
        owner: tx-sender,
        beneficiary: beneficiary,
        unlock-height: unlock-height,
        message: (some message),
        nft-id: none,
        capsule-type: capsule-type-message,
        category: category,
        title: title,
        is-unlocked: false,
        created-at-height: block-height,
        locked-value: fee,
        metadata-uri: none
      }
    )
    (unwrap-panic (add-to-user-capsules tx-sender capsule-id))
    (var-set next-capsule-id (+ capsule-id u1))
    (print { event: "capsule-created", capsule-id: capsule-id, type: "message" })
    (ok capsule-id)
  )
)

(define-public (create-nft-capsule 
  (unlock-height uint)
  (nft-name (string-utf8 50))
  (nft-description (string-utf8 200))
  (nft-image (string-utf8 256))
  (title (string-utf8 100))
  (category (string-utf8 50))
  (beneficiary (optional principal)))
  (let (
    (capsule-id (var-get next-capsule-id))
    (nft-id (var-get next-nft-id))
    (fee (var-get creation-fee))
  )
    (asserts! (> unlock-height block-height) err-invalid-unlock-height)
    (try! (stx-transfer? fee tx-sender contract-owner))
    (map-set nft-metadata
      { nft-id: nft-id }
      {
        name: nft-name,
        description: nft-description,
        image: nft-image,
        capsule-id: capsule-id
      }
    )
    (map-set time-capsules
      { capsule-id: capsule-id }
      {
        owner: tx-sender,
        beneficiary: beneficiary,
        unlock-height: unlock-height,
        message: none,
        nft-id: (some nft-id),
        capsule-type: capsule-type-nft,
        category: category,
        title: title,
        is-unlocked: false,
        created-at-height: block-height,
        locked-value: fee,
        metadata-uri: none
      }
    )
    (unwrap-panic (add-to-user-capsules tx-sender capsule-id))
    (var-set next-capsule-id (+ capsule-id u1))
    (var-set next-nft-id (+ nft-id u1))
    (print { event: "capsule-created", capsule-id: capsule-id, type: "nft" })
    (ok capsule-id)
  )
)

(define-public (create-hybrid-capsule 
  (unlock-height uint)
  (message (string-utf8 1000))
  (nft-name (string-utf8 50))
  (nft-description (string-utf8 200))
  (nft-image (string-utf8 256))
  (title (string-utf8 100))
  (category (string-utf8 50))
  (beneficiary (optional principal)))
  (let (
    (capsule-id (var-get next-capsule-id))
    (nft-id (var-get next-nft-id))
    (fee (* (var-get creation-fee) u2))
  )
    (asserts! (> unlock-height block-height) err-invalid-unlock-height)
    (try! (stx-transfer? fee tx-sender contract-owner))
    (map-set nft-metadata
      { nft-id: nft-id }
      {
        name: nft-name,
        description: nft-description,
        image: nft-image,
        capsule-id: capsule-id
      }
    )
    (map-set time-capsules
      { capsule-id: capsule-id }
      {
        owner: tx-sender,
        beneficiary: beneficiary,
        unlock-height: unlock-height,
        message: (some message),
        nft-id: (some nft-id),
        capsule-type: capsule-type-hybrid,
        category: category,
        title: title,
        is-unlocked: false,
        created-at-height: block-height,
        locked-value: fee,
        metadata-uri: none
      }
    )
    (unwrap-panic (add-to-user-capsules tx-sender capsule-id))
    (var-set next-capsule-id (+ capsule-id u1))
    (var-set next-nft-id (+ nft-id u1))
    (print { event: "capsule-created", capsule-id: capsule-id, type: "hybrid" })
    (ok capsule-id)
  )
)

(define-public (unlock-capsule (capsule-id uint))
  (match (map-get? time-capsules { capsule-id: capsule-id })
    capsule
      (let ((authorized-user (default-to (get owner capsule) (get beneficiary capsule))))
        (asserts! (or (is-eq tx-sender (get owner capsule)) 
                     (is-eq tx-sender authorized-user)) err-not-authorized)
        (asserts! (>= block-height (get unlock-height capsule)) err-capsule-locked)
        (map-set time-capsules
          { capsule-id: capsule-id }
          (merge capsule { is-unlocked: true })
        )
        (match (get nft-id capsule)
          nft-id (map-set capsule-owners { nft-id: nft-id } { owner: tx-sender })
          true
        )
        (print { event: "capsule-unlocked", capsule-id: capsule-id, by: tx-sender })
        (ok {
          message: (get message capsule),
          nft-id: (get nft-id capsule),
          type: (get capsule-type capsule)
        })
      )
    err-capsule-not-found
  )
)

(define-public (emergency-unlock (capsule-id uint))
  (match (map-get? time-capsules { capsule-id: capsule-id })
    capsule
      (let (
        (penalty (calculate-emergency-penalty (get locked-value capsule)))
        (authorized-user (default-to (get owner capsule) (get beneficiary capsule)))
      )
        (asserts! (var-get emergency-unlock-enabled) err-emergency-unlock-failed)
        (asserts! (or (is-eq tx-sender (get owner capsule)) 
                     (is-eq tx-sender authorized-user)) err-not-authorized)
        (asserts! (not (get is-unlocked capsule)) err-capsule-locked)
        (try! (stx-transfer? penalty tx-sender contract-owner))
        (map-set time-capsules
          { capsule-id: capsule-id }
          (merge capsule { is-unlocked: true })
        )
        (map-set emergency-unlocks
          { capsule-id: capsule-id }
          {
            unlocked-by: tx-sender,
            penalty-paid: penalty,
            unlock-height: block-height
          }
        )
        (match (get nft-id capsule)
          nft-id (map-set capsule-owners { nft-id: nft-id } { owner: tx-sender })
          true
        )
        (print { event: "emergency-unlock", capsule-id: capsule-id, penalty: penalty })
        (ok {
          message: (get message capsule),
          nft-id: (get nft-id capsule),
          penalty-paid: penalty
        })
      )
    err-capsule-not-found
  )
)

(define-public (transfer-capsule (capsule-id uint) (new-owner principal))
  (match (map-get? time-capsules { capsule-id: capsule-id })
    capsule
      (begin
        (asserts! (is-eq tx-sender (get owner capsule)) err-not-authorized)
        (asserts! (not (get is-unlocked capsule)) err-capsule-locked)
        (map-set time-capsules
          { capsule-id: capsule-id }
          (merge capsule { owner: new-owner })
        )
        (unwrap-panic (remove-from-user-capsules tx-sender capsule-id))
        (unwrap-panic (add-to-user-capsules new-owner capsule-id))
        (print { event: "capsule-transferred", capsule-id: capsule-id, from: tx-sender, to: new-owner })
        (ok true)
      )
    err-capsule-not-found
  )
)

(define-public (set-beneficiary (capsule-id uint) (new-beneficiary principal))
  (match (map-get? time-capsules { capsule-id: capsule-id })
    capsule
      (begin
        (asserts! (is-eq tx-sender (get owner capsule)) err-not-authorized)
        (map-set time-capsules
          { capsule-id: capsule-id }
          (merge capsule { beneficiary: (some new-beneficiary) })
        )
        (print { event: "beneficiary-set", capsule-id: capsule-id, beneficiary: new-beneficiary })
        (ok true)
      )
    err-capsule-not-found
  )
)

(define-public (get-unlocked-content (capsule-id uint))
  (match (map-get? time-capsules { capsule-id: capsule-id })
    capsule
      (let ((authorized-user (default-to (get owner capsule) (get beneficiary capsule))))
        (asserts! (or (is-eq tx-sender (get owner capsule)) 
                     (is-eq tx-sender authorized-user)) err-not-authorized)
        (asserts! (get is-unlocked capsule) err-capsule-locked)
        (ok {
          message: (get message capsule),
          nft-id: (get nft-id capsule),
          metadata: (match (get nft-id capsule)
            nft-id (map-get? nft-metadata { nft-id: nft-id })
            none
          )
        })
      )
    err-capsule-not-found
  )
)

;; Helper functions
(define-private (add-to-user-capsules (user principal) (capsule-id uint))
  (let ((current-list (default-to (list) (get capsule-ids (map-get? user-capsules { user: user })))))
    (map-set user-capsules
      { user: user }
      { capsule-ids: (unwrap! (as-max-len? (append current-list capsule-id) u100) err-transfer-failed) }
    )
    (ok true)
  )
)

(define-private (remove-from-user-capsules (user principal) (capsule-id uint))
  (let ((current-list (default-to (list) (get capsule-ids (map-get? user-capsules { user: user })))))
    (var-set target-id capsule-id)
    (map-set user-capsules
      { user: user }
      { capsule-ids: (filter is-not-target-id current-list) }
    )
    (ok true)
  )
)

(define-private (is-not-target-id (id uint))
  (not (is-eq id (var-get target-id)))
)

(define-data-var target-id uint u0)

;; Admin functions
(define-public (set-creation-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (var-set creation-fee new-fee)
    (print { event: "fee-updated", new-fee: new-fee })
    (ok true)
  )
)

(define-public (toggle-emergency-unlock)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (var-set emergency-unlock-enabled (not (var-get emergency-unlock-enabled)))
    (print { event: "emergency-unlock-toggled", enabled: (var-get emergency-unlock-enabled) })
    (ok (var-get emergency-unlock-enabled))
  )
)

(define-public (set-contract-uri (new-uri (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (var-set contract-uri (some new-uri))
    (ok true)
  )
)

;; SIP-009 Required Functions
(define-public (transfer (nft-id uint) (sender principal) (recipient principal))
  (match (map-get? capsule-owners { nft-id: nft-id })
    owner-data
      (begin
        (asserts! (is-eq tx-sender (get owner owner-data)) err-not-authorized)
        (map-set capsule-owners { nft-id: nft-id } { owner: recipient })
        (print { event: "nft-transferred", nft-id: nft-id, from: sender, to: recipient })
        (ok true)
      )
    err-nft-not-found
  )
)

(define-public (mint (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (let ((nft-id (var-get next-nft-id)))
      (map-set capsule-owners { nft-id: nft-id } { owner: recipient })
      (var-set next-nft-id (+ nft-id u1))
      (print { event: "nft-minted", nft-id: nft-id, recipient: recipient })
      (ok nft-id)
    )
  )
)

;; Utility functions
(define-read-only (get-capsules-by-category (category (string-utf8 50)))
  (ok "Use off-chain indexing for category filtering")
)

(define-read-only (get-total-capsules)
  (- (var-get next-capsule-id) u1)
)

(define-read-only (get-total-nfts)
  (- (var-get next-nft-id) u1)
)