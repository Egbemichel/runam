from django.db import migrations

def seed_roles(apps, schema_editor):
    Role = apps.get_model("roles", "Role")
    Role.objects.get_or_create(name="BUYER")
    Role.objects.get_or_create(name="RUNNER")

class Migration(migrations.Migration):

    dependencies = [
        ("roles", "0001_initial"),
    ]

    operations = [
        migrations.RunPython(seed_roles),
    ]
