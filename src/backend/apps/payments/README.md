# Flutterwave Payment Gateway Integration

This app provides Flutterwave payment gateway integration for the RunAm platform.

## Overview

The payment gateway handles:
1. **Payment Initialization**: Create payment links for escrow transactions
2. **Payment Verification**: Verify payment status after customer payment
3. **Funds Transfer**: Transfer escrow funds to runner's bank account
4. **Refunds**: Process refunds when errands are cancelled or expired

## Configuration

Add the following environment variables to your `.env` file:

```bash
# Flutterwave API Keys (get from https://dashboard.flutterwave.com)
FLUTTERWAVE_SECRET_KEY=your_secret_key_here
FLUTTERWAVE_PUBLIC_KEY=your_public_key_here
FLUTTERWAVE_ENCRYPTION_KEY=your_encryption_key_here  # Optional
FLUTTERWAVE_SECRET_HASH=your_secret_hash_here  # For webhook signature verification

# Payment Settings
FLUTTERWAVE_CURRENCY=NGN  # Default: NGN
FLUTTERWAVE_TEST_MODE=True  # Set to False for production
FLUTTERWAVE_LOGO_URL=https://your-domain.com/logo.png  # Optional
FRONTEND_URL=http://localhost:3000  # For payment redirects
```

### Webhook Setup

1. **Configure Webhook URL in Flutterwave Dashboard**:
   - Go to Settings > Webhooks
   - Add webhook URL: `https://your-domain.com/webhooks/flutterwave/`
   - Select events: `charge.completed`, `transfer.completed`, `transfer.reversed`
   - Copy the secret hash and add to `FLUTTERWAVE_SECRET_HASH` in `.env`

2. **Webhook Endpoint**: `/webhooks/flutterwave/`
   - Automatically handles payment confirmations
   - Updates escrow status when payments complete
   - Logs transfer completions and reversals

## Usage

### 1. Initialize Payment for Escrow

When an errand is accepted and escrow is created, payment is automatically initialized. You can also initialize manually:

```graphql
mutation {
  initializePayment(escrowId: "1") {
    success
    paymentLink
    transactionId
    txRef
    message
  }
}
```

### 2. Verify Payment

After customer completes payment, verify the transaction:

```graphql
mutation {
  verifyPayment(
    transactionId: "1234567890"
    escrowId: "1"
  ) {
    success
    paymentStatus
    amount
    message
  }
}
```

### 3. Transfer Funds to Runner

When errand is completed, transfer funds to runner. You can either use runner's saved account or provide details:

```graphql
# Option 1: Use runner's saved bank account
mutation {
  transferToRunner(
    escrowId: "1"
    useSavedAccount: true
  ) {
    success
    transferId
    message
  }
}

# Option 2: Provide bank account details manually
mutation {
  transferToRunner(
    escrowId: "1"
    accountNumber: "1234567890"
    bankCode: "044"  # Flutterwave bank code
    accountName: "John Doe"
  ) {
    success
    transferId
    message
  }
}

# Get list of banks
query {
  banks(country: "NG") {
    code
    name
  }
}
```

**Note**: If runner has saved bank account details, escrow release will automatically transfer funds. Otherwise, use the manual transfer mutation.

### 4. Manage Bank Account (for Runners)

Runners can save their bank account details for automatic transfers:

```graphql
mutation {
  updateBankAccount(
    accountNumber: "1234567890"
    bankCode: "044"
    accountName: "John Doe"
  ) {
    success
    message
  }
}

# Get bank account details (masked)
query {
  me {
    bankAccount {
      accountNumber  # Masked (shows last 4 digits)
      bankCode
      accountName
      hasAccount
    }
  }
}
```

### 5. Refunds

Refunds are automatically processed when errands are cancelled or expired. The escrow service handles this automatically.

## Integration with Escrow

The payment gateway is integrated with the escrow system:

- **Escrow Creation**: Payment is initialized automatically when escrow is created
- **Escrow Release**: Funds are transferred to runner when errand is completed
- **Escrow Refund**: Funds are refunded to buyer when errand is cancelled/expired

## API Reference

### FlutterwaveService Methods

#### `initialize_payment(amount, email, tx_ref, ...)`
Initialize a payment transaction.

#### `verify_payment(transaction_id)`
Verify a payment transaction status.

#### `transfer_funds(amount, recipient_account_number, recipient_bank_code, ...)`
Transfer funds to a recipient bank account.

#### `refund_payment(transaction_id, amount=None, comments=None)`
Refund a payment transaction.

#### `get_banks(country='NG')`
Get list of banks for a country.

## Testing

For testing, use Flutterwave's test credentials:
- Test cards: https://developer.flutterwave.com/docs/test-cards
- Test bank accounts: Use Flutterwave's test bank accounts

## Production Checklist

- [ ] Set `FLUTTERWAVE_TEST_MODE=False`
- [ ] Use production API keys
- [ ] Configure proper `FRONTEND_URL` for payment callbacks
- [ ] Set up webhook endpoints for payment notifications (optional)
- [ ] Test payment flow end-to-end
- [ ] Set up monitoring and logging

## Error Handling

All payment operations include comprehensive error handling:
- API failures are logged with full details
- User-friendly error messages are returned
- Escrow operations continue even if payment operations fail (can be retried)

## Security Notes

- Never expose secret keys in frontend code
- Always verify payment status server-side
- Use HTTPS in production
- Validate all payment callbacks
- Implement rate limiting for payment endpoints
