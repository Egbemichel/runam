from django.apps import AppConfig


class EscrowConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.escrow'
    
    def ready(self):
        """Import cache signals when app is ready."""
        import core.cache_signals  # noqa