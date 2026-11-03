import asyncio
import os
from collections.abc import AsyncGenerator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

os.environ["ENV"] = "test"
# Always use the dedicated test database — never inherit DATABASE_URL from .env
# (that pointed at `track` and drop_all wiped the working demo workspace).
os.environ["DATABASE_URL"] = (
    "postgresql+asyncpg://track:track_dev_pass@localhost:5433/track_test"
)
os.environ["SECRET_KEY"] = "test-secret-key-minimum-32-characters-long"
os.environ["ADMIN_EMAIL"] = "admin@test.com"
os.environ["ADMIN_PASSWORD"] = "Admin123!Test"
os.environ["ADMIN_NAME"] = "Admin"
os.environ["SEED_DEMO_DATA"] = "false"

from app.core.config import get_settings

get_settings.cache_clear()

from app.db.session import get_db
from app.main import app
from app.models.base import Base
from app.services.bootstrap import bootstrap_db

engine = create_async_engine(os.environ["DATABASE_URL"], echo=False, poolclass=NullPool)
TestSession = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(autouse=True)
async def prepare_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    async with TestSession() as db:
        await bootstrap_db(db, get_settings())
    yield


@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    async def override_get_db():
        async with TestSession() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    app.dependency_overrides[get_db] = override_get_db
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def admin_client(client: AsyncClient) -> AsyncClient:
    r = await client.post(
        "/api/v1/auth/login",
        json={"email": "admin@test.com", "password": "Admin123!Test"},
    )
    assert r.status_code == 200
    return client


async def current_user_id(client: AsyncClient) -> str:
    me = await client.get("/api/v1/auth/me")
    assert me.status_code == 200, me.text
    return me.json()["user"]["id"]


async def register_verified(
    client: AsyncClient,
    *,
    name: str,
    email: str,
    password: str = "SecurePass123!",
    invite_token: str | None = None,
) -> dict:
    """Registration via email OTP (dev_code available when ENV=test)."""
    send = await client.post(
        "/api/v1/auth/register/send-code",
        json={
            "name": name,
            "email": email,
            "password": password,
            "password_confirm": password,
        },
    )
    assert send.status_code == 200, send.text
    code = send.json().get("dev_code")
    assert code, "expected dev_code in test env"
    payload: dict = {"email": email, "code": code}
    if invite_token:
        payload["invite_token"] = invite_token
    confirm = await client.post(
        "/api/v1/auth/register/confirm",
        json=payload,
    )
    assert confirm.status_code == 200, confirm.text
    return confirm.json()
