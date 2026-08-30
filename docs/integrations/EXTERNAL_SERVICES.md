# External services

## Push
Local development may use an explicit log adapter. Production must use FCM HTTP v1/APNs with credentials sourced from Vault; production must fail closed if a development adapter is selected.

## Payment
The implemented MVP path is manual bank transfer plus server-side admin verification. Provider integrations (Midtrans/Xendit/DOKU) must implement CreatePayment, GetPaymentStatus, HandleWebhook, CancelPayment and RefundPayment where supported. Webhooks require signature validation, replay protection and idempotency. Credentials come from Vault.
