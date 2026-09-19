import os

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from .auth import decode_token, hash_password, token_for, verify_password
from .db import get_pool

router = APIRouter()


class AuthIn(BaseModel):
    email: str
    password: str = Field(min_length=6, max_length=128)


class ProductIn(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    description: str = ''
    category: str = 'Другое'
    price: float = Field(ge=0)
    image_url: str | None = None
    available: bool = True


class OrderItemIn(BaseModel):
    product_id: int
    quantity: int = Field(ge=1, le=100)


class OrderIn(BaseModel):
    items: list[OrderItemIn] = Field(min_length=1)


class RoleIn(BaseModel):
    role: str


class BlockIn(BaseModel):
    blocked: bool


class ReviewModerationIn(BaseModel):
    approved: bool


class SettingIn(BaseModel):
    value: str


class BootstrapIn(BaseModel):
    email: str
    password: str = Field(min_length=6, max_length=128)


async def current_user(authorization: str | None = Header(default=None)):
    if not authorization or not authorization.startswith('Bearer '):
        raise HTTPException(401, 'Требуется авторизация')

    token = decode_token(authorization[7:])
    user_id = int(token.get('sub', 0))
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            'SELECT id,email,role,blocked FROM users WHERE id=$1',
            user_id,
        )

    if not row:
        raise HTTPException(401, 'Пользователь не найден')
    if row['blocked']:
        raise HTTPException(403, 'Аккаунт заблокирован')

    return dict(row)


async def admin_user(user=Depends(current_user)):
    if user.get('role') not in {'admin', 'owner'}:
        raise HTTPException(403, 'Доступ только для администратора')
    return user


async def owner_user(user=Depends(current_user)):
    if user.get('role') != 'owner':
        raise HTTPException(403, 'Доступ только для владельца')
    return user


async def audit(admin_id: int, action: str, target_type: str = '', target_id: int | None = None, details: str = ''):
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            'INSERT INTO audit_logs(admin_id,action,target_type,target_id,details) VALUES($1,$2,$3,$4,$5)',
            admin_id, action, target_type, target_id, details,
        )


@router.post('/auth/register')
async def register(data: AuthIn):
    pool = await get_pool()
    async with pool.acquire() as conn:
        try:
            row = await conn.fetchrow(
                'INSERT INTO users(email,password_hash) VALUES($1,$2) RETURNING id,email,role,blocked',
                data.email.lower().strip(),
                hash_password(data.password),
            )
        except Exception as exc:
            if 'users_email_key' in str(exc):
                raise HTTPException(409, 'Email уже зарегистрирован') from exc
            raise

    return {
        'access_token': token_for(row['id'], row['role']),
        'user': dict(row),
    }


@router.post('/auth/login')
async def login(data: AuthIn):
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
        await conn.execute('UPDATE users SET last_login_at=NOW() WHERE id=$1', row['id'])

    return {
        'access_token': token_for(row['id'], row['role']),
        'user': {
            'id': row['id'],
            'email': row['email'],
            'role': row['role'],
            'blocked': row['blocked'],
        },
    }


@router.post('/auth/bootstrap-owner')
async def bootstrap_owner(data: BootstrapIn):
    configured_email = os.getenv('ADMIN_EMAIL', '').lower().strip()
    configured_password = os.getenv('ADMIN_PASSWORD', '')
    if not configured_email or not configured_password:
        raise HTTPException(503, 'ADMIN_EMAIL и ADMIN_PASSWORD не настроены')
    if data.email.lower().strip() != configured_email or data.password != configured_password:
        raise HTTPException(403, 'Неверные данные владельца')

    pool = await get_pool()
    async with pool.acquire() as conn:
        existing_owner = await conn.fetchval("SELECT id FROM users WHERE role='owner' LIMIT 1")
        if existing_owner:
            raise HTTPException(409, 'Владелец уже создан')

        row = await conn.fetchrow(
            '''INSERT INTO users(email,password_hash,role)
               VALUES($1,$2,'owner')
               ON CONFLICT(email) DO UPDATE SET role='owner',password_hash=EXCLUDED.password_hash,blocked=FALSE
               RETURNING id,email,role,blocked''',
            configured_email,
            hash_password(configured_password),
        )

    return {'access_token': token_for(row['id'], row['role']), 'user': dict(row)}


@router.get('/me')
async def me(user=Depends(current_user)):
    return user


@router.get('/products')
async def products():
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            'SELECT id,name,description,category,price,image_url,available FROM products WHERE available=TRUE ORDER BY id DESC'
        )
    return [dict(r) for r in rows]


@router.get('/admin/products')
async def admin_products(_=Depends(admin_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            'SELECT id,name,description,category,price,image_url,available,created_at,updated_at FROM products ORDER BY id DESC'
        )
    return [dict(r) for r in rows]


@router.post('/products')
async def create_product(data: ProductIn, user=Depends(admin_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            '''INSERT INTO products(name,description,category,price,image_url,available)
               VALUES($1,$2,$3,$4,$5,$6)
               RETURNING id,name,description,category,price,image_url,available''',
            data.name, data.description, data.category, data.price, data.image_url, data.available,
        )
    await audit(user['id'], 'product.create', 'product', row['id'], row['name'])
    return dict(row)


@router.patch('/products/{product_id}')
async def update_product(product_id: int, data: ProductIn, user=Depends(admin_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            '''UPDATE products SET name=$1,description=$2,category=$3,price=$4,image_url=$5,
               available=$6,updated_at=NOW() WHERE id=$7
               RETURNING id,name,description,category,price,image_url,available''',
            data.name, data.description, data.category, data.price, data.image_url, data.available, product_id,
        )
    if not row:
        raise HTTPException(404, 'Товар не найден')
    await audit(user['id'], 'product.update', 'product', product_id, row['name'])
    return dict(row)


@router.delete('/products/{product_id}')
async def delete_product(product_id: int, user=Depends(admin_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        result = await conn.execute('DELETE FROM products WHERE id=$1', product_id)
    if result == 'DELETE 0':
        raise HTTPException(404, 'Товар не найден')
    await audit(user['id'], 'product.delete', 'product', product_id)
    return {'ok': True}


@router.get('/orders')
async def orders(user=Depends(current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        if user['role'] in {'admin', 'owner'}:
            rows = await conn.fetch(
                '''SELECT o.id,o.user_id,u.email,o.total,o.status,o.created_at
                   FROM orders o JOIN users u ON u.id=o.user_id ORDER BY o.id DESC'''
            )
        else:
            rows = await conn.fetch(
                'SELECT id,user_id,total,status,created_at FROM orders WHERE user_id=$1 ORDER BY id DESC',
                user['id'],
            )
    return [dict(r) for r in rows]


@router.post('/orders')
async def create_order(data: OrderIn, user=Depends(current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.transaction():
            total = 0.0
            prepared = []
            for item in data.items:
                row = await conn.fetchrow(
                    'SELECT id,price FROM products WHERE id=$1 AND available=TRUE',
                    item.product_id,
                )
                if not row:
                    raise HTTPException(400, f'Товар {item.product_id} недоступен')
                total += float(row['price']) * item.quantity
                prepared.append((item.product_id, item.quantity, row['price']))

            order = await conn.fetchrow(
                'INSERT INTO orders(user_id,total) VALUES($1,$2) RETURNING id,user_id,total,status,created_at',
                user['id'], total,
            )
            for product_id, quantity, price in prepared:
                await conn.execute(
                    'INSERT INTO order_items(order_id,product_id,quantity,unit_price) VALUES($1,$2,$3,$4)',
                    order['id'], product_id, quantity, price,
                )
    return dict(order)


@router.patch('/orders/{order_id}/status')
async def order_status(order_id: int, status_value: str, user=Depends(admin_user)):
    if status_value not in {'new', 'processing', 'completed', 'cancelled'}:
        raise HTTPException(400, 'Недопустимый статус')
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            'UPDATE orders SET status=$1 WHERE id=$2 RETURNING id,user_id,total,status,created_at',
            status_value, order_id,
        )
    if not row:
        raise HTTPException(404, 'Заказ не найден')
    await audit(user['id'], 'order.status', 'order', order_id, status_value)
    return dict(row)


@router.get('/admin/dashboard')
async def admin_dashboard(_=Depends(admin_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        stats = await conn.fetchrow(
            '''SELECT
                 (SELECT COUNT(*) FROM users) AS users,
                 (SELECT COUNT(*) FROM users WHERE role IN ('admin','owner')) AS staff,
                 (SELECT COUNT(*) FROM products) AS products,
                 (SELECT COUNT(*) FROM products WHERE available=TRUE) AS active_products,
                 (SELECT COUNT(*) FROM orders) AS orders,
                 (SELECT COUNT(*) FROM orders WHERE status='new') AS new_orders,
                 (SELECT COALESCE(SUM(total),0) FROM orders WHERE status='completed') AS revenue,
                 (SELECT COUNT(*) FROM reviews) AS reviews,
                 (SELECT COUNT(*) FROM reviews WHERE approved=FALSE) AS pending_reviews'''
        )
    return dict(stats)


@router.get('/admin/users')
async def admin_users(_=Depends(admin_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            'SELECT id,email,role,blocked,created_at,last_login_at FROM users ORDER BY id DESC'
        )
    return [dict(r) for r in rows]


@router.patch('/admin/users/{user_id}/role')
async def change_role(user_id: int, data: RoleIn, user=Depends(owner_user)):
    if data.role not in {'customer', 'admin', 'owner'}:
        raise HTTPException(400, 'Недопустимая роль')
    if user_id == user['id'] and data.role != 'owner':
        raise HTTPException(400, 'Нельзя снять роль с текущего владельца')

    pool = await get_pool()
    async with pool.acquire() as conn:
        if data.role == 'owner':
            raise HTTPException(400, 'Для безопасности роль owner назначается только через bootstrap')
        row = await conn.fetchrow(
            'UPDATE users SET role=$1 WHERE id=$2 RETURNING id,email,role,blocked',
            data.role, user_id,
        )
    if not row:
        raise HTTPException(404, 'Пользователь не найден')
    await audit(user['id'], 'user.role', 'user', user_id, data.role)
    return dict(row)


@router.patch('/admin/users/{user_id}/blocked')
async def set_blocked(user_id: int, data: BlockIn, user=Depends(owner_user)):
    if user_id == user['id'] and data.blocked:
        raise HTTPException(400, 'Владелец не может заблокировать сам себя')
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            'UPDATE users SET blocked=$1 WHERE id=$2 RETURNING id,email,role,blocked',
            data.blocked, user_id,
        )
    if not row:
        raise HTTPException(404, 'Пользователь не найден')
    await audit(user['id'], 'user.block', 'user', user_id, str(data.blocked))
    return dict(row)


@router.get('/admin/reviews')
async def admin_reviews(_=Depends(admin_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            '''SELECT r.id,r.user_id,u.email,r.product_id,p.name AS product_name,
                      r.rating,r.text,r.approved,r.created_at
               FROM reviews r
               JOIN users u ON u.id=r.user_id
               JOIN products p ON p.id=r.product_id
               ORDER BY r.id DESC'''
        )
    return [dict(r) for r in rows]


@router.patch('/admin/reviews/{review_id}')
async def moderate_review(review_id: int, data: ReviewModerationIn, user=Depends(admin_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            'UPDATE reviews SET approved=$1 WHERE id=$2 RETURNING id,approved',
            data.approved, review_id,
        )
    if not row:
        raise HTTPException(404, 'Отзыв не найден')
    await audit(user['id'], 'review.moderate', 'review', review_id, str(data.approved))
    return dict(row)


@router.get('/admin/logs')
async def admin_logs(_=Depends(owner_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            '''SELECT l.id,l.action,l.target_type,l.target_id,l.details,l.created_at,
                      u.email AS admin_email
               FROM audit_logs l
               LEFT JOIN users u ON u.id=l.admin_id
               ORDER BY l.id DESC LIMIT 100'''
        )
    return [dict(r) for r in rows]


@router.get('/admin/settings')
async def admin_settings(_=Depends(owner_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch('SELECT key,value,updated_at FROM app_settings ORDER BY key')
    return [dict(r) for r in rows]


@router.put('/admin/settings/{key}')
async def set_setting(key: str, data: SettingIn, user=Depends(owner_user)):
    if not key or len(key) > 80:
        raise HTTPException(400, 'Недопустимый ключ')
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            '''INSERT INTO app_settings(key,value) VALUES($1,$2)
               ON CONFLICT(key) DO UPDATE SET value=EXCLUDED.value,updated_at=NOW()
               RETURNING key,value,updated_at''',
            key, data.value,
        )
    await audit(user['id'], 'setting.update', 'setting', None, key)
    return dict(row)
