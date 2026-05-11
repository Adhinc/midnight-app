# 🚨 CRITICAL PRODUCTION BLOCKERS 🚨

**DO NOT RELEASE THIS APP TO THE PLAY STORE UNTIL THESE ITEMS ARE COMPLETED.**

Because the Firebase project is currently on the free "Spark" plan, we had to pause the deployment of critical backend infrastructure. Once you upgrade your Firebase project to the "Blaze" plan, you must complete the following checklist:

## 1. Deploy Agora Token Server
- [ ] Ensure `agora.app_id` and `agora.app_certificate` are set in Firebase Functions config.
- [ ] Run `firebase deploy --only functions` in the `functions/` directory.
- *Why:* Prevents hackers from using your App ID to run up massive Agora voice calling bills.

## 2. Deploy Razorpay Webhook
- [ ] Write the `payment.captured` webhook in `functions/index.js` to securely credit `walletBalance`.
- [ ] Ensure `razorpay.webhook_secret` is set in Firebase Functions config.
- [ ] Deploy the function.
- *Why:* Prevents users from simulating fake successful payments on their phone to get free wallet funds.

## 3. Implement Strict Firestore Security Rules
- [ ] Update `firestore.rules` to completely block the mobile app from writing to `walletBalance` or the `transactions` collection.
- *Why:* Prevents malicious users from manually editing the database to give themselves ₹99,999. 

## 4. Deploy Push Notifications
- [ ] Write a Cloud Function that listens for new documents in the `requests` collection.
- [ ] Send FCM (Firebase Cloud Messaging) payloads to online listeners matching the requested topic.
- [ ] Deploy the function.
- *Why:* Listeners will not know someone is requesting a call unless the app is actively open on their screen.

## 5. Listener Payouts System
- [ ] Decide on a payout method (RazorpayX, manual UPI transfers, etc.).
- [ ] Connect the "Withdraw" button in `wallet_screen.dart` to a backend payout function or an admin dashboard.
- *Why:* Currently, the withdraw button just deletes funds from the wallet locally; it doesn't actually send real money to the listener's bank account.
