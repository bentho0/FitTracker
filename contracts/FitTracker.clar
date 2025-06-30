;; FitTracker - Fitness challenge tracking and wellness rewards platform
(define-data-var fitness-coordinator principal tx-sender)
(define-data-var total-fitness-points uint u0)
(define-data-var wellness-multiplier uint u25) ;; wellness points per achievement
(define-data-var last-wellness-cycle uint u0)

(define-map participant-achievements principal uint)
(define-map fitness-categories principal (string-utf8 64))
(define-map approved-challenges (string-utf8 64) bool)

;; Error codes
(define-constant err-unauthorized-coordinator (err u1700))
(define-constant err-coordinator-already-set (err u1701))
(define-constant err-invalid-points (err u1702))
(define-constant err-no-wellness-rewards (err u1703))
(define-constant err-no-achievements (err u1704))
(define-constant err-invalid-challenge-category (err u1705))
(define-constant err-challenge-not-approved (err u1706))

;; Verify coordinator authorization
(define-private (is-fitness-coordinator (caller principal))
  (begin
    (asserts! (is-eq caller (var-get fitness-coordinator)) err-unauthorized-coordinator)
    (ok true)))

;; Initialize fitness challenge platform
(define-public (launch-fitness-platform (coordinator principal))
  (begin
    (asserts! (is-none (map-get? participant-achievements coordinator)) err-coordinator-already-set)
    (var-set fitness-coordinator coordinator)
    (ok "FitTracker fitness challenge platform launched")))

;; Approve fitness challenge category
(define-public (approve-challenge-category (category (string-utf8 64)))
  (begin
    (try! (is-fitness-coordinator tx-sender))
    (asserts! (> (len category) u0) err-invalid-challenge-category)
    (map-set approved-challenges category true)
    (ok "Fitness challenge category approved")))

;; Record fitness achievement progress
(define-public (record-fitness-progress (points uint) (challenge-category (string-utf8 64)))
  (begin
    (asserts! (> points u0) err-invalid-points)
    (asserts! (default-to false (map-get? approved-challenges challenge-category)) err-challenge-not-approved)
    
    (let ((current-achievements (default-to u0 (map-get? participant-achievements tx-sender))))
      (map-set participant-achievements tx-sender (+ current-achievements points))
      (map-set fitness-categories tx-sender challenge-category)
      (var-set total-fitness-points (+ (var-get total-fitness-points) points))
      (ok (+ current-achievements points)))))

;; Calculate wellness achievement bonuses
(define-public (calculate-wellness-bonuses)
  (begin
    (try! (is-fitness-coordinator tx-sender))
    (let ((current-cycle (+ (var-get last-wellness-cycle) u1))
          (total-points (var-get total-fitness-points)))
      (asserts! (> total-points (var-get last-wellness-cycle)) err-no-wellness-rewards)
      
      (let ((wellness-bonus-pool (* (var-get wellness-multiplier) total-points)))
        (var-set last-wellness-cycle current-cycle)
        (ok wellness-bonus-pool)))))

;; Complete fitness certification and claim rewards
(define-public (complete-fitness-certification)
  (begin
    (let ((participant-points (default-to u0 (map-get? participant-achievements tx-sender))))
      (asserts! (> participant-points u0) err-no-achievements)
      
      (let ((total-points (var-get total-fitness-points))
            (base-wellness-rewards (* (var-get wellness-multiplier) participant-points))
            (achievement-ratio (/ (* participant-points u100000) total-points)))
        
        (let ((final-wellness-rewards (/ (* achievement-ratio base-wellness-rewards) u100000)))
          (map-delete participant-achievements tx-sender)
          (map-delete fitness-categories tx-sender)
          (var-set total-fitness-points (- (var-get total-fitness-points) participant-points))
          (ok (+ participant-points final-wellness-rewards)))))))

;; Read-only functions
(define-read-only (get-participant-achievements (participant principal))
  (default-to u0 (map-get? participant-achievements participant)))

(define-read-only (get-fitness-category (participant principal))
  (map-get? fitness-categories participant))

(define-read-only (get-total-fitness-points)
  (var-get total-fitness-points))

(define-read-only (is-challenge-approved (category (string-utf8 64)))
  (default-to false (map-get? approved-challenges category)))