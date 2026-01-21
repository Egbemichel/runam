import logging

from apps.errands.models import Errand, ErrandOffer
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
    created_offers = []
    for idx, runner in enumerate(runners, start=1):
        logger.info("start_errand_matching: creating offer for runner=%s position=%s for errand=%s", getattr(runner, 'id', None), idx, errand.id)
        try:
            offer = send_errand_offer(errand, runner, position=idx)
            if offer:
                created_offers.append((getattr(offer, 'id', None), getattr(runner, 'id', None)))
        except Exception as e:
            logger.exception("start_errand_matching: failed to create offer for runner=%s errand=%s: %s", getattr(runner, 'id', None), errand.id, e)
        # continue to create offers for next runners

    # 3️⃣ Offers created — do NOT expire the errand here. Frontend polling / runner actions
    # will drive acceptance and eventual expiration. We keep the errand open for the offers TTL.
    logger.info("start_errand_matching: created %s offers for errand=%s; leaving errand open for polling", len(created_offers), errand.id)

    # Extra debug: query DB for offers to ensure they persisted and log runner ids
    try:
        offers_qs = ErrandOffer.objects.filter(errand=errand).order_by('created_at')
        offer_count = offers_qs.count()
        sample = list(offers_qs.values_list('id', 'runner_id', 'status', 'expires_at')[:20])
        logger.info("start_errand_matching: DB shows %s offers for errand=%s sample=%s", offer_count, errand.id, sample)
    except Exception:
        logger.exception("start_errand_matching: failed to query ErrandOffer rows for errand=%s", errand.id)
