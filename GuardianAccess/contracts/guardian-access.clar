;; Error constants
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_NOT_WHITELISTED (err u101))
(define-constant ERR_ALLOCATION_EXCEEDED (err u102))
(define-constant ERR_SALE_NOT_ACTIVE (err u103))
(define-constant ERR_INVALID_TIER (err u104))
(define-constant ERR_ALREADY_WHITELISTED (err u105))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u106))

;; Contract constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MAX_ALLOCATION_TIER_1 u10000000) ;; 10 STX
(define-constant MAX_ALLOCATION_TIER_2 u50000000) ;; 50 STX
(define-constant MAX_ALLOCATION_TIER_3 u100000000) ;; 100 STX

;; Sale phases
(define-constant PHASE_INACTIVE u0)
(define-constant PHASE_TIER_3_ONLY u1)
(define-constant PHASE_TIER_2_AND_3 u2)
(define-constant PHASE_PUBLIC u3)

;; Whitelist data structures
(define-map whitelist-entries
  { address: principal }
  {
    tier: uint,
    max-allocation: uint,
    used-allocation: uint,
    whitelisted-at: uint,
    is-active: bool,
    referrer: (optional principal)
  }
)

;; Tier configurations
(define-map tier-configs
  { tier: uint }
  {
    name: (string-ascii 32),
    max-allocation: uint,
    min-investment: uint,
    early-access-blocks: uint
  }
)

;; Sale state
(define-data-var current-phase uint PHASE_INACTIVE)
(define-data-var sale-start-block uint u0)
(define-data-var total-raised uint u0)
(define-data-var max-raise-target uint u1000000000) ;; 1000 STX

;; Statistics
(define-data-var total-whitelisted uint u0)
(define-data-var total-participants uint u0)

;; Purchase tracking
(define-map user-purchases
  { user: principal }
  { 
    total-purchased: uint,
    purchase-count: uint,
    first-purchase: uint,
    last-purchase: uint
  }
)

;; Referral tracking
(define-map referral-stats
  { referrer: principal }
  { referred-count: uint, total-volume: uint }
)

;; Read-only functions
(define-read-only (get-whitelist-info (address principal))
  (map-get? whitelist-entries { address: address })
)

(define-read-only (get-tier-config (tier uint))
  (map-get? tier-configs { tier: tier })
)

(define-read-only (get-sale-state)
  {
    current-phase: (var-get current-phase),
    sale-start-block: (var-get sale-start-block),
    total-raised: (var-get total-raised),
    max-target: (var-get max-raise-target),
    total-whitelisted: (var-get total-whitelisted),
    participants: (var-get total-participants)
  }
)

(define-read-only (get-user-purchase-info (user principal))
  (map-get? user-purchases { user: user })
)

(define-read-only (is-eligible-for-purchase (user principal) (amount uint))
  (let
    (
      (whitelist-data (get-whitelist-info user))
      (current-phase-val (var-get current-phase))
    )
    (match whitelist-data
      entry (let
        (
          (tier (get tier entry))
          (remaining-allocation (- (get max-allocation entry) (get used-allocation entry)))
          (is-active (get is-active entry))
        )
        (and 
          is-active
          (>= remaining-allocation amount)
          (>= current-phase-val (if (is-eq tier u3) u1 (if (is-eq tier u2) u2 u3)))
        )
      )
      (is-eq current-phase-val PHASE_PUBLIC)
    )
  )
)

;; Admin functions
(define-public (initialize-tiers)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    ;; Set up tier configurations
    (map-set tier-configs { tier: u1 }
      { name: "Bronze", max-allocation: MAX_ALLOCATION_TIER_1, 
        min-investment: u1000000, early-access-blocks: u0 })
    
    (map-set tier-configs { tier: u2 }
      { name: "Silver", max-allocation: MAX_ALLOCATION_TIER_2, 
        min-investment: u5000000, early-access-blocks: u144 })
    
    (map-set tier-configs { tier: u3 }
      { name: "Gold", max-allocation: MAX_ALLOCATION_TIER_3, 
        min-investment: u10000000, early-access-blocks: u288 })
    
    (ok true)
  )
)

(define-public (add-to-whitelist (address principal) (tier uint) (referrer (optional principal)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= tier u3) ERR_INVALID_TIER)
    (asserts! (> tier u0) ERR_INVALID_TIER)
    (asserts! (is-none (get-whitelist-info address)) ERR_ALREADY_WHITELISTED)
    
    (let
      (
        (tier-config (unwrap! (get-tier-config tier) ERR_INVALID_TIER))
      )
      (map-set whitelist-entries
        { address: address }
        {
          tier: tier,
          max-allocation: (get max-allocation tier-config),
          used-allocation: u0,
          whitelisted-at: block-height,
          is-active: true,
          referrer: referrer
        }
      )
      
      ;; Update referrer stats if applicable
      (match referrer
        ref-addr (let
          (
            (ref-stats (default-to { referred-count: u0, total-volume: u0 }
                                  (map-get? referral-stats { referrer: ref-addr })))
          )
          (map-set referral-stats
            { referrer: ref-addr }
            (merge ref-stats { referred-count: (+ (get referred-count ref-stats) u1) })
          )
        )
        true
      )
      
      (var-set total-whitelisted (+ (var-get total-whitelisted) u1))
      (ok true)
    )
  )
)

(define-public (update-sale-phase (new-phase uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-phase PHASE_PUBLIC) ERR_INVALID_TIER)
    
    (if (is-eq (var-get current-phase) PHASE_INACTIVE)
      (var-set sale-start-block block-height)
      true
    )
    
    (var-set current-phase new-phase)
    (ok new-phase)
  )
)

;; Purchase function
(define-public (purchase-allocation (amount uint))
  (let
    (
      (whitelist-data (get-whitelist-info tx-sender))
      (current-phase-val (var-get current-phase))
      (current-raised (var-get total-raised))
      (max-target (var-get max-raise-target))
    )
    ;; Check sale is active
    (asserts! (> current-phase-val PHASE_INACTIVE) ERR_SALE_NOT_ACTIVE)
    
    ;; Check total raise limit
    (asserts! (<= (+ current-raised amount) max-target) ERR_ALLOCATION_EXCEEDED)
    
    ;; Check eligibility
    (asserts! (is-eligible-for-purchase tx-sender amount) ERR_NOT_WHITELISTED)
    
    ;; Process payment
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update allocations for whitelisted users
    (match whitelist-data
      entry (begin
        (map-set whitelist-entries
          { address: tx-sender }
          (merge entry { used-allocation: (+ (get used-allocation entry) amount) })
        )
        
        ;; Update referrer volume if applicable
        (match (get referrer entry)
          ref-addr (let
            (
              (ref-stats (default-to { referred-count: u0, total-volume: u0 }
                                    (map-get? referral-stats { referrer: ref-addr })))
            )
            (map-set referral-stats
              { referrer: ref-addr }
              (merge ref-stats { total-volume: (+ (get total-volume ref-stats) amount) })
            )
          )
          true
        )
      )
      true ;; Public phase purchase
    )
    
    ;; Update user purchase history
    (let
      (
        (purchase-data (default-to
          { total-purchased: u0, purchase-count: u0, first-purchase: block-height, last-purchase: block-height }
          (get-user-purchase-info tx-sender)))
      )
      (map-set user-purchases
        { user: tx-sender }
        {
          total-purchased: (+ (get total-purchased purchase-data) amount),
          purchase-count: (+ (get purchase-count purchase-data) u1),
          first-purchase: (get first-purchase purchase-data),
          last-purchase: block-height
        }
      )
    )
    
    ;; Update global counters
    (var-set total-raised (+ current-raised amount))
    (if (is-eq (get purchase-count (default-to { purchase-count: u0, total-purchased: u0, first-purchase: u0, last-purchase: u0 } (get-user-purchase-info tx-sender))) u0)
      (var-set total-participants (+ (var-get total-participants) u1))
      true
    )
    
    (ok amount)
  )
)

;; Utility functions
(define-public (remove-from-whitelist (address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (is-some (get-whitelist-info address)) ERR_NOT_WHITELISTED)
    
    (map-set whitelist-entries
      { address: address }
      (merge (unwrap-panic (get-whitelist-info address)) { is-active: false })
    )
    
    (ok true)
  )
)

(define-read-only (get-referral-stats (referrer principal))
  (map-get? referral-stats { referrer: referrer })
)