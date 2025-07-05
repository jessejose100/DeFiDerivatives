;; On-Chain Futures and Options Trading Contract
;; This contract enables decentralized trading of futures and options contracts
;; with collateral management, settlement mechanisms, and risk controls

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u102))
(define-constant ERR_CONTRACT_NOT_FOUND (err u103))
(define-constant ERR_CONTRACT_EXPIRED (err u104))
(define-constant ERR_ALREADY_SETTLED (err u105))
(define-constant ERR_NOT_EXPIRED (err u106))
(define-constant ERR_INVALID_STRIKE (err u107))
(define-constant MIN_COLLATERAL_RATIO u150) ;; 150% minimum collateral
(define-constant LIQUIDATION_THRESHOLD u120) ;; 120% liquidation threshold

;; Data Maps and Variables
(define-map futures-contracts
  { contract-id: uint }
  {
    creator: principal,
    counterparty: (optional principal),
    underlying-asset: (string-ascii 10),
    contract-size: uint,
    strike-price: uint,
    expiry-block: uint,
    collateral-amount: uint,
    is-settled: bool,
    settlement-price: (optional uint)
  }
)

(define-map options-contracts
  { contract-id: uint }
  {
    creator: principal,
    holder: (optional principal),
    underlying-asset: (string-ascii 10),
    contract-size: uint,
    strike-price: uint,
    expiry-block: uint,
    option-type: (string-ascii 4), ;; "CALL" or "PUT"
    premium: uint,
    collateral-amount: uint,
    is-exercised: bool,
    is-settled: bool
  }
)

(define-map user-balances
  { user: principal, asset: (string-ascii 10) }
  { balance: uint }
)

(define-map collateral-deposits
  { user: principal, contract-id: uint, contract-type: (string-ascii 7) }
  { amount: uint }
)

(define-data-var next-contract-id uint u1)
(define-data-var oracle-price uint u0)
(define-data-var last-price-update uint u0)

;; Private Functions
(define-private (get-user-balance (user principal) (asset (string-ascii 10)))
  (default-to u0 (get balance (map-get? user-balances { user: user, asset: asset })))
)

(define-private (update-user-balance (user principal) (asset (string-ascii 10)) (new-balance uint))
  (map-set user-balances { user: user, asset: asset } { balance: new-balance })
)

(define-private (calculate-collateral-requirement (contract-size uint) (strike-price uint))
  (/ (* contract-size strike-price MIN_COLLATERAL_RATIO) u100)
)

(define-private (is-contract-expired (expiry-block uint))
  (>= block-height expiry-block)
)

(define-private (validate-collateral (user principal) (required-amount uint) (asset (string-ascii 10)))
  (>= (get-user-balance user asset) required-amount)
)

;; Public Functions
(define-public (deposit-funds (amount uint) (asset (string-ascii 10)))
  (let ((current-balance (get-user-balance tx-sender asset)))
    (begin
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (update-user-balance tx-sender asset (+ current-balance amount))
      (ok true)
    )
  )
)

(define-public (withdraw-funds (amount uint) (asset (string-ascii 10)))
  (let ((current-balance (get-user-balance tx-sender asset)))
    (begin
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (asserts! (>= current-balance amount) ERR_INSUFFICIENT_COLLATERAL)
      (update-user-balance tx-sender asset (- current-balance amount))
      (ok true)
    )
  )
)

(define-public (create-futures-contract 
  (underlying-asset (string-ascii 10))
  (contract-size uint)
  (strike-price uint)
  (expiry-block uint))
  (let (
    (contract-id (var-get next-contract-id))
    (required-collateral (calculate-collateral-requirement contract-size strike-price))
  )
    (begin
      (asserts! (> contract-size u0) ERR_INVALID_AMOUNT)
      (asserts! (> strike-price u0) ERR_INVALID_STRIKE)
      (asserts! (> expiry-block block-height) ERR_CONTRACT_EXPIRED)
      (asserts! (validate-collateral tx-sender required-collateral underlying-asset) ERR_INSUFFICIENT_COLLATERAL)
      
      (map-set futures-contracts
        { contract-id: contract-id }
        {
          creator: tx-sender,
          counterparty: none,
          underlying-asset: underlying-asset,
          contract-size: contract-size,
          strike-price: strike-price,
          expiry-block: expiry-block,
          collateral-amount: required-collateral,
          is-settled: false,
          settlement-price: none
        }
      )
      
      (map-set collateral-deposits
        { user: tx-sender, contract-id: contract-id, contract-type: "FUTURES" }
        { amount: required-collateral }
      )
      
      (update-user-balance tx-sender underlying-asset 
        (- (get-user-balance tx-sender underlying-asset) required-collateral))
      (var-set next-contract-id (+ contract-id u1))
      (ok contract-id)
    )
  )
)

(define-public (create-options-contract
  (underlying-asset (string-ascii 10))
  (contract-size uint)
  (strike-price uint)
  (expiry-block uint)
  (option-type (string-ascii 4))
  (premium uint))
  (let (
    (contract-id (var-get next-contract-id))
    (required-collateral (if (is-eq option-type "CALL")
      (* contract-size strike-price)
      (calculate-collateral-requirement contract-size strike-price)))
  )
    (begin
      (asserts! (> contract-size u0) ERR_INVALID_AMOUNT)
      (asserts! (> strike-price u0) ERR_INVALID_STRIKE)
      (asserts! (> expiry-block block-height) ERR_CONTRACT_EXPIRED)
      (asserts! (or (is-eq option-type "CALL") (is-eq option-type "PUT")) ERR_INVALID_AMOUNT)
      (asserts! (validate-collateral tx-sender required-collateral underlying-asset) ERR_INSUFFICIENT_COLLATERAL)
      
      (map-set options-contracts
        { contract-id: contract-id }
        {
          creator: tx-sender,
          holder: none,
          underlying-asset: underlying-asset,
          contract-size: contract-size,
          strike-price: strike-price,
          expiry-block: expiry-block,
          option-type: option-type,
          premium: premium,
          collateral-amount: required-collateral,
          is-exercised: false,
          is-settled: false
        }
      )
      
      (map-set collateral-deposits
        { user: tx-sender, contract-id: contract-id, contract-type: "OPTIONS" }
        { amount: required-collateral }
      )
      
      (update-user-balance tx-sender underlying-asset 
        (- (get-user-balance tx-sender underlying-asset) required-collateral))
      (var-set next-contract-id (+ contract-id u1))
      (ok contract-id)
    )
  )
)

(define-public (exercise-option (contract-id uint))
  (let (
    (contract-data (unwrap! (map-get? options-contracts { contract-id: contract-id }) ERR_CONTRACT_NOT_FOUND))
    (current-price (var-get oracle-price))
    (strike-price (get strike-price contract-data))
    (option-type (get option-type contract-data))
    (contract-size (get contract-size contract-data))
    (underlying-asset (get underlying-asset contract-data))
  )
    (begin
      (asserts! (is-some (get holder contract-data)) ERR_UNAUTHORIZED)
      (asserts! (is-eq tx-sender (unwrap-panic (get holder contract-data))) ERR_UNAUTHORIZED)
      (asserts! (not (get is-exercised contract-data)) ERR_ALREADY_SETTLED)
      (asserts! (not (is-contract-expired (get expiry-block contract-data))) ERR_CONTRACT_EXPIRED)
      
      ;; Check if option is in-the-money
      (asserts! 
        (if (is-eq option-type "CALL")
          (> current-price strike-price)
          (< current-price strike-price))
        ERR_INVALID_AMOUNT)
      
      ;; Calculate payout
      (let (
        (payout (if (is-eq option-type "CALL")
          (* contract-size (- current-price strike-price))
          (* contract-size (- strike-price current-price))))
        (creator (get creator contract-data))
        (collateral-amount (get collateral-amount contract-data))
      )
        ;; Update contract status
        (map-set options-contracts
          { contract-id: contract-id }
          (merge contract-data { is-exercised: true, is-settled: true })
        )
        
        ;; Transfer payout to option holder
        (update-user-balance tx-sender underlying-asset 
          (+ (get-user-balance tx-sender underlying-asset) payout))
        
        ;; Return remaining collateral to creator
        (update-user-balance creator underlying-asset 
          (+ (get-user-balance creator underlying-asset) (- collateral-amount payout)))
        
        ;; Clear collateral deposit record
        (map-delete collateral-deposits 
          { user: creator, contract-id: contract-id, contract-type: "OPTIONS" })
        
        (ok payout)
      )
    )
  )
)

;; Advanced Risk Management and Liquidation System
(define-public (liquidate-undercollateralized-position (contract-id uint) (contract-type (string-ascii 7)))
  (let (
    (current-price (var-get oracle-price))
    (liquidation-bonus u105) ;; 5% bonus for liquidators
  )
    (if (is-eq contract-type "FUTURES")
      ;; Handle futures liquidation
      (let (
        (contract-data (unwrap! (map-get? futures-contracts { contract-id: contract-id }) ERR_CONTRACT_NOT_FOUND))
        (creator (get creator contract-data))
        (strike-price (get strike-price contract-data))
        (contract-size (get contract-size contract-data))
        (collateral-amount (get collateral-amount contract-data))
        (current-value (* contract-size current-price))
        (strike-value (* contract-size strike-price))
        (unrealized-loss (if (> current-value strike-value) u0 (- strike-value current-value)))
        (collateral-ratio (if (> unrealized-loss u0) 
          (/ (* (- collateral-amount unrealized-loss) u100) strike-value) u200))
      )
        (begin
          (asserts! (not (get is-settled contract-data)) ERR_ALREADY_SETTLED)
          (asserts! (< collateral-ratio LIQUIDATION_THRESHOLD) ERR_INSUFFICIENT_COLLATERAL)
          
          ;; Calculate liquidation amounts
          (let (
            (liquidation-amount (/ (* collateral-amount liquidation-bonus) u100))
            (remaining-collateral (- collateral-amount liquidation-amount))
          )
            ;; Mark contract as settled
            (map-set futures-contracts
              { contract-id: contract-id }
              (merge contract-data { 
                is-settled: true, 
                settlement-price: (some current-price) 
              })
            )
            
            ;; Reward liquidator
            (update-user-balance tx-sender (get underlying-asset contract-data)
              (+ (get-user-balance tx-sender (get underlying-asset contract-data)) liquidation-amount))
            
            ;; Return remaining collateral to creator
            (if (> remaining-collateral u0)
              (update-user-balance creator (get underlying-asset contract-data)
                (+ (get-user-balance creator (get underlying-asset contract-data)) remaining-collateral))
              true)
            
            ;; Clear collateral deposit
            (map-delete collateral-deposits 
              { user: creator, contract-id: contract-id, contract-type: "FUTURES" })
            
            (ok liquidation-amount)
          )
        )
      )
      ;; Handle options liquidation (similar logic for options contracts)
      (let (
        (contract-data (unwrap! (map-get? options-contracts { contract-id: contract-id }) ERR_CONTRACT_NOT_FOUND))
        (creator (get creator contract-data))
        (collateral-amount (get collateral-amount contract-data))
        (liquidation-amount (/ (* collateral-amount liquidation-bonus) u100))
      )
        (begin
          (asserts! (not (get is-settled contract-data)) ERR_ALREADY_SETTLED)
          
          ;; Mark as settled and liquidate
          (map-set options-contracts
            { contract-id: contract-id }
            (merge contract-data { is-settled: true })
          )
          
          ;; Transfer collateral to liquidator
          (update-user-balance tx-sender (get underlying-asset contract-data)
            (+ (get-user-balance tx-sender (get underlying-asset contract-data)) liquidation-amount))
          
          (ok liquidation-amount)
        )
      )
    )
  )
)


