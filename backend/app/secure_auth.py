import os

from fastapi import APIRouter, HTTPException, Request, Depends
from pydantic import BaseModel, Field

from .auth import hash_password, token_for, verify_password
from .db import get_pool
from .routes import current_user

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


class ApprovalLoginIn(BaseModel):
    email: str
    password: str = Field(min_length=6, max_length=128)
    device_id: str = Field(min_length=8, max_length=200)
    device_name: str = Field(default='Новое устройство', max_length=120)


@router.post('/login-secure')
async def login_secure(data: ApprovalLoginIn, request: Request):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            'SELECT id,email,password_hash,role,blocked FROM users WHERE email=$1',
            data.email.lower().strip(),
        )
        if not row or not verify_password(data.password, row['password_hash']):
            raise HTTPException(401, 'Неверный email или пароль')
        if row['blocked']:
            raise HTTPException(403, 'Аккаунт заблокирован')

        device = await conn.fetchrow(
            'SELECT id,trusted FROM auth_devices WHERE user_id=$1 AND device_id=$2',
            row['id'], data.device_id,
        )

        if device and device['trusted']:
            await conn.execute(
                'UPDATE auth_devices SET last_seen_at=NOW(),device_name=$1 WHERE id=$2',
                data.device_name, device['id'],
            )
            await conn.execute('UPDATE users SET last_login_at=NOW() WHERE id=$1', row['id'])
            return {
                'status': 'approved',
                'access_token': token_for(row['id'], row['role']),
                'user': {'id': row['id'], 'email': row['email'], 'role': row['role'], 'blocked': row['blocked']},
            }

        trusted_count = await conn.fetchval(
            'SELECT COUNT(*) FROM auth_devices WHERE user_id=$1 AND trusted=TRUE',
            row['id'],
        )

        if int(trusted_count or 0) == 0:
            await conn.execute(
                '''INSERT INTO auth_devices(user_id,device_id,device_name,trusted)
                   VALUES($1,$2,$3,TRUE)
                   ON CONFLICT(user_id,device_id)
                   DO UPDATE SET trusted=TRUE,last_seen_at=NOW(),device_name=EXCLUDED.device_name''',
                row['id'], data.device_id, data.device_name,
            )
            await conn.execute('UPDATE users SET last_login_at=NOW() WHERE id=$1', row['id'])
            return {
                'status': 'approved',
                'access_token': token_for(row['id'], row['role']),
                'user': {'id': row['id'], 'email': row['email'], 'role': row['role'], 'blocked': row['blocked']},
            }

        request_id = await conn.fetchval(
            '''INSERT INTO auth_requests(id,user_id,device_id,device_name,expires_at)
               VALUES(gen_random_uuid(),$1,$2,$3,NOW()+INTERVAL '5 minutes')
               RETURNING id''',
            row['id'], data.device_id, data.device_name,
        )
    return {
        'status': 'pending',
        'request_id': str(request_id),
        'message': 'Подтвердите вход на доверенном устройстве',
    }


class ApprovalDecisionIn(BaseModel):
    approved: bool


@router.get('/device-requests')
async def device_requests(user=Depends(current_user)):
    if user['role'] not in {'admin', 'owner', 'customer'}:
        raise HTTPException(403, 'Доступ запрещён')
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            '''SELECT id,device_id,device_name,created_at,expires_at
               FROM auth_requests
               WHERE user_id=$1 AND status='pending' AND expires_at>NOW()
               ORDER BY created_at DESC''',
            user['id'],
        )
    return [dict(r) for r in rows]


@router.post('/device-requests/{request_id}/decision')
async def decide_device_request(
    request_id: str,
    data: ApprovalDecisionIn,
    user=Depends(current_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        request_row = await conn.fetchrow(
            '''SELECT id,device_id,device_name FROM auth_requests
               WHERE id=$1 AND user_id=$2 AND status='pending' AND expires_at>NOW()''',
            request_id, user['id'],
        )
        if not request_row:
            raise HTTPException(404, 'Запрос не найден или истёк')

        if data.approved:
            await conn.execute(
                '''INSERT INTO auth_devices(user_id,device_id,device_name,trusted)
                   VALUES($1,$2,$3,TRUE)
                   ON CONFLICT(user_id,device_id)
                   DO UPDATE SET trusted=TRUE,last_seen_at=NOW(),device_name=EXCLUDED.device_name''',
                user['id'], request_row['device_id'], request_row['device_name'],
            )

        await conn.execute(
            '''UPDATE auth_requests SET status=$1,decided_at=NOW()
               WHERE id=$2''',
            'approved' if data.approved else 'denied',
            request_id,
        )
    return {'ok': True, 'status': 'approved' if data.approved else 'denied'}


@router.get('/device-status/{request_id}')
async def device_status(request_id: str):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            '''SELECT r.status,r.expires_at,u.id,u.email,u.role,u.blocked
               FROM auth_requests r JOIN users u ON u.id=r.user_id
               WHERE r.id=$1''',
            request_id,
        )
    if not row:
        raise HTTPException(404, 'Запрос не найден')
    if row['status'] == 'approved':
        return {
            'status': 'approved',
            'access_token': token_for(row['id'], row['role']),
            'user': {'id': row['id'], 'email': row['email'], 'role': row['role'], 'blocked': row['blocked']},
        }
    if row['status'] == 'denied':
        return {'status': 'denied'}
    if row['expires_at'].timestamp() <= __import__('time').time():
        return {'status': 'expired'}
    return {'status': 'pending'}
