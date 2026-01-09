from django.contrib import admin
from django.contrib.auth import get_user_model
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin

User = get_user_model()

@admin.register(User)
class UserAdmin(DjangoUserAdmin):
    # Align list display and searches with custom fields
    list_display = ('email', 'name', 'is_staff', 'is_active', 'created_at')
    search_fields = ('email', 'name')
    list_filter = ('is_staff', 'is_superuser', 'is_active', 'groups')
    ordering = ('-created_at', 'email')
    readonly_fields = ('created_at', 'updated_at', 'last_login')

    # Keep DjangoUserAdmin fieldsets but ensure email is used as username field
    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal info', {'fields': ('name', 'avatar')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Important dates', {'fields': ('last_login', 'created_at', 'updated_at')}),
        ('Roles', {'fields': ('roles',)}),
    )
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'name', 'password1', 'password2', 'is_staff', 'is_active'),
        }),
    )
