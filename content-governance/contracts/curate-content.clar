;; Content Curation Smart Contract

;; Define constants
(define-constant CONTRACT_ADMIN tx-sender)
(define-constant ERROR_NOT_AUTHORIZED (err u100))
(define-constant ERROR_INVALID_CONTENT_SUBMISSION (err u101))
(define-constant ERROR_CONTENT_EXISTS (err u102))
(define-constant ERROR_CONTENT_NOT_FOUND (err u103))
(define-constant ERROR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERROR_INVALID_CONTENT_CATEGORY (err u105))
(define-constant ERROR_INVALID_REPORT (err u106))
(define-constant ERROR_NUMERIC_OVERFLOW (err u107))
(define-constant ERROR_INVALID_VOTE (err u108))
(define-constant ERROR_INVALID_CONTENT_ID (err u109))
(define-constant MINIMUM_URL_LENGTH u10)
(define-constant MAXIMUM_UINT_VALUE u340282366920938463463374607431768211455)

;; Define data variables
(define-data-var content_submission_fee uint u10)
(define-data-var total_content_count uint u0)
(define-data-var available_categories (list 10 (string-ascii 20)) (list "Technology" "Science" "Art" "Politics" "Sports"))

;; Define data maps
(define-map content_database 
  { content_id: uint } 
  { 
    content_creator: principal, 
    content_title: (string-ascii 100), 
    content_url: (string-ascii 200), 
    content_category: (string-ascii 20),
    submission_block_height: uint, 
    vote_count: int,
    tip_amount: uint,
    report_count: uint
  }
)

(define-map user_votes 
  { voter: principal, content_id: uint } 
  { vote_value: int }
)

(define-map user_reputation
  { user_address: principal }
  { reputation_score: int }
)

;; Helper function to check if content exists
(define-private (content-exists (content_id uint))
  (is-some (map-get? content_database { content_id: content_id }))
)

;; Public functions

;; Submit new content for curation
(define-public (submit-content (content_title (string-ascii 100)) (content_url (string-ascii 200)) (content_category (string-ascii 20)))
  (let
    (
      (new_content_id (+ (var-get total_content_count) u1))
    )
    (asserts! (and 
                (>= (len content_title) u1)
                (>= (len content_url) MINIMUM_URL_LENGTH)
                (>= (len content_category) u1)
              ) ERROR_INVALID_CONTENT_SUBMISSION)
    (asserts! (> new_content_id (var-get total_content_count)) ERROR_NUMERIC_OVERFLOW)
    (asserts! (is-some (index-of (var-get available_categories) content_category)) ERROR_INVALID_CONTENT_CATEGORY)
    (asserts! (>= (stx-get-balance tx-sender) (var-get content_submission_fee)) ERROR_INSUFFICIENT_FUNDS)
    (try! (stx-transfer? (var-get content_submission_fee) tx-sender CONTRACT_ADMIN))
    (map-set content_database
      { content_id: new_content_id }
      {
        content_creator: tx-sender,
        content_title: content_title,
        content_url: content_url,
        content_category: content_category,
        submission_block_height: block-height,
        vote_count: 0,
        tip_amount: u0,
        report_count: u0
      }
    )
    (var-set total_content_count new_content_id)
    (print { event_type: "content-submitted", content_id: new_content_id, creator: tx-sender })
    (ok new_content_id)
  )
)

;; Vote on curated content
(define-public (vote-on-content (content_id uint) (vote_value int))
  (let
    (
      (previous_vote (default-to 0 (get vote_value (map-get? user_votes { voter: tx-sender, content_id: content_id }))))
      (target_content (unwrap! (map-get? content_database { content_id: content_id }) ERROR_CONTENT_NOT_FOUND))
      (voter_reputation (default-to { reputation_score: 0 } (map-get? user_reputation { user_address: tx-sender })))
    )
    (asserts! (content-exists content_id) ERROR_CONTENT_NOT_FOUND)
    (asserts! (or (is-eq vote_value 1) (is-eq vote_value -1)) ERROR_INVALID_VOTE)
    (map-set user_votes
      { voter: tx-sender, content_id: content_id }
      { vote_value: vote_value }
    )
    (map-set content_database
      { content_id: content_id }
      (merge target_content { vote_count: (+ (get vote_count target_content) (- vote_value previous_vote)) })
    )
    (map-set user_reputation
      { user_address: tx-sender }
      { reputation_score: (+ (get reputation_score voter_reputation) vote_value) }
    )
    (print { event_type: "vote-cast", content_id: content_id, voter: tx-sender, vote_value: vote_value })
    (ok true)
  )
)

;; Tip content creator
(define-public (send-tip (content_id uint) (tip_amount uint))
  (let
    (
      (target_content (unwrap! (map-get? content_database { content_id: content_id }) ERROR_CONTENT_NOT_FOUND))
    )
    (asserts! (content-exists content_id) ERROR_CONTENT_NOT_FOUND)
    (asserts! (>= (stx-get-balance tx-sender) tip_amount) ERROR_INSUFFICIENT_FUNDS)
    ;; Update state before transfer
    (map-set content_database
      { content_id: content_id }
      (merge target_content { tip_amount: (+ (get tip_amount target_content) tip_amount) })
    )
    ;; Perform transfer last
    (try! (stx-transfer? tip_amount tx-sender (get content_creator target_content)))
    (print { event_type: "tip-sent", content_id: content_id, tipper: tx-sender, recipient: (get content_creator target_content), amount: tip_amount })
    (ok true)
  )
)

;; Report content
(define-public (report-content (content_id uint))
  (let
    (
      (target_content (unwrap! (map-get? content_database { content_id: content_id }) ERROR_CONTENT_NOT_FOUND))
    )
    (asserts! (content-exists content_id) ERROR_CONTENT_NOT_FOUND)
    (asserts! (not (is-eq (get content_creator target_content) tx-sender)) ERROR_INVALID_REPORT)
    (map-set content_database
      { content_id: content_id }
      (merge target_content { report_count: (+ (get report_count target_content) u1) })
    )
    (print { event_type: "content-reported", content_id: content_id, reporter: tx-sender })
    (ok true)
  )
)

;; Get content details
(define-read-only (get-content-details (content_id uint))
  (map-get? content_database { content_id: content_id })
)

;; Get user's vote on specific content
(define-read-only (get-user-vote (voter_address principal) (content_id uint))
  (get vote_value (map-get? user_votes { voter: voter_address, content_id: content_id }))
)

;; Get total number of curated content
(define-read-only (get-total-content-count)
  (var-get total_content_count)
)

;; Get user reputation
(define-read-only (get-user-reputation (user_address principal))
  (default-to { reputation_score: 0 } (map-get? user_reputation { user_address: user_address }))
)

;; Get top content (limited by number of items)
(define-read-only (get-top-content (limit uint))
  (let
    (
      (total_items (var-get total_content_count))
      (actual_limit (if (> limit total_items) total_items limit))
    )
    (filter remove-none-values
      (map get-valid-content (get-content-ids actual_limit))
    )
  )
)

(define-private (remove-none-values (content_item (optional {
    content_creator: principal, 
    content_title: (string-ascii 100), 
    content_url: (string-ascii 200), 
    content_category: (string-ascii 20),
    submission_block_height: uint, 
    vote_count: int,
    tip_amount: uint,
    report_count: uint
  })))
  (is-some content_item)
)

(define-private (get-valid-content (content_id uint))
  (match (map-get? content_database { content_id: content_id })
    content_item (if (>= (get vote_count content_item) 0) (some content_item) none)
    none
  )
)

;; Updated get-content-ids function
(define-read-only (get-content-ids (count uint))
  (filter is-valid-id (generate-sequence count))
)

;; Updated generate-sequence function
(define-private (generate-sequence (n uint))
  (let ((sequence_limit (if (> n u10) u10 n)))
    (list
      (if (>= sequence_limit u1) u1 u0)
      (if (>= sequence_limit u2) u2 u0)
      (if (>= sequence_limit u3) u3 u0)
      (if (>= sequence_limit u4) u4 u0)
      (if (>= sequence_limit u5) u5 u0)
      (if (>= sequence_limit u6) u6 u0)
      (if (>= sequence_limit u7) u7 u0)
      (if (>= sequence_limit u8) u8 u0)
      (if (>= sequence_limit u9) u9 u0)
      (if (>= sequence_limit u10) u10 u0)
    )
  )
)

;; Helper function to filter out zero values
(define-private (is-valid-id (id uint))
  (not (is-eq id u0))
)

;; Admin functions

;; Set submission fee
(define-public (update-submission-fee (new_fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_ADMIN) ERROR_NOT_AUTHORIZED)
    (asserts! (<= new_fee MAXIMUM_UINT_VALUE) ERROR_NUMERIC_OVERFLOW)
    (var-set content_submission_fee new_fee)
    (print { event_type: "fee-updated", new_fee: new_fee })
    (ok true)
  )
)

;; Remove content (only by contract owner)
(define-public (remove-content (content_id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_ADMIN) ERROR_NOT_AUTHORIZED)
    (asserts! (content-exists content_id) ERROR_CONTENT_NOT_FOUND)
    (map-delete content_database { content_id: content_id })
    (print { event_type: "content-removed", content_id: content_id })
    (ok true)
  )
)

;; Add new category
(define-public (add-category (new_category (string-ascii 20)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_ADMIN) ERROR_NOT_AUTHORIZED)
    (asserts! (< (len (var-get available_categories)) u10) ERROR_INVALID_CONTENT_CATEGORY)
    (asserts! (>= (len new_category) u1) ERROR_INVALID_CONTENT_CATEGORY)
    (var-set available_categories (unwrap-panic (as-max-len? (append (var-get available_categories) new_category) u10)))
    (print { event_type: "category-added", category: new_category })
    (ok true)
  )
)