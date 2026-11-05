import asyncio
import subprocess
import sys
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.api.v1.router import api_router
from app.api.v1.ws import router as ws_router
from app.core.config import get_settings
from app.core.limiter import limiter
from app.db.session import AsyncSessionLocal
from app.services.bootstrap import bootstrap_db
from app.services.due_reminder_service import due_reminder_loop


def run_migrations() -> None:
    backend_dir = Path(__file__).resolve().parent.parent
    # Prefer venv alembic; do not resolve() the interpreter (symlink → Homebrew breaks PATH).
    candidates = [
        Path(sys.executable).parent / "alembic",
        backend_dir / ".venv" / "bin" / "alembic",
    ]
    alembic_cmd = next((str(p) for p in candidates if p.exists()), "alembic")
    result = subprocess.run(
        [alembic_cmd, "upgrade", "head"],
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
    stop = asyncio.Event()
    reminder_task: asyncio.Task | None = None
    if settings.DUE_REMINDER_ENABLED and settings.DUE_REMINDER_INTERVAL_SECONDS > 0:
        reminder_task = asyncio.create_task(due_reminder_loop(stop))
    try:
        yield
    finally:
        stop.set()
        if reminder_task is not None:
            reminder_task.cancel()
            try:
                await reminder_task
            except asyncio.CancelledError:
                pass


settings = get_settings()

app = FastAPI(title=settings.APP_NAME, lifespan=lifespan)
app.state.limiter = limiter


async def _rate_limit_ru_handler(request: Request, exc: RateLimitExceeded):
    return JSONResponse(
        status_code=429,
        content={
            "detail": {
                "error": {
                    "code": "rate_limit",
                    "message": "Слишком много попыток. Попробуйте через минуту",
                }
            }
        },
    )


async def _validation_ru_handler(request: Request, exc: RequestValidationError):
    first = exc.errors()[0] if exc.errors() else {}
    loc = ".".join(str(x) for x in first.get("loc", ()) if x != "body")
    typ = str(first.get("type") or "")
    raw = str(first.get("msg") or "").strip()
    # Pydantic ValueError из model_validator: "Value error, Пароли не совпадают"
    if raw.startswith("Value error, "):
        raw = raw[len("Value error, ") :].strip()
    loc_l = loc.lower()
    if raw and typ == "value_error":
        message = raw
    elif typ.endswith("missing") or typ == "missing":
        message = "Заполните обязательные поля"
    elif "email" in loc_l or "email" in typ:
        message = "Введите корректный email"
    elif "password" in loc_l and ("too_short" in typ or "min_length" in typ):
        message = "Пароль не короче 8 символов"
    elif "password" in loc_l:
        message = "Проверьте пароль"
    elif "too_short" in typ or "min_length" in typ:
        message = "Слишком короткое значение"
    elif "too_long" in typ or "max_length" in typ:
        message = "Слишком длинное значение"
    elif "string_type" in typ or "type_error" in typ:
        message = "Некорректный формат данных"
    else:
        # Не отдаём сырой английский текст pydantic пользователю.
        message = "Некорректные данные запроса"
    return JSONResponse(
        status_code=422,
        content={"detail": {"error": {"code": "validation_error", "message": message}}},
    )


app.add_exception_handler(RateLimitExceeded, _rate_limit_ru_handler)
app.add_exception_handler(RequestValidationError, _validation_ru_handler)
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
