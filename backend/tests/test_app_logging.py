"""app.* INFO logs reach stdout (docker logs); emails in logs are masked."""

import logging

from app.main import configure_app_logging
from app.services.email_service import mask_email


def test_app_info_logs_are_emitted(capsys):
    configure_app_logging("INFO")
    configure_app_logging("INFO")  # idempotent: no duplicate handlers
    app_logger = logging.getLogger("app")
    assert sum(1 for h in app_logger.handlers if getattr(h, "_takt_app", False)) == 1
    logging.getLogger("app.services.rhythm_service").info("rhythm pass ok: projects=%s", 3)
    err = capsys.readouterr().err
    assert "INFO app.services.rhythm_service: rhythm pass ok: projects=3" in err


def test_mask_email():
    assert mask_email("ivan.petrov@college.ru") == "i***@college.ru"
    assert mask_email("") == "***"
    assert mask_email("not-an-email") == "***"
