import argparse
import asyncio

from sqlalchemy import select

from app.core.config import get_settings
from app.core.security import hash_password
from app.db.session import AsyncSessionLocal
from app.models.user import User, UserRole
from app.services.bootstrap import bootstrap_db


async def create_admin(email: str | None, password: str | None, name: str | None) -> None:
    settings = get_settings()
    email = (email or settings.ADMIN_EMAIL).lower()
    password = password or settings.ADMIN_PASSWORD
    name = name or settings.ADMIN_NAME
    async with AsyncSessionLocal() as db:
        await bootstrap_db(db, settings)
        user = await db.scalar(select(User).where(User.email == email))
        if user:
            user.password_hash = hash_password(password)
            user.role = UserRole.admin
            user.is_active = True
            user.name = name
            print(f"Обновлён администратор: {email}")
        else:
            db.add(
                User(
                    email=email,
                    password_hash=hash_password(password),
                    name=name,
                    role=UserRole.admin,
                    is_active=True,
                    must_change_password=False,
                )
            )
            print(f"Создан администратор: {email}")
        await db.commit()


async def seed_demo() -> None:
    settings = get_settings()
    if settings.ENV not in ("development", "test", "local") and not settings.DEBUG:
        raise SystemExit("seed-demo разрешён только в development/test/local или DEBUG=true")
    from app.services.demo_seed import seed_demo_content

    async with AsyncSessionLocal() as db:
        await bootstrap_db(db, settings)
        result = await seed_demo_content(db)
        print("Demo seed OK:", result)


def main() -> None:
    parser = argparse.ArgumentParser(prog="app.cli")
    sub = parser.add_subparsers(dest="command", required=True)
    admin = sub.add_parser("create-admin", help="Создать или сбросить администратора")
    admin.add_argument("--email")
    admin.add_argument("--password")
    admin.add_argument("--name")
    sub.add_parser("seed-demo", help="Идемпотентное демо-наполнение (только local/dev)")
    args = parser.parse_args()
    if args.command == "create-admin":
        asyncio.run(create_admin(args.email, args.password, args.name))
    elif args.command == "seed-demo":
        asyncio.run(seed_demo())


if __name__ == "__main__":
    main()
