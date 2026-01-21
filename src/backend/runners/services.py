import logging
from django.contrib.auth import get_user_model
from math import radians, sin, cos, sqrt, atan2

logger = logging.getLogger(__name__)
User = get_user_model()


def distance_between(location, go_to):
    """Compute distance in meters between two (latitude, longitude) points using Haversine formula.
    Accepts either objects with .latitude/.longitude or tuples (lat, lon).
    Returns a large number if coordinates are missing to push such users to the end.
    """
    try:
        if location is None or go_to is None:
            logger.debug("distance_between: missing location or go_to -> inf")
            return float("inf")

        if hasattr(location, "latitude") and hasattr(location, "longitude"):
            lat1 = float(location.latitude)
            lon1 = float(location.longitude)
        elif isinstance(location, (list, tuple)) and len(location) >= 2:
            lat1, lon1 = float(location[0]), float(location[1])
        else:
            logger.debug("distance_between: invalid location format -> inf")
            return float("inf")

        # go_to might be ErrandLocation model with latitude/longitude or a tuple
        if hasattr(go_to, "latitude") and hasattr(go_to, "longitude"):
            lat2 = float(go_to.latitude)
            lon2 = float(go_to.longitude)
        elif isinstance(go_to, (list, tuple)) and len(go_to) >= 2:
            lat2, lon2 = float(go_to[0]), float(go_to[1])
        else:
            logger.debug("distance_between: invalid go_to format -> inf")
            return float("inf")

        # Haversine
        R = 6371000  # Earth radius in meters
        phi1 = radians(lat1)
        phi2 = radians(lat2)
        dphi = radians(lat2 - lat1)
        dlambda = radians(lon2 - lon1)

        a = sin(dphi / 2) ** 2 + cos(phi1) * cos(phi2) * sin(dlambda / 2) ** 2
        c = 2 * atan2(sqrt(a), sqrt(1 - a))

        dist = R * c
        logger.debug("distance_between: computed %s meters between (%s,%s) and (%s,%s)", dist, lat1, lon1, lat2, lon2)
        return dist

    except Exception as e:
        logger.exception("distance_between failed: %s", e)
        return float("inf")


def get_nearby_runners(errand):
    """
    Returns runners ordered by:
    1. Distance (ascending)
    2. Trust score (descending)

    This function fetches candidate users with a non-null `location` and sorts them in Python
    using the `distance_between` helper because the database does not use geo indexes.
    """
    logger.info("get_nearby_runners: computing candidates for errand=%s", getattr(errand, 'id', None))
    # Select candidates who have the RUNNER role and a saved location
    runners_qs = (
        User.objects
        .filter(profile__roles__name="RUNNER", location__isnull=False)
        .select_related("location", "profile")
    )

    # Log how many users matched the DB filter and sample ids
    try:
        total_candidates = runners_qs.count()
        sample_ids = list(runners_qs.values_list('id', flat=True)[:10])
        logger.info("get_nearby_runners: DB matched %s users with RUNNER role and location. sample_ids=%s", total_candidates, sample_ids)
    except Exception:
        logger.exception("get_nearby_runners: failed to inspect candidate queryset")

    # Prepare list with computed distances
    runners_with_distance = []
    for r in runners_qs:
        try:
            dist = distance_between(r.location, errand.go_to)
            trust = getattr(r.profile, "trust_score", 0)
        except Exception as e:
            logger.exception("get_nearby_runners: failed for runner=%s: %s", getattr(r, 'id', None), e)
            dist = float("inf")
            trust = 0
        runners_with_distance.append((r, dist, trust))

    # Sort by distance asc, trust desc
    runners_with_distance.sort(key=lambda t: (t[1], -t[2]))

    # Log sorted list
    logger.info("get_nearby_runners: sorted %s candidates for errand=%s", len(runners_with_distance), getattr(errand, 'id', None))
    for r, dist, trust in runners_with_distance:
        logger.debug("candidate runner=%s dist_m=%s trust=%s", getattr(r, 'id', None), dist, trust)

    # Return only user objects in order
    return [t[0] for t in runners_with_distance]
