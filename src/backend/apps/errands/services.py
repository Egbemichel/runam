import os
import uuid
from datetime import timedelta
from typing import Tuple
import base64
from django.conf import settings
from apps.errands.models import ErrandOffer, Errand
from django.utils import timezone
import logging
from runners.services import distance_between

logger = logging.getLogger(__name__)

# Structural Pattern: Facade
# This services.py file acts as a Facade, providing a simplified interface to complex subsystems (image storage, offer management, notifications).

# Optional Supabase import
try:
    import supabase as _supabase_module  # type: ignore
except Exception:  # pragma: no cover
    _supabase_module = None

# Creational Pattern: Builder
# The following functions build complex objects step-by-step (e.g., images, offers).

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
        raise ValueError("Invalid image payload")

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

def store_errand_image(image_b64: str, user) -> str:
    mode = (settings.STORAGE_MODE or "dev").lower()
    if mode == "prod":
        pass
    return store_image_local(image_b64, user)


def accept_offer(errand, runner):
    # Calculate distance between runner location and errand.go_to
    try:
        distance_m = float(distance_between(getattr(runner, 'location', None), errand.go_to))
    except Exception:
        distance_m = 0.0

    # distance fee: 250 per 1 KM
    distance_km = distance_m / 1000.0
    distance_fee = int(round(distance_km * 250))

    # service fee & totals
    errand_value = errand.errand_value()
    service_fee = int(errand_value * 0.2)
    total_price = errand_value + service_fee + distance_fee

    # Persist pricing and acceptance
    errand.quoted_distance_fee = distance_fee
    errand.quoted_service_fee = service_fee
    errand.quoted_total_price = total_price

    errand.status = Errand.Status.IN_PROGRESS
    errand.is_open = False
    errand.runner = runner
    errand.accepted_at = timezone.now()
    errand.save(update_fields=["status", "is_open", "runner", "quoted_distance_fee", "quoted_service_fee", "quoted_total_price", "accepted_at"])

    # Expire other pending offers for this errand
    try:
        ErrandOffer.objects.filter(errand=errand, status=ErrandOffer.Status.PENDING).exclude(runner=runner).update(status=ErrandOffer.Status.EXPIRED)
    except Exception:
        logger.exception('Failed expiring other offers')

    # Note: webhooks / websocket notifications removed. Frontend will poll for updates.
    logger.info('accept_offer: completed accept for errand=%s runner=%s total_price=%s', errand.id, getattr(runner, 'id', None), total_price)

def notify_runner(runner, offer):
    """Notify a runner about a new errand offer via WebSocket (Channels) when available.

    Group name convention: "user_{user_id}". Frontend should subscribe to that group.
    Message format: {
        "type": "errand_offer",
        "offer_id": offer.id,
        "errand_id": offer.errand.id,
        "position": offer.position,
        "expires_at": offer.expires_at.isoformat(),
    }

    If Channels is not present, we go back to logging a warning.
    """
    payload = {
        "type": "errand_offer",
        "offer_id": offer.id,
        "errand_id": offer.errand.id,
        "position": offer.position,
        "expires_at": offer.expires_at.isoformat(),
        # Minimal errand summary for runner UI
        "errand": {
            "id": offer.errand.id,
            "image_url": getattr(offer.errand, 'image_url', None),
            "tasks": [
                {"description": t.description, "price": t.price} for t in offer.errand.tasks.all()
            ],
            "go_to": {
                "latitude": getattr(getattr(offer.errand, 'go_to', None), 'latitude', None),
                "longitude": getattr(getattr(offer.errand, 'go_to', None), 'longitude', None),
                "address": getattr(getattr(offer.errand, 'go_to', None), 'address', None),
            },
            "errand_value": offer.errand.errand_value(),
        }
    }

    # No websocket/webhook; frontend should poll offers endpoint to discover pending offers.
    logger.info('notify_runner (noop): created offer=%s for runner=%s errand=%s', getattr(offer, 'id', None), getattr(runner, 'id', None), getattr(offer.errand, 'id', None))
    return True


def send_errand_offer(errand, runner, position: int = 0):
    """Create an ErrandOffer and notify the runner, then return immediately.
    This function no longer blocks or waits for acceptance. Frontend will poll for PENDING offers.
    """
    # Use update_or_create to avoid unique_together IntegrityError and to refresh an existing offer's TTL.
    ttl_seconds = getattr(settings, 'ERRAND_OFFER_TTL_SECONDS', 60)
    expires = timezone.now() + timedelta(seconds=ttl_seconds)

    offer, created = ErrandOffer.objects.update_or_create(
        errand=errand,
        runner=runner,
        defaults={
            'position': position,
            'status': ErrandOffer.Status.PENDING,
            'expires_at': expires,
        }
    )

    # Notify runner (noop for now) and return immediately. Frontend will poll for PENDING offers.
    notify_runner(runner, offer)
    if created:
        logger.info("send_errand_offer: created offer=%s for errand=%s runner=%s expires_at=%s", getattr(offer, 'id', None), getattr(errand, 'id', None), getattr(runner, 'id', None), offer.expires_at)
    else:
        logger.info("send_errand_offer: refreshed offer=%s for errand=%s runner=%s new_expires_at=%s", getattr(offer, 'id', None), getattr(errand, 'id', None), getattr(runner, 'id', None), offer.expires_at)

    # Return immediately; do not block waiting for acceptance. Caller should not assume acceptance.
    return offer


def expire_errand(errand):
    """Mark an errand as expired and expire pending offers."""
    try:
        errand.is_open = False
        errand.status = Errand.Status.EXPIRED
        errand.save(update_fields=["is_open", "status", "updated_at"])
    except Exception:
        # Best effort; avoid raising from background task
        pass

    # Expire any pending offers
    try:
        ErrandOffer.objects.filter(
            errand=errand,
            status=ErrandOffer.Status.PENDING
        ).update(status=ErrandOffer.Status.EXPIRED)
    except Exception:
        pass

    logger.info('expire_errand: errand=%s expired and pending offers were expired', getattr(errand, 'id', None))

# def store_image_supabase(image_b64: str, user) -> str:
#     if not _supabase_module:
#         raise GraphQLError("Supabase client not installed. Set STORAGE_MODE=local or install supabase-py")
#     if not (settings.SUPABASE_URL and settings.SUPABASE_SERVICE_KEY):
#         raise GraphQLError("Supabase env vars missing")
#
#     client = _supabase_module.create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)
#     content, ext = _parse_base64_image(image_b64)
#     filename = f"errands/{user.id}/{uuid.uuid4().hex}.{ext}"
#
#     bucket = settings.SUPABASE_BUCKET or "public"
#     # Upload bytes
#     upload_resp = client.storage.from_(bucket).upload(filename, content)
#     if getattr(upload_resp, "error", None):
#         raise GraphQLError(f"Supabase upload failed: {upload_resp.error}")
#
#     # Get public URL
#     public = client.storage.from_(bucket).get_public_url(filename)
#     url = None
#     if isinstance(public, dict):
#         url = public.get("publicUrl") or public.get("public_url")
#     else:
#         # supabase-py may return object with .public_url
#         url = getattr(public, "public_url", None) or getattr(public, "publicUrl", None)
#     if not url:
#         raise ValueError("Supabase public URL unavailable")
#     return url
#
