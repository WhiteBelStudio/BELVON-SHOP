import os
from datetime import datetime, timedelta, timezone
import jwt
from pwdlib import PasswordHash
from fastapi import HTTPException, status

_passwords = PasswordHash.recommended()
ALGORITHM = 'HS256'

def hash_password(value): return _passwords.hash(value)
def verify_password(value, hashed): return _passwords.verify(value, hashed)

def token_for(user_id, role):
    payload={'sub':str(user_id),'role':role,'exp':datetime.now(timezone.utc)+timedelta(hours=12)}
    return jwt.encode(payload, os.environ['JWT_SECRET'], algorithm=ALGORITHM)

def decode_token(token):
    try: return jwt.decode(token, os.environ['JWT_SECRET'], algorithms=[ALGORITHM])
    except jwt.PyJWTError as exc: raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Недействительный токен') from exc
