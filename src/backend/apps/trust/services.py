from .models import Rating, TrustScoreEvent

def update_trust_score(user, delta, reason):
    user.trust_score = max(0, min(100, user.trust_score + delta))
    user.save()

    user.trust_events.create(
        delta=delta,
        reason=reason,
    )

def recalculate_trust_score(user):
    ratings = Rating.objects.filter(ratee=user)
    if ratings.exists():
        avg = round(sum(r.score for r in ratings) / ratings.count())
        old_score = user.trust_score
        user.trust_score = avg
        user.save()
        TrustScoreEvent.objects.create(user=user, delta=avg - old_score, reason="Recalculated from ratings")
    return user.trust_score
