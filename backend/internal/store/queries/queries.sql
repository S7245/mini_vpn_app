-- name: CreateUser :one
INSERT INTO users (email, password_hash)
VALUES ($1, $2)
RETURNING id, email, created_at;

-- name: GetUserByEmail :one
SELECT id, email, password_hash, created_at FROM users WHERE email = $1;

-- name: GetUserByID :one
SELECT id, email, password_hash, created_at FROM users WHERE id = $1;

-- name: UpdatePassword :exec
UPDATE users SET password_hash = $2 WHERE id = $1;

-- name: CreateRefreshToken :exec
INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
VALUES ($1, $2, $3);

-- name: GetRefreshToken :one
SELECT id, user_id, token_hash, expires_at, revoked
FROM refresh_tokens WHERE token_hash = $1;

-- name: RevokeRefreshToken :exec
UPDATE refresh_tokens SET revoked = true WHERE token_hash = $1;

-- name: RevokeAllUserTokens :exec
UPDATE refresh_tokens SET revoked = true WHERE user_id = $1;

-- name: CreateSubscription :exec
INSERT INTO subscriptions (user_id, plan, status, expires_at, device_limit)
VALUES ($1, $2, $3, $4, $5);

-- name: GetSubscription :one
SELECT user_id, plan, status, expires_at, device_limit
FROM subscriptions WHERE user_id = $1;

-- name: GetSubscriptionForUpdate :one
SELECT user_id, plan, status, expires_at, device_limit
FROM subscriptions WHERE user_id = $1 FOR UPDATE;

-- name: ListDevices :many
SELECT id, user_id, name, platform, last_seen_at, created_at
FROM devices WHERE user_id = $1 ORDER BY created_at;

-- name: CountDevices :one
SELECT count(*) FROM devices WHERE user_id = $1;

-- name: CreateDevice :one
INSERT INTO devices (user_id, name, platform)
VALUES ($1, $2, $3)
RETURNING id, user_id, name, platform, last_seen_at, created_at;

-- name: DeleteDevice :exec
DELETE FROM devices WHERE id = $1 AND user_id = $2;

-- name: ListNodesForUser :many
SELECT id, kind, region, city, latency_ms, load, tier, label, static_ip, expires_at, owner_id
FROM nodes
WHERE owner_id IS NULL OR owner_id = $1
ORDER BY kind, latency_ms;

-- name: ListSharedNodesByScore :many
SELECT id, kind, region, city, latency_ms, load, tier, label, static_ip, expires_at, owner_id
FROM nodes
WHERE owner_id IS NULL
ORDER BY latency_ms ASC, load ASC
LIMIT 1;

-- name: SeedNode :exec
INSERT INTO nodes (kind, region, city, latency_ms, load, tier, label, static_ip, expires_at, owner_id)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10);
