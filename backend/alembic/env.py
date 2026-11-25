from logging.config import fileConfig

from alembic.runtime.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, inspect, pool
from sqlalchemy.engine import Connection

from alembic import context
from app.core.config import get_settings
from app.models import (  # noqa: F401
    ActivityLog,
    AdminAuditLog,
    AdminMfaSecret,
    Attachment,
    ChecklistItem,
    Comment,
    EmailCode,
    Label,
    MCPAuthorizationCode,
    MCPOAuthClient,
    MCPRefreshGrant,
    ModerationReport,
    OAuthLoginState,
    PlatformSetting,
    ProjectLeaveRequest,
    ProjectLeaveRequestStatus,
    ProjectRestriction,
    RefreshToken,
    Task,
    TaskAssignee,
    TaskLabel,
    TaskStatus,
    TeamSettings,
    User,
    UserActivityEvent,
    UserBlock,
    UserIdentity,
)
from app.models.base import Base

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata
settings = get_settings()


def sync_database_url() -> str:
    """Alembic на Windows надёжнее работает через синхронный драйвер, не asyncpg."""
    url = settings.DATABASE_URL
    if "+asyncpg" in url:
        return url.replace("postgresql+asyncpg://", "postgresql+psycopg://", 1)
    return url


config.set_main_option("sqlalchemy.url", sync_database_url())


def run_migrations_offline() -> None:
    url = sync_database_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        tables = set(inspect(connection).get_table_names())
        application_tables = tables - {"alembic_version"}
        if not application_tables:
            # Revision 001 creates the current model metadata. Running every
            # historical revision afterward would re-add columns already
            # present in that schema and can break a fresh installation.
            target_metadata.create_all(connection)
            MigrationContext.configure(connection).stamp(
                ScriptDirectory.from_config(config), "head"
            )
        else:
            context.run_migrations()


def run_migrations_online() -> None:
    connectable = create_engine(sync_database_url(), poolclass=pool.NullPool)
    with connectable.connect() as connection:
        do_run_migrations(connection)
    connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
