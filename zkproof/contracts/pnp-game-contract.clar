;; zkProof-as-a-Service Smart Contract
;; Provides plug-and-play zk tooling for developers

;; ==============================================================================
;; CONSTANTS & ERROR CODES
;; ==============================================================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROOF_NOT_FOUND (err u101))
(define-constant ERR_INVALID_PROOF (err u102))
(define-constant ERR_PROOF_ALREADY_EXISTS (err u103))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u104))
(define-constant ERR_VERIFIER_NOT_REGISTERED (err u105))
(define-constant ERR_INVALID_PROOF_TYPE (err u106))

;; ==============================================================================
;; DATA VARIABLES
;; ==============================================================================

(define-data-var service-fee uint u1000000) ;; 1 STX in microSTX
(define-data-var next-proof-id uint u1)
(define-data-var contract-paused bool false)

;; ==============================================================================
;; DATA MAPS
;; ==============================================================================

;; Store zk proofs with metadata
(define-map proofs
  { proof-id: uint }
  {
    submitter: principal,
    proof-type: (string-ascii 32),
    proof-hash: (buff 32),
    public-inputs: (buff 1024),
    verification-key: (buff 512),
    verified: bool,
    verifier: (optional principal),
    timestamp: uint,
    expiry: uint
  }
)

;; Registered verifiers and their capabilities
(define-map verifiers
  { verifier: principal }
  {
    name: (string-ascii 64),
    supported-types: (list 10 (string-ascii 32)),
    reputation-score: uint,
    total-verifications: uint,
    active: bool
  }
)

;; Service usage statistics per user
(define-map user-stats
  { user: principal }
  {
    total-proofs: uint,
    verified-proofs: uint,
    last-activity: uint
  }
)

;; Proof type configurations
(define-map proof-types
  { proof-type: (string-ascii 32) }
  {
    min-fee: uint,
    verification-timeout: uint,
    requires-stake: bool,
    active: bool
  }
)

;; ==============================================================================
;; PRIVATE FUNCTIONS
;; ==============================================================================

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (update-user-stats (user principal) (verified bool))
  (let (
    (current-stats (default-to
      { total-proofs: u0, verified-proofs: u0, last-activity: u0 }
      (map-get? user-stats { user: user })
    ))
  )
    (map-set user-stats
      { user: user }
      {
        total-proofs: (+ (get total-proofs current-stats) u1),
        verified-proofs: (if verified 
          (+ (get verified-proofs current-stats) u1)
          (get verified-proofs current-stats)
        ),
        last-activity: block-height
      }
    )
  )
)

(define-private (is-valid-proof-type (proof-type (string-ascii 32)))
  (is-some (map-get? proof-types { proof-type: proof-type }))
)

;; ==============================================================================
;; PUBLIC FUNCTIONS - SETUP & ADMIN
;; ==============================================================================

(define-public (initialize-contract)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    ;; Initialize common proof types
    (try! (add-proof-type "zk-snark" u500000 u144 false)) ;; ~24 hours
    (try! (add-proof-type "zk-stark" u750000 u144 false))
    (try! (add-proof-type "bulletproof" u300000 u72 false)) ;; ~12 hours
    (try! (add-proof-type "plonk" u600000 u144 false))
    (ok true)
  )
)

(define-public (add-proof-type 
  (proof-type (string-ascii 32))
  (min-fee uint)
  (verification-timeout uint)
  (requires-stake bool)
)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (map-set proof-types
      { proof-type: proof-type }
      {
        min-fee: min-fee,
        verification-timeout: verification-timeout,
        requires-stake: requires-stake,
        active: true
      }
    )
    (ok true)
  )
)

(define-public (register-verifier 
  (name (string-ascii 64))
  (supported-types (list 10 (string-ascii 32)))
)
  (begin
    (map-set verifiers
      { verifier: tx-sender }
      {
        name: name,
        supported-types: supported-types,
        reputation-score: u100, ;; Start with neutral reputation
        total-verifications: u0,
        active: true
      }
    )
    (ok true)
  )
)

;; ==============================================================================
;; PUBLIC FUNCTIONS - CORE PROOF OPERATIONS
;; ==============================================================================

(define-public (submit-proof
  (proof-type (string-ascii 32))
  (proof-hash (buff 32))
  (public-inputs (buff 1024))
  (verification-key (buff 512))
  (expiry-blocks uint)
)
  (let (
    (proof-id (var-get next-proof-id))
    (type-config (unwrap! (map-get? proof-types { proof-type: proof-type }) ERR_INVALID_PROOF_TYPE))
    (required-fee (get min-fee type-config))
  )
    (begin
      (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
      (asserts! (>= (stx-get-balance tx-sender) required-fee) ERR_INSUFFICIENT_PAYMENT)
      
      ;; Transfer fee to contract
      (try! (stx-transfer? required-fee tx-sender (as-contract tx-sender)))
      
      ;; Store proof
      (map-set proofs
        { proof-id: proof-id }
        {
          submitter: tx-sender,
          proof-type: proof-type,
          proof-hash: proof-hash,
          public-inputs: public-inputs,
          verification-key: verification-key,
          verified: false,
          verifier: none,
          timestamp: block-height,
          expiry: (+ block-height expiry-blocks)
        }
      )
      
      ;; Update counters and stats
      (var-set next-proof-id (+ proof-id u1))
      (update-user-stats tx-sender false)
      
      (ok proof-id)
    )
  )
)

(define-public (verify-proof (proof-id uint) (verification-result bool))
  (let (
    (proof-data (unwrap! (map-get? proofs { proof-id: proof-id }) ERR_PROOF_NOT_FOUND))
    (verifier-data (unwrap! (map-get? verifiers { verifier: tx-sender }) ERR_VERIFIER_NOT_REGISTERED))
  )
    (begin
      (asserts! (get active verifier-data) ERR_UNAUTHORIZED)
      (asserts! (< block-height (get expiry proof-data)) ERR_INVALID_PROOF)
      (asserts! (not (get verified proof-data)) ERR_PROOF_ALREADY_EXISTS)
      
      ;; Update proof verification status
      (map-set proofs
        { proof-id: proof-id }
        (merge proof-data {
          verified: verification-result,
          verifier: (some tx-sender)
        })
      )
      
      ;; Update verifier stats
      (map-set verifiers
        { verifier: tx-sender }
        (merge verifier-data {
          total-verifications: (+ (get total-verifications verifier-data) u1),
          reputation-score: (if verification-result 
            (+ (get reputation-score verifier-data) u1)
            (get reputation-score verifier-data)
          )
        })
      )
      
      ;; Update user stats
      (update-user-stats (get submitter proof-data) verification-result)
      
      (ok verification-result)
    )
  )
)

(define-public (batch-verify-proofs 
  (proof-ids (list 50 uint))
  (verification-results (list 50 bool))
)
  (let (
    (verifier-data (unwrap! (map-get? verifiers { verifier: tx-sender }) ERR_VERIFIER_NOT_REGISTERED))
  )
    (begin
      (asserts! (get active verifier-data) ERR_UNAUTHORIZED)
      (asserts! (is-eq (len proof-ids) (len verification-results)) ERR_INVALID_PROOF)
      
      (ok (map verify-single-proof proof-ids verification-results))
    )
  )
)

(define-private (verify-single-proof (proof-id uint) (result bool))
  (match (verify-proof proof-id result)
    success true
    error false
  )
)

;; ==============================================================================
;; PUBLIC FUNCTIONS - QUERIES
;; ==============================================================================

(define-read-only (get-proof (proof-id uint))
  (map-get? proofs { proof-id: proof-id })
)

(define-read-only (get-verifier (verifier principal))
  (map-get? verifiers { verifier: verifier })
)

(define-read-only (get-user-stats (user principal))
  (map-get? user-stats { user: user })
)

(define-read-only (get-proof-type-config (proof-type (string-ascii 32)))
  (map-get? proof-types { proof-type: proof-type })
)

(define-read-only (get-service-fee)
  (var-get service-fee)
)

(define-read-only (get-next-proof-id)
  (var-get next-proof-id)
)

(define-read-only (is-proof-verified (proof-id uint))
  (match (map-get? proofs { proof-id: proof-id })
    proof-data (get verified proof-data)
    false
  )
)

;; ==============================================================================
;; PUBLIC FUNCTIONS - UTILITIES
;; ==============================================================================

(define-public (challenge-verification (proof-id uint))
  (let (
    (proof-data (unwrap! (map-get? proofs { proof-id: proof-id }) ERR_PROOF_NOT_FOUND))
  )
    (begin
      (asserts! (is-eq tx-sender (get submitter proof-data)) ERR_UNAUTHORIZED)
      (asserts! (get verified proof-data) ERR_INVALID_PROOF)
      
      ;; Reset verification status for re-evaluation
      (map-set proofs
        { proof-id: proof-id }
        (merge proof-data {
          verified: false,
          verifier: none
        })
      )
      
      (ok true)
    )
  )
)

(define-public (extend-proof-expiry (proof-id uint) (additional-blocks uint))
  (let (
    (proof-data (unwrap! (map-get? proofs { proof-id: proof-id }) ERR_PROOF_NOT_FOUND))
    (extension-fee (/ (var-get service-fee) u10)) ;; 10% of service fee
  )
    (begin
      (asserts! (is-eq tx-sender (get submitter proof-data)) ERR_UNAUTHORIZED)
      (try! (stx-transfer? extension-fee tx-sender (as-contract tx-sender)))
      
      (map-set proofs
        { proof-id: proof-id }
        (merge proof-data {
          expiry: (+ (get expiry proof-data) additional-blocks)
        })
      )
      
      (ok true)
    )
  )
)

;; ==============================================================================
;; ADMIN FUNCTIONS
;; ==============================================================================

(define-public (set-service-fee (new-fee uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set service-fee new-fee)
    (ok true)
  )
)

(define-public (pause-contract)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-paused true)
    (ok true)
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-paused false)
    (ok true)
  )
)

(define-public (withdraw-fees (amount uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER))
  )
)