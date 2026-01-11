# errands/admin.py
from django.contrib import admin
from .models import Errand

@admin.register(Errand)
class ErrandAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'type', 'instructions', 'speed', 'payment_method', 'status', 'created_at')
    list_filter = ('status','type')
    search_fields = ('instructions','user__email',)
