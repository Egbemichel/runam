# errands/admin.py
from django.contrib import admin
from .models import Errand

@admin.register(Errand)
class ErrandAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'type', 'task_count', 'speed', 'payment_method', 'status', 'created_at')
    list_filter = ('status','type')
    search_fields = ('user__email',)

    def task_count(self, obj):
        return obj.tasks.count()

    task_count.short_description = "Tasks"