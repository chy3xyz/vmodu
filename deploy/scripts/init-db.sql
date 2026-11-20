-- VModu Runtime Database Initialization
-- Run on PostgreSQL startup

-- ═══════════════════════════════════════════════════════════════
-- Create Extensions
-- ═══════════════════════════════════════════════════════════════
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ═══════════════════════════════════════════════════════════════
-- Event Store Schema
-- ═══════════════════════════════════════════════════════════════
CREATE SCHEMA IF NOT EXISTS event_store;

CREATE TABLE IF NOT EXISTS event_store.events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    aggregate_id VARCHAR(255) NOT NULL,
    aggregate_type VARCHAR(100) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    event_version INTEGER NOT NULL DEFAULT 1,
    payload JSONB NOT NULL,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sequence_number BIGSERIAL
);

CREATE INDEX idx_events_aggregate ON event_store.events(aggregate_id, aggregate_type);
CREATE INDEX idx_events_type ON event_store.events(event_type);
CREATE INDEX idx_events_created ON event_store.events(created_at);

-- ═══════════════════════════════════════════════════════════════
-- Actor State Schema
-- ═══════════════════════════════════════════════════════════════
CREATE SCHEMA IF NOT EXISTS actor;

CREATE TABLE IF NOT EXISTS actor.snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_id VARCHAR(255) NOT NULL UNIQUE,
    actor_type VARCHAR(100) NOT NULL,
    state JSONB NOT NULL,
    version INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_snapshots_actor ON actor.snapshots(actor_id);

-- ═══════════════════════════════════════════════════════════════
-- Cluster Schema
-- ═══════════════════════════════════════════════════════════════
CREATE SCHEMA IF NOT EXISTS cluster;

CREATE TABLE IF NOT EXISTS cluster.nodes (
    id VARCHAR(255) PRIMARY KEY,
    hostname VARCHAR(255) NOT NULL,
    address VARCHAR(255) NOT NULL,
    port INTEGER NOT NULL DEFAULT 9000,
    status VARCHAR(50) DEFAULT 'active',
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cluster.shards (
    id VARCHAR(255) PRIMARY KEY,
    node_id VARCHAR(255) REFERENCES cluster.nodes(id),
    key_range_start VARCHAR(255),
    key_range_end VARCHAR(255),
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════
-- Metrics Schema
-- ═══════════════════════════════════════════════════════════════
CREATE SCHEMA IF NOT EXISTS metrics;

CREATE TABLE IF NOT EXISTS metrics.time_series (
    id BIGSERIAL PRIMARY KEY,
    metric_name VARCHAR(255) NOT NULL,
    labels JSONB,
    value DOUBLE PRECISION NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_metrics_name ON metrics.time_series(metric_name);
CREATE INDEX idx_metrics_time ON metrics.time_series(timestamp);

-- ═══════════════════════════════════════════════════════════════
-- Scheduler Schema
-- ═══════════════════════════════════════════════════════════════
CREATE SCHEMA IF NOT EXISTS scheduler;

CREATE TABLE IF NOT EXISTS scheduler.jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    cron_expression VARCHAR(100),
    next_run_at TIMESTAMP WITH TIME ZONE,
    last_run_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(50) DEFAULT 'pending',
    payload JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_jobs_next_run ON scheduler.jobs(next_run_at) WHERE status = 'pending';

-- ═══════════════════════════════════════════════════════════════
-- Audit Log
-- ═══════════════════════════════════════════════════════════════
CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE IF NOT EXISTS audit.logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100),
    resource_id VARCHAR(255),
    old_value JSONB,
    new_value JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_audit_user ON audit.logs(user_id);
CREATE INDEX idx_audit_resource ON audit.logs(resource_type, resource_id);
CREATE INDEX idx_audit_created ON audit.logs(created_at);

-- ═══════════════════════════════════════════════════════════════
-- Create Application User (if not exists)
-- ═══════════════════════════════════════════════════════════════
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'vmodu_app') THEN
        CREATE ROLE vmodu_app WITH LOGIN PASSWORD 'vmodu_app_password';
    END IF;
END
$$;

-- Grant permissions
GRANT USAGE ON SCHEMA event_store TO vmodu_app;
GRANT USAGE ON SCHEMA actor TO vmodu_app;
GRANT USAGE ON SCHEMA cluster TO vmodu_app;
GRANT USAGE ON SCHEMA metrics TO vmodu_app;
GRANT USAGE ON SCHEMA scheduler TO vmodu_app;
GRANT USAGE ON SCHEMA audit TO vmodu_app;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA event_store TO vmodu_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA actor TO vmodu_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cluster TO vmodu_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA metrics TO vmodu_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA scheduler TO vmodu_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA audit TO vmodu_app;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA event_store TO vmodu_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA actor TO vmodu_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA cluster TO vmodu_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA metrics TO vmodu_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA scheduler TO vmodu_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA audit TO vmodu_app;
