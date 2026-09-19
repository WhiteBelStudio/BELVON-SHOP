from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from .auth import decode_token, hash_password, token_for, verify_password
from .db import get_pool

router=APIRouter()
class AuthIn(BaseModel): email:str; password:str=Field(min_length=6,max_length=128)
class ProductIn(BaseModel): name:str=Field(min_length=1,max_length=200); description:str=''; category:str='Другое'; price:float=Field(ge=0); image_url:str|None=None; available:bool=True
class OrderItemIn(BaseModel): product_id:int; quantity:int=Field(ge=1,le=100)
class OrderIn(BaseModel): items:list[OrderItemIn]=Field(min_length=1)

async def current_user(authorization:str|None=Header(default=None)):
    if not authorization or not authorization.startswith('Bearer '): raise HTTPException(401,'Требуется авторизация')
    return decode_token(authorization[7:])
async def admin_user(user=Depends(current_user)):
    if user.get('role')!='admin': raise HTTPException(403,'Доступ только для администратора')
    return user

@router.post('/auth/register')
async def register(data:AuthIn):
    pool=await get_pool()
    async with pool.acquire() as conn:
        try: row=await conn.fetchrow('INSERT INTO users(email,password_hash) VALUES($1,$2) RETURNING id,email,role',data.email.lower().strip(),hash_password(data.password))
        except Exception as exc:
            if 'users_email_key' in str(exc): raise HTTPException(409,'Email уже зарегистрирован') from exc
            raise
    return {'access_token':token_for(row['id'],row['role']),'user':dict(row)}

@router.post('/auth/login')
async def login(data:AuthIn):
    pool=await get_pool()
    async with pool.acquire() as conn: row=await conn.fetchrow('SELECT id,email,password_hash,role FROM users WHERE email=$1',data.email.lower().strip())
    if not row or not verify_password(data.password,row['password_hash']): raise HTTPException(401,'Неверный email или пароль')
    return {'access_token':token_for(row['id'],row['role']),'user':{'id':row['id'],'email':row['email'],'role':row['role']}}

@router.get('/products')
async def products():
    pool=await get_pool()
    async with pool.acquire() as conn: rows=await conn.fetch('SELECT id,name,description,category,price,image_url,available FROM products WHERE available=TRUE ORDER BY id DESC')
    return [dict(r) for r in rows]

@router.post('/products')
async def create_product(data:ProductIn,_=Depends(admin_user)):
    pool=await get_pool()
    async with pool.acquire() as conn: row=await conn.fetchrow('INSERT INTO products(name,description,category,price,image_url,available) VALUES($1,$2,$3,$4,$5,$6) RETURNING id,name,description,category,price,image_url,available',data.name,data.description,data.category,data.price,data.image_url,data.available)
    return dict(row)

@router.patch('/products/{product_id}')
async def update_product(product_id:int,data:ProductIn,_=Depends(admin_user)):
    pool=await get_pool()
    async with pool.acquire() as conn: row=await conn.fetchrow('UPDATE products SET name=$1,description=$2,category=$3,price=$4,image_url=$5,available=$6,updated_at=NOW() WHERE id=$7 RETURNING id,name,description,category,price,image_url,available',data.name,data.description,data.category,data.price,data.image_url,data.available,product_id)
    if not row: raise HTTPException(404,'Товар не найден')
    return dict(row)

@router.delete('/products/{product_id}')
async def delete_product(product_id:int,_=Depends(admin_user)):
    pool=await get_pool()
    async with pool.acquire() as conn: result=await conn.execute('DELETE FROM products WHERE id=$1',product_id)
    if result=='DELETE 0': raise HTTPException(404,'Товар не найден')
    return {'ok':True}

@router.get('/orders')
async def orders(user=Depends(current_user)):
    pool=await get_pool()
    async with pool.acquire() as conn:
        rows=await conn.fetch('SELECT id,user_id,total,status,created_at FROM orders ORDER BY id DESC') if user['role']=='admin' else await conn.fetch('SELECT id,user_id,total,status,created_at FROM orders WHERE user_id=$1 ORDER BY id DESC',int(user['sub']))
    return [dict(r) for r in rows]

@router.post('/orders')
async def create_order(data:OrderIn,user=Depends(current_user)):
    pool=await get_pool()
    async with pool.acquire() as conn:
        async with conn.transaction():
            total=0.0; prepared=[]
            for item in data.items:
                row=await conn.fetchrow('SELECT id,price FROM products WHERE id=$1 AND available=TRUE',item.product_id)
                if not row: raise HTTPException(400,f'Товар {item.product_id} недоступен')
                total+=float(row['price'])*item.quantity; prepared.append((item.product_id,item.quantity,row['price']))
            order=await conn.fetchrow('INSERT INTO orders(user_id,total) VALUES($1,$2) RETURNING id,user_id,total,status,created_at',int(user['sub']),total)
            for product_id,quantity,price in prepared: await conn.execute('INSERT INTO order_items(order_id,product_id,quantity,unit_price) VALUES($1,$2,$3,$4)',order['id'],product_id,quantity,price)
    return dict(order)

@router.patch('/orders/{order_id}/status')
async def order_status(order_id:int,status_value:str,_=Depends(admin_user)):
    if status_value not in {'new','processing','completed','cancelled'}: raise HTTPException(400,'Недопустимый статус')
    pool=await get_pool()
    async with pool.acquire() as conn: row=await conn.fetchrow('UPDATE orders SET status=$1 WHERE id=$2 RETURNING id,user_id,total,status,created_at',status_value,order_id)
    if not row: raise HTTPException(404,'Заказ не найден')
    return dict(row)
