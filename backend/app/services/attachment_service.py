"""Task file attachments with optional WebP preview for images."""

from __future__ import annotations

import io
import re
import uuid
from pathlib import Path

from fastapi import UploadFile
from PIL import Image, UnidentifiedImageError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.models.task import Attachment, Task
from app.models.user import User

MAX_BYTES = 25 * 1024 * 1024
PREVIEW_MAX_EDGE = 1280
PREVIEW_QUALITY = 80

_SAFE_NAME = re.compile(r"[^\w.\- ()\[\]]+", re.UNICODE)

IMAGE_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/gif",
    "image/webp",
    "image/heic",
    "image/heif",
    "image/bmp",
}


class AttachmentError(Exception):
    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message
        super().__init__(message)


def _sanitize_filename(name: str) -> str:
    raw = (name or "file").strip().replace("\\", "/").split("/")[-1]
    cleaned = _SAFE_NAME.sub("_", raw).strip(" ._")
    if not cleaned:
        cleaned = "file"
    return cleaned[:200]


def _ext_for(content_type: str, filename: str) -> str:
    suffix = Path(filename).suffix.lower()
    if suffix and len(suffix) <= 12:
        return suffix
    mapping = {
        "image/jpeg": ".jpg",
        "image/png": ".png",
        "image/gif": ".gif",
        "image/webp": ".webp",
        "application/pdf": ".pdf",
    }
    return mapping.get(content_type, ".bin")


def attachments_dir(task_id: uuid.UUID) -> Path:
    settings = get_settings()
    path = Path(settings.UPLOAD_DIR) / "attachments" / str(task_id)
    path.mkdir(parents=True, exist_ok=True)
    return path


def attachment_path(att: Attachment) -> Path:
    return attachments_dir(att.task_id) / att.stored_name


def preview_path(att: Attachment) -> Path | None:
    if not att.preview_stored_name:
        return None
    return attachments_dir(att.task_id) / att.preview_stored_name


def is_image_content_type(content_type: str) -> bool:
    ct = (content_type or "").split(";")[0].strip().lower()
    return ct in IMAGE_TYPES or ct.startswith("image/")


def _make_webp_preview(data: bytes) -> bytes | None:
    try:
        img = Image.open(io.BytesIO(data))
        img = img.convert("RGB") if img.mode not in ("RGB", "L") else img.convert("RGB")
        img.thumbnail((PREVIEW_MAX_EDGE, PREVIEW_MAX_EDGE), Image.Resampling.LANCZOS)
        buf = io.BytesIO()
        img.save(buf, format="WEBP", quality=PREVIEW_QUALITY, method=4)
        return buf.getvalue()
    except (UnidentifiedImageError, OSError, ValueError):
        return None


async def get_attachment(db: AsyncSession, attachment_id: uuid.UUID) -> Attachment | None:
    return (
        await db.execute(
            select(Attachment)
            .options(selectinload(Attachment.task))
            .where(Attachment.id == attachment_id)
        )
    ).scalar_one_or_none()


async def list_for_task(db: AsyncSession, task_id: uuid.UUID) -> list[Attachment]:
    rows = (
        await db.execute(
            select(Attachment)
            .where(Attachment.task_id == task_id)
            .order_by(Attachment.created_at.asc())
        )
    ).scalars().all()
    return list(rows)


async def save_upload(
    db: AsyncSession,
    *,
    task: Task,
    user: User,
    upload: UploadFile,
) -> Attachment:
    raw_name = upload.filename or "file"
    filename = _sanitize_filename(raw_name)
    content_type = (upload.content_type or "application/octet-stream").split(";")[0].strip()
    data = await upload.read()
    if not data:
        raise AttachmentError("empty", "Пустой файл")
    if len(data) > MAX_BYTES:
        raise AttachmentError("too_large", "Файл больше 25 МБ")

    att_id = uuid.uuid4()
    ext = _ext_for(content_type, filename)
    stored = f"{att_id}{ext}"
    folder = attachments_dir(task.id)
    (folder / stored).write_bytes(data)

    preview_name: str | None = None
    if is_image_content_type(content_type):
        preview = _make_webp_preview(data)
        if preview:
            preview_name = f"{att_id}_preview.webp"
            (folder / preview_name).write_bytes(preview)

    att = Attachment(
        id=att_id,
        task_id=task.id,
        uploaded_by_id=user.id,
        filename=filename,
        stored_name=stored,
        preview_stored_name=preview_name,
        size_bytes=len(data),
        content_type=content_type or "application/octet-stream",
    )
    db.add(att)
    await db.flush()
    return att


async def delete_attachment(db: AsyncSession, att: Attachment) -> None:
    path = attachment_path(att)
    prev = preview_path(att)
    await db.delete(att)
    await db.flush()
    path.unlink(missing_ok=True)
    if prev:
        prev.unlink(missing_ok=True)
