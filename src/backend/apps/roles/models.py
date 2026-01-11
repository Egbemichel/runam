from django.db import models


class Role(models.Model):
    BUYER = "BUYER"
    RUNNER = "RUNNER"

    ROLE_CHOICES = [
        (BUYER, "Buyer"),
        (RUNNER, "Runner"),
    ]

    name = models.CharField(max_length=20, choices=ROLE_CHOICES, unique=True)

    def __str__(self):
        return self.name
