;; Waste Finance Automation Smart Contract
;; A comprehensive system for automating waste collection payments and incentives

;; Contract constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_INSUFFICIENT_BALANCE (err u402))
(define-constant ERR_INVALID_STATUS (err u403))
(define-constant ERR_EXPIRED_COLLECTION (err u405))
(define-constant ERR_INVALID_WASTE_TYPE (err u406))
(define-constant ERR_INVALID_INPUT (err u407))

;; Waste types with different pricing
(define-constant WASTE_TYPE_ORGANIC u1)
(define-constant WASTE_TYPE_RECYCLABLE u2)
(define-constant WASTE_TYPE_HAZARDOUS u3)
(define-constant WASTE_TYPE_GENERAL u4)

;; Collection status types
(define-constant STATUS_SCHEDULED u1)
(define-constant STATUS_IN_PROGRESS u2)
(define-constant STATUS_COMPLETED u3)
(define-constant STATUS_CANCELLED u4)

;; Validation constants
(define-constant MAX_COLLECTION_ID u1000000)
(define-constant MAX_STRING_LENGTH u100)
(define-constant MIN_STRING_LENGTH u1)

;; Contract variables
(define-data-var contract-active bool true)
(define-data-var collection-counter uint u0)
(define-data-var total-collections uint u0)
(define-data-var total-rewards-paid uint u0)

;; Maps for data storage
(define-map waste-generators 
  { generator-id: principal } 
  { 
    name: (string-ascii 50),
    location: (string-ascii 100),
    total-waste: uint,
    total-paid: uint,
    reputation-score: uint,
    active: bool,
    registration-block: uint
  })

(define-map waste-collectors 
  { collector-id: principal } 
  { 
    name: (string-ascii 50),
    license-number: (string-ascii 30),
    service-area: (string-ascii 100),
    total-collected: uint,
    total-earned: uint,
    reputation-score: uint,
    active: bool,
    registration-block: uint
  })

(define-map waste-collections 
  { collection-id: uint } 
  { 
    generator-id: principal,
    collector-id: (optional principal),
    waste-type: uint,
    weight: uint,
    location: (string-ascii 100),
    scheduled-block: uint,
    completion-block: (optional uint),
    payment-amount: uint,
    status: uint,
    verified: bool,
    created-block: uint
  })

(define-map waste-type-pricing 
  { waste-type: uint } 
  { 
    price-per-kg: uint,
    bonus-multiplier: uint,
    active: bool
  })

(define-map collector-balances 
  { collector-id: principal } 
  { balance: uint })

(define-map generator-deposits 
  { generator-id: principal } 
  { balance: uint })

(define-map collection-verifiers 
  { verifier-id: principal } 
  { 
    name: (string-ascii 50),
    verification-count: uint,
    active: bool
  })

;; Initialize waste type pricing
(map-set waste-type-pricing 
  { waste-type: WASTE_TYPE_ORGANIC }
  { price-per-kg: u50, bonus-multiplier: u120, active: true })

(map-set waste-type-pricing 
  { waste-type: WASTE_TYPE_RECYCLABLE }
  { price-per-kg: u75, bonus-multiplier: u150, active: true })

(map-set waste-type-pricing 
  { waste-type: WASTE_TYPE_HAZARDOUS }
  { price-per-kg: u200, bonus-multiplier: u200, active: true })

(map-set waste-type-pricing 
  { waste-type: WASTE_TYPE_GENERAL }
  { price-per-kg: u25, bonus-multiplier: u100, active: true })

;; Validation helper functions
(define-private (is-valid-string (input (string-ascii 100)))
  (and (>= (len input) MIN_STRING_LENGTH) (<= (len input) MAX_STRING_LENGTH)))

(define-private (is-valid-string-50 (input (string-ascii 50)))
  (and (>= (len input) u1) (<= (len input) u50)))

(define-private (is-valid-collection-id (collection-id uint))
  (and (> collection-id u0) (<= collection-id MAX_COLLECTION_ID)))

(define-private (is-valid-waste-type (waste-type uint))
  (and (>= waste-type WASTE_TYPE_ORGANIC) (<= waste-type WASTE_TYPE_GENERAL)))

(define-private (is-valid-status (status uint))
  (and (>= status STATUS_SCHEDULED) (<= status STATUS_CANCELLED)))

(define-private (is-valid-principal (principal-to-check principal))
  (and 
    (not (is-eq principal-to-check 'SP000000000000000000002Q6VF78)) ;; Not zero address
    (not (is-eq principal-to-check CONTRACT_OWNER)))) ;; Not contract owner

(define-private (sanitize-location (location (string-ascii 100)))
  (let ((location-len (len location)))
    (if (and (>= location-len MIN_STRING_LENGTH) (<= location-len MAX_STRING_LENGTH))
      location
      "INVALID_LOCATION")))

;; Read-only functions
(define-read-only (get-contract-info)
  {
    active: (var-get contract-active),
    total-collections: (var-get total-collections),
    total-rewards-paid: (var-get total-rewards-paid),
    collection-counter: (var-get collection-counter)
  })

(define-read-only (get-waste-generator (generator-id principal))
  (map-get? waste-generators { generator-id: generator-id }))

(define-read-only (get-waste-collector (collector-id principal))
  (map-get? waste-collectors { collector-id: collector-id }))

(define-read-only (get-waste-collection (collection-id uint))
  (if (is-valid-collection-id collection-id)
    (map-get? waste-collections { collection-id: collection-id })
    none))

(define-read-only (get-waste-type-pricing (waste-type uint))
  (map-get? waste-type-pricing { waste-type: waste-type }))

(define-read-only (get-collector-balance (collector-id principal))
  (default-to u0 (get balance (map-get? collector-balances { collector-id: collector-id }))))

(define-read-only (get-generator-deposit (generator-id principal))
  (default-to u0 (get balance (map-get? generator-deposits { generator-id: generator-id }))))

(define-read-only (calculate-collection-payment (waste-type uint) (weight uint))
  (if (is-valid-waste-type waste-type)
    (let ((pricing (map-get? waste-type-pricing { waste-type: waste-type })))
      (match pricing
        pricing-data (ok (* (get price-per-kg pricing-data) weight))
        ERR_INVALID_WASTE_TYPE))
    ERR_INVALID_WASTE_TYPE))

(define-read-only (is-collection-expired (collection-id uint))
  (if (is-valid-collection-id collection-id)
    (match (map-get? waste-collections { collection-id: collection-id })
      collection-data 
        (let ((scheduled-block (get scheduled-block collection-data)))
          (> block-height (+ scheduled-block u144))) ;; 24 hours in blocks
      false)
    false))

;; Public functions

;; Register as waste generator
(define-public (register-waste-generator (name (string-ascii 50)) (location (string-ascii 100)))
  (let ((generator-id tx-sender))
    (asserts! (is-none (map-get? waste-generators { generator-id: generator-id })) ERR_ALREADY_EXISTS)
    (asserts! (is-valid-string name) ERR_INVALID_INPUT)
    (asserts! (is-valid-string location) ERR_INVALID_INPUT)
    (map-set waste-generators 
      { generator-id: generator-id }
      { 
        name: name,
        location: location,
        total-waste: u0,
        total-paid: u0,
        reputation-score: u100,
        active: true,
        registration-block: block-height
      })
    (ok generator-id)))

;; Register as waste collector
(define-public (register-waste-collector (name (string-ascii 50)) (license-number (string-ascii 30)) (service-area (string-ascii 100)))
  (let ((collector-id tx-sender))
    (asserts! (is-none (map-get? waste-collectors { collector-id: collector-id })) ERR_ALREADY_EXISTS)
    (asserts! (is-valid-string name) ERR_INVALID_INPUT)
    (asserts! (and (>= (len license-number) u1) (<= (len license-number) u30)) ERR_INVALID_INPUT)
    (asserts! (is-valid-string service-area) ERR_INVALID_INPUT)
    (map-set waste-collectors 
      { collector-id: collector-id }
      { 
        name: name,
        license-number: license-number,
        service-area: service-area,
        total-collected: u0,
        total-earned: u0,
        reputation-score: u100,
        active: true,
        registration-block: block-height
      })
    (ok collector-id)))

;; Deposit funds for waste collection payments
(define-public (deposit-funds (amount uint))
  (let ((generator-id tx-sender))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-some (map-get? waste-generators { generator-id: generator-id })) ERR_NOT_FOUND)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set generator-deposits 
      { generator-id: generator-id }
      { balance: (+ (get-generator-deposit generator-id) amount) })
    (ok amount)))

;; Schedule waste collection
(define-public (schedule-waste-collection 
    (waste-type uint) 
    (weight uint) 
    (location (string-ascii 100)) 
    (scheduled-block uint))
  (let (
    (collection-id (+ (var-get collection-counter) u1))
    (generator-id tx-sender)
    (safe-location (sanitize-location location))
  )
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? waste-generators { generator-id: generator-id })) ERR_NOT_FOUND)
    (asserts! (> weight u0) ERR_INVALID_AMOUNT)
    (asserts! (> scheduled-block block-height) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-waste-type waste-type) ERR_INVALID_WASTE_TYPE)
    (asserts! (is-valid-collection-id collection-id) ERR_INVALID_INPUT)
    (asserts! (is-valid-string location) ERR_INVALID_INPUT)
    
    (let (
      (payment-amount (try! (calculate-collection-payment waste-type weight)))
      (generator-balance (get-generator-deposit generator-id))
    )
      (asserts! (>= generator-balance payment-amount) ERR_INSUFFICIENT_BALANCE)
      
      ;; Create collection record with validated location
      (map-set waste-collections 
        { collection-id: collection-id }
        { 
          generator-id: generator-id,
          collector-id: none,
          waste-type: waste-type,
          weight: weight,
          location: safe-location,
          scheduled-block: scheduled-block,
          completion-block: none,
          payment-amount: payment-amount,
          status: STATUS_SCHEDULED,
          verified: false,
          created-block: block-height
        })
      
      ;; Reserve funds from generator deposit
      (map-set generator-deposits 
        { generator-id: generator-id }
        { balance: (- generator-balance payment-amount) })
      
      ;; Update counters
      (var-set collection-counter collection-id)
      (var-set total-collections (+ (var-get total-collections) u1))
      
      (ok collection-id))))

;; Accept waste collection job
(define-public (accept-waste-collection (collection-id uint))
  (let ((collector-id tx-sender))
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? waste-collectors { collector-id: collector-id })) ERR_NOT_FOUND)
    (asserts! (is-valid-collection-id collection-id) ERR_INVALID_INPUT)
    
    (let ((collection-data (unwrap! (map-get? waste-collections { collection-id: collection-id }) ERR_NOT_FOUND)))
      (asserts! (is-eq (get status collection-data) STATUS_SCHEDULED) ERR_INVALID_STATUS)
      (asserts! (is-none (get collector-id collection-data)) ERR_ALREADY_EXISTS)
      (asserts! (not (is-collection-expired collection-id)) ERR_EXPIRED_COLLECTION)
      
      ;; Update collection with collector info
      (map-set waste-collections 
        { collection-id: collection-id }
        (merge collection-data {
          collector-id: (some collector-id),
          status: STATUS_IN_PROGRESS
        }))
      
      (ok collection-id))))

;; Complete waste collection
(define-public (complete-waste-collection (collection-id uint))
  (let ((collector-id tx-sender))
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (is-valid-collection-id collection-id) ERR_INVALID_INPUT)
    
    (let (
      (collection-data (unwrap! (map-get? waste-collections { collection-id: collection-id }) ERR_NOT_FOUND))
      (assigned-collector (unwrap! (get collector-id collection-data) ERR_UNAUTHORIZED))
    )
      (asserts! (is-eq collector-id assigned-collector) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status collection-data) STATUS_IN_PROGRESS) ERR_INVALID_STATUS)
      
      ;; Update collection status
      (map-set waste-collections 
        { collection-id: collection-id }
        (merge collection-data {
          status: STATUS_COMPLETED,
          completion-block: (some block-height)
        }))
      
      (ok collection-id))))

;; Verify and process payment for completed collection
(define-public (verify-and-pay-collection (collection-id uint))
  (let ((verifier-id tx-sender))
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (is-valid-collection-id collection-id) ERR_INVALID_INPUT)
    (asserts! (or (is-eq verifier-id CONTRACT_OWNER) 
                  (is-some (map-get? collection-verifiers { verifier-id: verifier-id }))) ERR_UNAUTHORIZED)
    
    (let (
      (collection-data (unwrap! (map-get? waste-collections { collection-id: collection-id }) ERR_NOT_FOUND))
      (collector-id (unwrap! (get collector-id collection-data) ERR_NOT_FOUND))
      (generator-id (get generator-id collection-data))
      (payment-amount (get payment-amount collection-data))
      (waste-type (get waste-type collection-data))
      (weight (get weight collection-data))
    )
      (asserts! (is-eq (get status collection-data) STATUS_COMPLETED) ERR_INVALID_STATUS)
      (asserts! (not (get verified collection-data)) ERR_ALREADY_EXISTS)
      
      ;; Calculate bonus payment
      (let (
        (pricing (unwrap! (map-get? waste-type-pricing { waste-type: waste-type }) ERR_INVALID_WASTE_TYPE))
        (bonus-amount (/ (* payment-amount (get bonus-multiplier pricing)) u100))
        (total-payment (+ payment-amount bonus-amount))
        (current-collector-balance (get-collector-balance collector-id))
      )
        
        ;; Transfer payment to collector
        (try! (as-contract (stx-transfer? total-payment tx-sender collector-id)))
        
        ;; Update collector balance
        (map-set collector-balances 
          { collector-id: collector-id }
          { balance: (+ current-collector-balance total-payment) })
        
        ;; Mark collection as verified
        (map-set waste-collections 
          { collection-id: collection-id }
          (merge collection-data { verified: true }))
        
        ;; Update collector stats
        (match (map-get? waste-collectors { collector-id: collector-id })
          collector-data
          (map-set waste-collectors 
            { collector-id: collector-id }
            (merge collector-data {
              total-collected: (+ (get total-collected collector-data) weight),
              total-earned: (+ (get total-earned collector-data) total-payment)
            }))
          false)
        
        ;; Update generator stats
        (match (map-get? waste-generators { generator-id: generator-id })
          generator-data
          (map-set waste-generators 
            { generator-id: generator-id }
            (merge generator-data {
              total-waste: (+ (get total-waste generator-data) weight),
              total-paid: (+ (get total-paid generator-data) total-payment)
            }))
          false)
        
        ;; Update contract stats
        (var-set total-rewards-paid (+ (var-get total-rewards-paid) total-payment))
        
        ;; Update verifier stats if applicable
        (match (map-get? collection-verifiers { verifier-id: verifier-id })
          verifier-data
          (map-set collection-verifiers 
            { verifier-id: verifier-id }
            (merge verifier-data {
              verification-count: (+ (get verification-count verifier-data) u1)
            }))
          false)
        
        (ok total-payment)))))

;; Cancel scheduled collection
(define-public (cancel-waste-collection (collection-id uint))
  (begin
    (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
    (asserts! (is-valid-collection-id collection-id) ERR_INVALID_INPUT)
    
    (let (
      (collection-data (unwrap! (map-get? waste-collections { collection-id: collection-id }) ERR_NOT_FOUND))
      (generator-id (get generator-id collection-data))
      (payment-amount (get payment-amount collection-data))
    )
      (asserts! (or (is-eq tx-sender generator-id) 
                    (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
      (asserts! (or (is-eq (get status collection-data) STATUS_SCHEDULED)
                    (is-eq (get status collection-data) STATUS_IN_PROGRESS)) ERR_INVALID_STATUS)
      
      ;; Refund reserved payment to generator
      (map-set generator-deposits 
        { generator-id: generator-id }
        { balance: (+ (get-generator-deposit generator-id) payment-amount) })
      
      ;; Update collection status
      (map-set waste-collections 
        { collection-id: collection-id }
        (merge collection-data { status: STATUS_CANCELLED }))
      
      (ok collection-id))))

;; Withdraw funds for collectors
(define-public (withdraw-funds (amount uint))
  (let (
    (collector-id tx-sender)
    (current-balance (get-collector-balance collector-id))
  )
    (asserts! (is-some (map-get? waste-collectors { collector-id: collector-id })) ERR_NOT_FOUND)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount current-balance) ERR_INSUFFICIENT_BALANCE)
    
    ;; Transfer funds to collector
    (try! (as-contract (stx-transfer? amount tx-sender collector-id)))
    
    ;; Update collector balance
    (map-set collector-balances 
      { collector-id: collector-id }
      { balance: (- current-balance amount) })
    
    (ok amount)))

;; Admin functions

;; Add collection verifier (Admin only) - FIXED VERSION
(define-public (add-collection-verifier (verifier-id principal) (name (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal verifier-id) ERR_INVALID_INPUT)
    (asserts! (is-none (map-get? collection-verifiers { verifier-id: verifier-id })) ERR_ALREADY_EXISTS)
    (asserts! (is-valid-string-50 name) ERR_INVALID_INPUT)
    (map-set collection-verifiers 
      { verifier-id: verifier-id }
      { name: name, verification-count: u0, active: true })
    (ok verifier-id)))

;; Update waste type pricing (Admin only)
(define-public (update-waste-type-pricing (waste-type uint) (price-per-kg uint) (bonus-multiplier uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-valid-waste-type waste-type) ERR_INVALID_WASTE_TYPE)
    (asserts! (> price-per-kg u0) ERR_INVALID_AMOUNT)
    (asserts! (>= bonus-multiplier u100) ERR_INVALID_AMOUNT)
    (map-set waste-type-pricing 
      { waste-type: waste-type }
      { price-per-kg: price-per-kg, bonus-multiplier: bonus-multiplier, active: true })
    (ok waste-type)))

;; Toggle contract active status (Admin only)
(define-public (toggle-contract-status)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-active (not (var-get contract-active)))
    (ok (var-get contract-active))))

;; Emergency withdrawal (Admin only)
(define-public (emergency-withdrawal (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
    (ok amount)))