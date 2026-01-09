# errands/admin.py
from django.contrib import admin
from .models import Errand

@admin.register(Errand)
class ErrandAdmin(admin.ModelAdmin):
    list_display = ('id', 'title', 'requester', 'status', 'budget', 'created_at')
    list_filter = ('status',)
    search_fields = ('title', 'description', 'requester__username')
