import logging

from apps.errands.models import Errand
from runners.services import get_nearby_runners
from apps.errands.services import send_errand_offer, expire_errand

logger = logging.getLogger(__name__)

def start_errand_matching(errand_id):
    logger.info("start_errand_matching triggered for errand=%s", errand_id)
    try:
        errand = Errand.objects.get(id=errand_id)
    except Errand.DoesNotExist:
        logger.warning("start_errand_matching: errand %s does not exist", errand_id)
        return

    logger.debug("Loaded errand %s: status=%s is_open=%s", errand.id, errand.status, errand.is_open)

    # Safety checks
    if not errand.is_open or errand.status != Errand.Status.PENDING:
        logger.info("start_errand_matching: errand %s is not open or not pending; skipping", errand.id)
        return

    # 1️⃣ Find nearby runners (sorted by distance + trust_score)
    runners = get_nearby_runners(errand)
    logger.info("start_errand_matching: found %s runners for errand=%s", len(runners), errand.id)

    if not runners:
        logger.info("start_errand_matching: no runners found for errand=%s; expiring errand", errand.id)
        expire_errand(errand)
        return

    # 2️⃣ Send offers sequentially
    for idx, runner in enumerate(runners, start=1):
        logger.info("start_errand_matching: sending offer to runner=%s position=%s for errand=%s", getattr(runner, 'id', None), idx, errand.id)
        accepted = send_errand_offer(errand, runner, position=idx)

        if accepted:
            logger.info("start_errand_matching: runner=%s accepted errand=%s", getattr(runner, 'id', None), errand.id)
            return  # Flow continues elsewhere
        else:
            logger.info("start_errand_matching: runner=%s did not accept errand=%s; continuing", getattr(runner, 'id', None), errand.id)

    # 3️⃣ No one accepted
    logger.info("start_errand_matching: no runners accepted errand=%s; expiring", errand.id)
    expire_errand(errand)
