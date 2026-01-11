def update_trust_score(user, delta, reason):
    user.trust_score = max(0, min(100, user.trust_score + delta))
    user.save()

    user.trust_events.create(
        delta=delta,
        reason=reason,
    )
