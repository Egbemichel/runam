import base64
import os
import uuid
from typing import Tuple

from django.conf import settings
from graphql import GraphQLError

# Optional Supabase import
try:
    import supabase as _supabase_module  # type: ignore
except Exception:  # pragma: no cover
    _supabase_module = None


def _parse_base64_image(data: str) -> Tuple[bytes, str]:
    """
    Accepts either raw base64 or data URL (data:image/jpeg;base64,....)
    Returns (bytes, extension)
    """
    header, b64data = (None, data)
    if data.startswith("data:") and ";base64," in data:
        header, b64data = data.split(",", 1)
    try:
        content = base64.b64decode(b64data)
    except Exception:
        raise GraphQLError("Invalid image payload")

    ext = "jpg"
    if header:
        if "image/png" in header:
            ext = "png"
        elif "image/jpeg" in header or "image/jpg" in header:
            ext = "jpg"
        elif "image/webp" in header:
            ext = "webp"
    return content, ext


def store_image_local(image_b64: str, user) -> str:
    content, ext = _parse_base64_image(image_b64)
    folder = os.path.join(settings.MEDIA_ROOT, "errands", str(user.id))
    os.makedirs(folder, exist_ok=True)

    filename = f"{uuid.uuid4().hex}.{ext}"
    path = os.path.join(folder, filename)

    with open(path, "wb") as f:
        f.write(content)

    rel_path = os.path.join("errands", str(user.id), filename).replace("\\", "/")
    return (settings.MEDIA_URL.rstrip("/") + "/" + rel_path).replace("//", "/")


def store_image_supabase(image_b64: str, user) -> str:
    if not _supabase_module:
        raise GraphQLError("Supabase client not installed. Set STORAGE_MODE=local or install supabase-py")
    if not (settings.SUPABASE_URL and settings.SUPABASE_SERVICE_KEY):
        raise GraphQLError("Supabase env vars missing")

    client = _supabase_module.create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)
    content, ext = _parse_base64_image(image_b64)
    filename = f"errands/{user.id}/{uuid.uuid4().hex}.{ext}"

    bucket = settings.SUPABASE_BUCKET or "public"
    # Upload bytes
    upload_resp = client.storage.from_(bucket).upload(filename, content)
    if getattr(upload_resp, "error", None):
        raise GraphQLError(f"Supabase upload failed: {upload_resp.error}")

    # Get public URL
    public = client.storage.from_(bucket).get_public_url(filename)
    url = None
    if isinstance(public, dict):
        url = public.get("publicUrl") or public.get("public_url")
    else:
        # supabase-py may return object with .public_url
        url = getattr(public, "public_url", None) or getattr(public, "publicUrl", None)
    if not url:
        raise GraphQLError("Supabase public URL unavailable")
    return url


def store_errand_image(image_b64: str, user) -> str:
    mode = (settings.STORAGE_MODE or "local").lower()
    if mode == "supabase":
        return store_image_supabase(image_b64, user)
    return store_image_local(image_b64, user)
