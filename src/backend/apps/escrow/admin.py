from django.contrib import admin
from .models import Escrow


@admin.register(Escrow)
class EscrowAdmin(admin.ModelAdmin):
    list_display = ('id', 'errand', 'buyer', 'runner', 'amount', 'status', 'created_at')
    list_filter = ('status', 'created_at')
    search_fields = ('errand__id', 'buyer__email', 'runner__email', 'transaction_id')
    readonly_fields = ('created_at', 'released_at', 'refunded_at', 'updated_at')
    
    fieldsets = (
        ('Basic Information', {
            'fields': ('errand', 'buyer', 'runner', 'amount', 'status')
        }),
        ('Transaction Details', {
            'fields': ('transaction_id',)
        }),
        ('Timestamps', {
            'fields': ('created_at', 'released_at', 'refunded_at', 'updated_at')
        }),
    )
