"""
Django management command to clear cache.
"""

from django.core.management.base import BaseCommand
from django.core.cache import cache
from core.cache_utils import CacheManager


class Command(BaseCommand):
    help = 'Clear all cache or specific cache patterns'

    def add_arguments(self, parser):
        parser.add_argument(
            '--pattern',
            type=str,
            help='Clear cache matching a pattern (requires Redis)',
        )
        parser.add_argument(
            '--all',
            action='store_true',
            help='Clear all cache',
        )

    def handle(self, *args, **options):
        if options['all']:
            CacheManager.clear_all()
            self.stdout.write(
                self.style.SUCCESS('Successfully cleared all cache')
            )
        elif options['pattern']:
            from core.cache_utils import invalidate_cache_pattern
            invalidate_cache_pattern(options['pattern'])
            self.stdout.write(
                self.style.SUCCESS(f'Successfully cleared cache pattern: {options["pattern"]}')
            )
        else:
            CacheManager.clear_all()
            self.stdout.write(
                self.style.SUCCESS('Successfully cleared all cache (default)')
            )
