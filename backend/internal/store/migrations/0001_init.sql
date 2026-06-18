-- +goose Up
CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE refresh_tokens (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked    BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE subscriptions (
    user_id      UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    plan         TEXT NOT NULL DEFAULT 'free',
    status       TEXT NOT NULL DEFAULT 'active',
    expires_at   TIMESTAMPTZ,
    device_limit INT NOT NULL DEFAULT 1
);

CREATE TABLE devices (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name         TEXT NOT NULL,
    platform     TEXT NOT NULL,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE nodes (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kind       TEXT NOT NULL CHECK (kind IN ('shared','dedicated')),
    region     TEXT NOT NULL,
    city       TEXT NOT NULL,
    latency_ms INT NOT NULL,
    load       REAL NOT NULL,
    tier       TEXT,                 -- shared only
    label      TEXT,                 -- dedicated only
    static_ip  TEXT,                 -- dedicated only
    expires_at TIMESTAMPTZ,          -- dedicated only
    owner_id   UUID REFERENCES users(id) ON DELETE CASCADE -- null = shared
);

-- +goose Down
DROP TABLE nodes;
DROP TABLE devices;
DROP TABLE subscriptions;
DROP TABLE refresh_tokens;
DROP TABLE users;
