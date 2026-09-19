import os

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from .auth import hash_password, token_for, verify_password
from .db import get_pool

router = APIRouter(prefix='/auth', tags=['secure-auth'])


class OwnerLoginIn(BaseModel):
    email: str
    password: str = Field(min_length=6, max_length=128)
    second_password: str = Field(min_length=6, max_length=128)


@router.post('/owner-login')
async def owner_login(data: OwnerLoginIn, request: Request):
    configured_email = os.getenv('ADMIN_EMAIL', '').lower().strip()
    configured_password = os.getenv('ADMIN_PASSWORD', '')
    second_password = os.getenv('OWNER_SECOND_PASSWORD', '')

    if not configured_email or not configured_password or not second_password:
        raise HTTPException(503, 'Данные владельца не настроены')

    email = data.email.lower().strip()
    if email != configured_email or data.password != configured_password or data.second_password != second_password:
        raise HTTPException(401, 'Неверные данные владельца')

    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            '''SELECT id,email,role,blocked,password_hash
               FROM users WHERE email=$1''',
            email,
        )
        if not row:
            row = await conn.fetchrow(
                '''INSERT INTO users(email,password_hash,role)
                   VALUES($1,$2,'owner')
                   RETURNING id,email,role,blocked,password_hash''',
                email,
                hash_password(configured_password),
            )
        elif row['role'] != 'owner':
            row = await conn.fetchrow(
                '''UPDATE users SET role='owner',password_hash=$1,blocked=FALSE,last_login_at=NOW()
                   WHERE id=$2
                   RETURNING id,email,role,blocked,password_hash''',
                hash_password(configured_password),
                row['id'],
            )
        else:
            await conn.execute('UPDATE users SET last_login_at=NOW() WHERE id=$1', row['id'])

        if row['blocked']:
            raise HTTPException(403, 'Аккаунт владельца заблокирован')

        ip = request.client.host if request.client else 'unknown'
        user_agent = request.headers.get('user-agent', 'unknown')[:500]
        await conn.execute(
            '''INSERT INTO audit_logs(admin_id,action,target_type,target_id,details)
               VALUES($1,$2,$3,$4,$5)''',
            row['id'],
            'owner.login',
            'owner',
            row['id'],
            f'ip={ip}; user_agent={user_agent}',
        )

    return {
        'access_token': token_for(row['id'], 'owner'),
        'user': {
            'id': row['id'],
            'email': row['email'],
            'role': 'owner',
            'blocked': row['blocked'],
        },
    }
