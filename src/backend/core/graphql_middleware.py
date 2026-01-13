"""
GraphQL Middleware for Rate Limiting

Provides operation-level rate limiting for GraphQL queries and mutations.
"""

import logging
from graphql import GraphQLError
from graphql.type import GraphQLResolveInfo
from core.graphql_rate_limit import graphql_rate_limiter

logger = logging.getLogger(__name__)


class RateLimitGraphQLMiddleware:
    """
    GraphQL middleware that applies rate limiting to operations.
    
    Checks rate limits before executing queries and mutations.
    Compatible with Graphene's middleware system.
    """
    
    def resolve(self, next, root, info: GraphQLResolveInfo, **args):
        """
        Intercept GraphQL resolution to check rate limits.
        
        Args:
            next: Next resolver in the chain
            root: Root value
            info: GraphQL resolve info containing operation details
            **args: Additional arguments
        """
        # Skip rate limiting for introspection queries
        if info.field_name.startswith('_'):
            return next(root, info, **args)
        
        # Get operation name and type from the operation definition
        operation_name = None
        operation_type = None
        
        if hasattr(info, 'operation') and info.operation:
            operation_name = info.operation.name.value if info.operation.name else None
            operation_type = info.operation.operation
        
        # Get field name (mutation/query name)
        field_name = info.field_name if hasattr(info, 'field_name') else None
        
        # Use field name as operation name if available
        if field_name and not operation_name:
            operation_name = field_name
        
        # Determine operation type from field name or operation
        if not operation_type:
            if field_name:
                # Check if it's a mutation (mutations typically start with verbs)
                mutation_keywords = ['create', 'update', 'delete', 'accept', 'initialize', 
                                    'verify', 'transfer', 'register', 'unregister', 'save']
                if any(field_name.lower().startswith(keyword) for keyword in mutation_keywords):
                    operation_type = 'mutation'
                else:
                    operation_type = 'query'
            else:
                operation_type = 'query'
        
        # Check rate limit
        if operation_name:
            try:
                request = info.context
                is_limited, remaining, reset_time, error_message = graphql_rate_limiter.check_rate_limit(
                    request=request,
                    operation_name=operation_name,
                    operation_type=operation_type
                )
                
                if is_limited:
                    user_id = getattr(request.user, 'id', None) if hasattr(request, 'user') else None
                    logger.warning(
                        f"Rate limit exceeded: user={user_id or 'anonymous'}, "
                        f"operation={operation_name}, type={operation_type}"
                    )
                    raise GraphQLError(
                        error_message or "Rate limit exceeded. Please try again later.",
                        extensions={
                            'code': 'RATE_LIMIT_EXCEEDED',
                            'operation': operation_name,
                            'type': operation_type,
                            'resetAt': int(reset_time) if reset_time else None,
                        }
                    )
            except AttributeError:
                # If context doesn't have request, skip rate limiting
                logger.debug("No request context available for rate limiting")
            except Exception as e:
                # Don't break the request if rate limiting fails
                logger.error(f"Error in rate limiting middleware: {e}", exc_info=True)
        
        # Continue with normal resolution
        return next(root, info, **args)
