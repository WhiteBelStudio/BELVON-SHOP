from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .db import get_pool
from .routes import router
from .secure_auth import router as secure_auth_router

APP_VERSION = '1.3.6'

app = FastAPI(title='BELVON SHOP API', version=APP_VERSION)
app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=False,
    allow_methods=['*'],
    allow_headers=['*'],
)
app.include_router(router)
app.include_router(secure_auth_router)


@app.get('/health')
async def health():
    return {'ok': True, 'service': 'belvon-shop-api', 'version': APP_VERSION}


@app.get('/health/ready')
async def health_ready():
    try:
        pool = await get_pool()
        async with pool.acquire() as conn:
            database_name = await conn.fetchval('SELECT current_database()')
            table_count = await conn.fetchval(
                """
                SELECT COUNT(*)
                FROM information_schema.tables
                WHERE table_schema='public' AND table_type='BASE TABLE'
                """
            )
        return {
            'ok': True,
            'service': 'belvon-shop-api',
            'version': APP_VERSION,
            'database': database_name,
            'tables': int(table_count or 0),
        }
    except Exception as exc:
        return JSONResponse(
            status_code=503,
            content={
                'ok': False,
                'service': 'belvon-shop-api',
                'version': APP_VERSION,
                'database': 'unavailable',
                'error_type': type(exc).__name__,
            },
        )
