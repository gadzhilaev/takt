import subprocess
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.core.limiter import limiter

from app.api.v1.router import api_router
from app.api.v1.ws import router as ws_router
from app.core.config import get_settings
from app.db.session import AsyncSessionLocal
from app.services.bootstrap import bootstrap_db


def run_migrations() -> None:
    backend_dir = Path(__file__).resolve().parent.parent
    result = subprocess.run(
        ["alembic", "upgrade", "head"],
        cwd=backend_dir,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        settings = get_settings()
        hint = (
            "\n\n--- Не удалось подключиться к PostgreSQL ---\n"
            f"DATABASE_URL: {settings.DATABASE_URL}\n"
            "Локально на Windows часто на :5432 уже стоит свой PostgreSQL (не пользователь track).\n"
            "1) Запустите БД проекта:  cd ..  &&  docker compose up db -d\n"
            "2) В .env используйте порт 5433 и пароль POSTGRES_PASSWORD (см. .env.example)\n"
            "3) Один раз:  alembic upgrade head\n"
            "-------------------------------------------\n"
        )
        raise RuntimeError(hint + (result.stderr or result.stdout or "alembic failed"))


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    Path(settings.UPLOAD_DIR).mkdir(parents=True, exist_ok=True)
    run_migrations()
    async with AsyncSessionLocal() as db:
        await bootstrap_db(db, settings)
    if settings.SEED_DEMO_DATA:
        from app.services.seed import seed_demo

        async with AsyncSessionLocal() as db:
            await seed_demo(db)
    yield


settings = get_settings()

app = FastAPI(title=settings.APP_NAME, lifespan=lifespan)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    return response


@app.get("/health")
async def health():
    return {"status": "ok"}


app.include_router(api_router)
app.include_router(ws_router)


@app.exception_handler(Exception)
async def unhandled(request: Request, exc: Exception):
    if settings.DEBUG:
        raise exc
    return JSONResponse(
        status_code=500,
        content={"error": {"code": "internal", "message": "Внутренняя ошибка сервера"}},
    )
