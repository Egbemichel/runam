from django.contrib import admin
from django.contrib.auth import get_user_model
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin

User = get_user_model()

@admin.register(User)
class UserAdmin(DjangoUserAdmin):
    # Use Django's default UserAdmin behavior but expose common columns/search
    list_display = ('username', 'email', 'first_name', 'last_name', 'is_staff', 'is_active')
    search_fields = ('username', 'email', 'first_name', 'last_name')
    list_filter = ('is_staff', 'is_superuser', 'is_active', 'groups')
    ordering = ('-date_joined', 'username')
    readonly_fields = ('date_joined', 'last_login')

    # Inherit add/edit fieldsets from DjangoUserAdmin
    fieldsets = DjangoUserAdmin.fieldsets
    add_fieldsets = DjangoUserAdmin.add_fieldsets
