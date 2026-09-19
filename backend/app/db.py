import os
import asyncpg

_pool = None
_schema_ready = False


async def get_pool():
    global _pool, _schema_ready
    if _pool is None:
        _pool = await asyncpg.create_pool(os.environ['DATABASE_URL'], min_size=1, max_size=5)

    if not _schema_ready:
        async with _pool.acquire() as conn:
            await conn.execute('ALTER TABLE users ADD COLUMN IF NOT EXISTS blocked BOOLEAN NOT NULL DEFAULT FALSE')
            await conn.execute('ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ')
            await conn.execute('ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check')
            await conn.execute("""
                DO $ BEGIN
                    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='users_role_check') THEN
                        ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('customer','admin','owner'));
                    END IF;
                END $;
            """)
            await conn.execute('''
                CREATE TABLE IF NOT EXISTS audit_logs (
                    id BIGSERIAL PRIMARY KEY,
                    admin_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
                    action TEXT NOT NULL,
                    target_type TEXT,
                    target_id BIGINT,
                    details TEXT NOT NULL DEFAULT '',
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
            ''')
            await conn.execute('''
                CREATE TABLE IF NOT EXISTS app_settings (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL DEFAULT '',
                    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
            ''')
            await conn.execute('CREATE INDEX IF NOT EXISTS idx_users_role ON users(role)')
            await conn.execute('CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC)')
        _schema_ready = True

    return _pool
