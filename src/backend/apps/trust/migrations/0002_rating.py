from django.db import migrations, models
import django.db.models.deletion

class Migration(migrations.Migration):
    dependencies = [
        ("trust", "0001_initial"),
        ("errands", "0001_initial"),
        ("users", "0001_initial"),
    ]
    operations = [
        migrations.CreateModel(
            name="Rating",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("score", models.PositiveSmallIntegerField()),
                ("comment", models.TextField(blank=True, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("errand", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="ratings", to="errands.errand")),
                ("rater", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="given_ratings", to="users.user")),
                ("ratee", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="received_ratings", to="users.user")),
            ],
            options={
                "unique_together": {("errand", "rater", "ratee")},
            },
        ),
    ]
