"""Unit tests without Postgres (overrides parent prepare_db)."""

import pytest_asyncio


@pytest_asyncio.fixture(autouse=True)
async def prepare_db():
    yield
