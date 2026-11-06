"""Email transport: SMTP.BZ HTTP API (preferred) or classic SMTP fallback."""

from __future__ import annotations

import logging
import re
import smtplib
import uuid
from email.message import EmailMessage

import httpx

from app.core.config import get_settings

logger = logging.getLogger("takt.email")

_SMTP_BZ_SEND_URL = "https://api.smtp.bz/v1/smtp/send"
_FROM_RE = re.compile(r"^(?:(.+?)\s*)?<([^>]+)>$")


class EmailDeliveryError(RuntimeError):
    def __init__(self, message: str = "Не удалось отправить письмо"):
        super().__init__(message)
        self.message = message


def _parse_from_header(raw: str) -> tuple[str, str]:
    value = raw.strip()
    match = _FROM_RE.match(value)
    if match:
        name = (match.group(1) or "Takt").strip().strip('"')
        return match.group(2).strip(), name
    return value, "Takt"


def is_email_configured() -> bool:
    settings = get_settings()
    if settings.SMTP_BZ_API_KEY.strip():
        return True
    return bool(settings.SMTP_HOST.strip() and settings.SMTP_USER.strip())


def _otp_copy(purpose: str) -> tuple[str, str, str]:
    """subject suffix, heading, short body line — same HTML chrome for every purpose."""
    if purpose == "register":
        return "код регистрации", "Код регистрации", "Подтвердите регистрацию в Takt:"
    if purpose == "change_password":
        return "код смены пароля", "Код смены пароля", "Подтвердите смену пароля:"
    if purpose == "reset_password":
        return "код сброса пароля", "Код сброса пароля", "Подтвердите сброс пароля:"
    return "код подтверждения", "Код подтверждения", "Ваш код подтверждения:"


def _otp_bodies(*, app_name: str, code: str, purpose: str) -> tuple[str, str, str]:
    subject_suffix, heading, lead = _otp_copy(purpose)
    subject = f"{app_name} — {subject_suffix}"
    text_body = (
        f"{heading}\n\n{lead}\n\n{code}\n\n"
        f"Код действует ограниченное время. Если вы не запрашивали его — "
        f"просто игнорируйте это письмо.\n"
    )
    # Единый HTML-шаблон для register / change_password / reset_password.
    font = "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif"
    wrap = "background:#f4f7f8;padding:32px 16px;"
    card = (
        "max-width:420px;background:#ffffff;border-radius:16px;"
        "padding:28px 24px;border:1px solid #e6ecef;"
    )
    html_body = (
        "<!DOCTYPE html><html lang=\"ru\"><head><meta charset=\"utf-8\">"
        "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
        f"<title>{subject}</title></head>"
        f"<body style=\"margin:0;padding:0;background:#f4f7f8;font-family:{font};\">"
        "<table role=\"presentation\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\" "
        f"style=\"{wrap}\"><tr><td align=\"center\">"
        f"<table role=\"presentation\" width=\"100%\" style=\"{card}\">"
        "<tr><td style=\"font-size:13px;font-weight:600;letter-spacing:0.04em;"
        "text-transform:uppercase;color:#315f72;padding-bottom:10px;\">"
        f"{app_name}</td></tr>"
        "<tr><td style=\"font-size:22px;font-weight:700;color:#1a2330;"
        f"padding-bottom:8px;line-height:1.25;\">{heading}</td></tr>"
        "<tr><td style=\"font-size:14px;line-height:1.5;color:#5b6775;"
        f"padding-bottom:22px;\">{lead}</td></tr>"
        "<tr><td align=\"center\" style=\"background:#f4f7f8;border-radius:12px;"
        "padding:18px 12px;\">"
        "<span style=\"font-size:32px;letter-spacing:8px;font-weight:700;"
        f"color:#1a2330;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;\">"
        f"{code}</span></td></tr>"
        "<tr><td style=\"font-size:13px;line-height:1.5;color:#8a94a0;"
        "padding-top:22px;\">"
        "Код действует ограниченное время. Если вы не запрашивали его — "
        "просто игнорируйте это письмо.</td></tr>"
        "</table></td></tr></table></body></html>"
    )
    return subject, text_body, html_body


def _send_via_smtp(*, to: str, subject: str, text_body: str, html_body: str) -> str:
    settings = get_settings()
    from_raw = settings.SMTP_FROM_EMAIL.strip() or settings.SMTP_USER.strip()
    from_email, from_name = _parse_from_header(from_raw)
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = f"{from_name} <{from_email}>"
    msg["To"] = to
    msg.set_content(text_body)
    msg.add_alternative(html_body, subtype="html")
    try:
        with smtplib.SMTP(settings.SMTP_HOST.strip(), settings.SMTP_PORT, timeout=30) as smtp:
            if settings.SMTP_USE_TLS:
                smtp.starttls()
            if settings.SMTP_USER.strip():
                smtp.login(settings.SMTP_USER.strip(), settings.SMTP_PASSWORD)
            smtp.send_message(msg)
    except Exception as exc:
        logger.warning("SMTP send failed to=%s err=%s", to, type(exc).__name__)
        raise EmailDeliveryError("Не удалось отправить письмо через SMTP") from exc
    logger.info("Email sent via SMTP to=%s subject=%s", to, subject)
    return "smtp_ok"


async def _send_via_smtp_bz_api(
    *,
    to: str,
    subject: str,
    html_body: str,
    text_body: str,
) -> str:
    settings = get_settings()
    from_raw = settings.SMTP_FROM_EMAIL.strip() or "Takt <noreply@taktapp.ru>"
    from_email, from_name = _parse_from_header(from_raw)

    boundary = f"----Takt{uuid.uuid4().hex}"
    fields = {
        "from": from_email,
        "name": from_name,
        "to": to,
        "subject": subject,
        "html": html_body,
        "text": text_body,
    }
    parts: list[str] = []
    for key, value in fields.items():
        parts.append(
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="{key}"\r\n\r\n'
            f"{value}\r\n"
        )
    body = "".join(parts) + f"--{boundary}--\r\n"

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                _SMTP_BZ_SEND_URL,
                content=body.encode("utf-8"),
                headers={
                    "Authorization": settings.SMTP_BZ_API_KEY.strip(),
                    "Content-Type": f"multipart/form-data; boundary={boundary}",
                },
            )
    except httpx.HTTPError as exc:
        logger.exception("SMTP.BZ network error to=%s", to)
        raise EmailDeliveryError("Не удалось отправить письмо через SMTP.BZ") from exc

    if response.status_code >= 400:
        logger.error("SMTP.BZ HTTP %s to=%s body=%s", response.status_code, to, response.text)
        raise EmailDeliveryError("Не удалось отправить письмо. Проверьте адрес почты.")

    try:
        payload = response.json()
    except ValueError:
        payload = None

    if isinstance(payload, dict) and payload.get("result") is False:
        logger.error("SMTP.BZ rejected to=%s payload=%s", to, payload)
        raise EmailDeliveryError("Не удалось отправить письмо. Проверьте адрес почты.")

    logger.info("Email sent via SMTP.BZ API to=%s subject=%s", to, subject)
    return "smtp_bz_ok"


async def send_otp_email(*, to: str, code: str, purpose: str) -> str | None:
    """Send OTP. Returns transport id, or None in dry-run."""
    settings = get_settings()
    destination = to.strip().lower()
    if not destination:
        raise EmailDeliveryError("Пустой адрес получателя")

    app_name = settings.APP_NAME or "Takt"
    subject, text_body, html_body = _otp_bodies(app_name=app_name, code=code, purpose=purpose)

    if not is_email_configured():
        logger.info("Email dry-run: to=%s purpose=%s", destination, purpose)
        return None

    # Prefer SMTP.BZ HTTP API (works when VPS blocks outbound SMTP ports).
    if settings.SMTP_BZ_API_KEY.strip():
        return await _send_via_smtp_bz_api(
            to=destination,
            subject=subject,
            html_body=html_body,
            text_body=text_body,
        )

    return _send_via_smtp(
        to=destination,
        subject=subject,
        text_body=text_body,
        html_body=html_body,
    )
