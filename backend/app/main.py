from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .routes import router

app = FastAPI(title='BELVON SHOP API', version='1.0.0')
app.add_middleware(CORSMiddleware, allow_origins=['*'], allow_credentials=False, allow_methods=['*'], allow_headers=['*'])
app.include_router(router)

@app.get('/health')
async def health():
    return {'ok': True, 'service': 'belvon-shop-api'}
