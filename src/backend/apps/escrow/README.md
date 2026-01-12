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

The escrow system is integrated with **Flutterwave** payment gateway:

### Automatic Integration
- **Escrow Creation**: Payment is automatically initialized when escrow is created
- **Escrow Release**: Funds are transferred to runner when errand is completed (requires runner's bank details)
- **Escrow Refund**: Funds are automatically refunded to buyer when errand is cancelled/expired

### Manual Payment Operations

You can also manually initialize payments and verify transactions using GraphQL mutations:

```graphql
# Initialize payment
mutation {
  initializePayment(escrowId: "1") {
    paymentLink
    transactionId
  }
}

# Verify payment
mutation {
  verifyPayment(transactionId: "123", escrowId: "1") {
    success
    paymentStatus
  }
}

# Transfer to runner (when errand completed)
mutation {
  transferToRunner(
    escrowId: "1"
    accountNumber: "1234567890"
    bankCode: "044"
    accountName: "John Doe"
  ) {
    success
    transferId
  }
}
```

See `apps/payments/README.md` for detailed Flutterwave integration documentation.

## Database Migrations

Run migrations to create the escrow tables:
```bash
python manage.py migrate escrow
python manage.py migrate errands
```
