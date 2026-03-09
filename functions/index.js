const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();

const db = admin.firestore();

/**
 * Razorpay Webhook to handle payment.captured event securely.
 */
exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
    const secret = functions.config().razorpay.webhook_secret;
    const signature = req.headers["x-razorpay-signature"];

    if (!secret || !signature) {
        console.error("Missing secret or signature");
        return res.status(400).send("Bad Request");
    }

    // Verify signature
    const hmac = crypto.createHmac("sha256", secret);
    hmac.update(JSON.stringify(req.body));
    const generatedSignature = hmac.digest("hex");

    if (generatedSignature !== signature) {
        console.error("Signature mismatch");
        return res.status(403).send("Forbidden");
    }

    const event = req.body.event;
    if (event !== "payment.captured") {
        // Only handle captured payments for now
        return res.status(200).send("Event ignored");
    }

    const payment = req.body.payload.payment.entity;
    const paymentId = payment.id;
    const amountPaise = payment.amount; // In paise
    const amountINR = amountPaise / 100;

    // We expect 'userId' to be passed in the notes field from the client
    const userId = payment.notes ? payment.notes.userId : null;

    if (!userId) {
        console.error("Missing userId in payment notes", paymentId);
        return res.status(200).send("No userId found"); // Return 200 so Razorpay doesn't retry
    }

    try {
        const userRef = db.collection("users").doc(userId);

        await db.runTransaction(async (transaction) => {
            const userDoc = await transaction.get(userRef);

            // 1. Check if transaction already processed to prevent duplicates
            const txRef = userRef.collection("transactions").doc(paymentId);
            const txDoc = await transaction.get(txRef);

            if (txDoc.exists) {
                console.log("Transaction already processed", paymentId);
                return;
            }

            // 2. Update balance
            let currentBalance = 0;
            if (userDoc.exists) {
                currentBalance = userDoc.data().walletBalance || 0;
            }

            const newBalance = currentBalance + amountINR;

            if (!userDoc.exists) {
                transaction.set(userRef, { walletBalance: newBalance });
            } else {
                transaction.update(userRef, { walletBalance: newBalance });
            }

            // 3. Record transaction
            transaction.set(txRef, {
                id: paymentId,
                title: "Wallet Top-up",
                amount: amountINR,
                date: admin.firestore.FieldValue.serverTimestamp(),
                isCredit: true,
                status: "success",
                razorpayPaymentId: paymentId,
                verified: true
            });
        });

        console.log(`Successfully updated wallet for user ${userId} with ${amountINR} INR`);
        return res.status(200).send("OK");
    } catch (error) {
        console.error("Transaction failed", error);
        return res.status(500).send("Internal Server Error");
    }
});

// TODO: Deploy cleanupStaleCalls scheduled function before production
// See DEV_NOTES.md for implementation details
