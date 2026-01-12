# Escrow Implementation

This app implements escrow logic for holding funds during errand transactions.

## Overview

The escrow system ensures that:
1. Funds are held securely when an errand is accepted by a runner
2. Funds are released to the runner when the errand is completed
3. Funds are refunded to the buyer if the errand is cancelled or expires

## Models

### Escrow
- **errand**: OneToOne relationship with Errand
- **buyer**: User who created the errand
- **runner**: User who accepted the errand (nullable)
- **amount**: Decimal amount held in escrow
- **status**: PENDING, RELEASED, REFUNDED, or CANCELLED
- **transaction_id**: External payment gateway transaction ID (optional)

## Services

### `create_escrow(errand, amount, runner=None)`
Creates an escrow when an errand is accepted (status changes to IN_PROGRESS).

### `release_escrow(errand, transaction_id=None)`
Releases funds to the runner when errand is completed (status changes to COMPLETED).

### `refund_escrow(errand, transaction_id=None)`
Refunds funds to the buyer when errand is cancelled or expired.

### `handle_errand_status_change(errand, old_status, new_status, runner=None)`
Main handler that automatically manages escrow based on errand status changes.

## Integration

The escrow logic is automatically triggered when:
- Errand status changes to `IN_PROGRESS` → Creates escrow
- Errand status changes to `COMPLETED` → Releases escrow
- Errand status changes to `CANCELLED` or `EXPIRED` → Refunds escrow

## GraphQL API

### Queries
- `myEscrows`: Get all escrows for the current user (as buyer or runner)
- `escrow(errandId)`: Get escrow for a specific errand

### Mutations
- `acceptErrand(errandId)`: Accept an errand (creates escrow if price exists)
- `updateErrand`: Update errand (handles escrow automatically on status change)

## Payment Gateway Integration

The escrow service includes placeholder comments for payment gateway integration:
- TODO: Integrate with payment gateway to actually transfer funds
- TODO: Integrate with payment gateway to actually refund funds

To integrate with a payment gateway (e.g., Stripe, PayPal):
1. Update `release_escrow()` to call payment gateway API
2. Update `refund_escrow()` to call payment gateway refund API
3. Store transaction IDs in the `transaction_id` field

## Database Migrations

Run migrations to create the escrow tables:
```bash
python manage.py migrate escrow
python manage.py migrate errands
```
