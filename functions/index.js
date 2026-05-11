const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const { RtcTokenBuilder, RtcRole } = require("agora-access-token");

admin.initializeApp();

const db = admin.firestore();

// Simple in-memory rate limiter for Cloud Functions
const rateLimitMap = new Map();
const RATE_LIMIT_WINDOW_MS = 60 * 1000; // 1 minute
const RATE_LIMIT_MAX_REQUESTS = 10; // max 10 requests per IP per minute

function isRateLimited(ip) {
    const now = Date.now();
    const entry = rateLimitMap.get(ip);

    if (!entry || now - entry.windowStart > RATE_LIMIT_WINDOW_MS) {
        rateLimitMap.set(ip, { windowStart: now, count: 1 });
        return false;
    }

    entry.count++;
    if (entry.count > RATE_LIMIT_MAX_REQUESTS) {
        return true;
    }
    return false;
}

/**
 * Razorpay Webhook to handle payment.captured event securely.
 */
exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
    // Only allow POST
    if (req.method !== "POST") {
        return res.status(405).send("Method Not Allowed");
    }

    // Rate limiting
    const clientIp = req.headers["x-forwarded-for"] || req.ip;
    if (isRateLimited(clientIp)) {
        console.warn("Rate limited:", clientIp);
        return res.status(429).send("Too Many Requests");
    }

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

    // Validate amount is positive and reasonable
    if (!Number.isFinite(amountINR) || amountINR <= 0 || amountINR > 100000) {
        console.error("Invalid payment amount", amountINR);
        return res.status(400).send("Invalid payment amount");
    }

    // We expect 'userId' to be passed in the notes field from the client
    const userId = payment.notes ? payment.notes.userId : null;

    if (!userId || typeof userId !== "string" || userId.length > 128) {
        console.error("Missing or invalid userId in payment notes", paymentId);
        return res.status(400).send("Missing userId in payment notes");
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

/**
 * Push Notifications for New Help Requests
 */
exports.onNewHelpRequest = functions.firestore
    .document("requests/{requestId}")
    .onCreate(async (snap, context) => {
        const requestData = snap.data();
        const requestId = context.params.requestId;

        // Only process open requests
        if (requestData.status !== "open") return null;

        const requestedTopic = requestData.topic;
        const seekerHandle = requestData.seekerHandle || "Someone";
        const targetListenerId = requestData.listenerId;

        if (targetListenerId) {
            console.log(`Targeted request for listener: ${targetListenerId}`);
            const listenerDoc = await db.collection("users").doc(targetListenerId).get();
            if (!listenerDoc.exists || !listenerDoc.data().isOnline) {
                console.log("Targeted listener is offline or doesn't exist.");
                return null;
            }
            const token = listenerDoc.data().fcmToken;
            if (!token) return null;

            const message = {
                notification: {
                    title: "Midnight App: Someone wants to talk again! 🌙",
                    body: `${seekerHandle} would like to speak with you specifically.`
                },
                data: { requestId, isTargeted: "true" },
                token: token
            };

            await admin.messaging().send(message);
            console.log("Targeted notification sent.");
            return null;
        }

        console.log(`New broadcast request for topic: ${requestedTopic}. Finding listeners...`);

        // Find all listeners who are online and match the topic
        const listenersSnapshot = await db.collection("users")
            .where("role", "==", "listener")
            .where("isOnline", "==", true)
            .where("topics", "array-contains", requestedTopic)
            .get();

        if (listenersSnapshot.empty) {
            console.log("No matching listeners found online for topic:", requestedTopic);
            return null;
        }

        const tokens = [];
        listenersSnapshot.forEach(doc => {
            const userData = doc.data();
            if (userData.fcmToken) {
                tokens.push(userData.fcmToken);
            }
        });

        if (tokens.length === 0) {
            console.log("Found matching listeners, but none have FCM tokens.");
            return null;
        }

        console.log(`Sending broadcast notifications to ${tokens.length} listeners.`);

        const message = {
            notification: {
                title: "Midnight App: New Call Request 🌙",
                body: `${seekerHandle} is looking to talk about ${requestedTopic} right now.`
            },
            data: {
                requestId: requestId,
                topic: requestedTopic
            },
            tokens: tokens
        };

        try {
            const response = await admin.messaging().sendEachForMulticast(message);
            console.log(response.successCount + " messages were sent successfully");
            if (response.failureCount > 0) {
                console.log(response.failureCount + " messages failed");
            }
        } catch (error) {
            console.error("Error sending multicast message:", error);
        }

        return null;
    });

/**
 * Generate Agora Token for Voice Calls
 */
exports.generateAgoraToken = functions.https.onCall((data, context) => {
    // 1. Check if user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "The function must be called while authenticated."
        );
    }

    // 2. Get App ID and Certificate from Firebase Config
    const appId = functions.config().agora ? functions.config().agora.app_id : null;
    const appCertificate = functions.config().agora ? functions.config().agora.app_certificate : null;

    if (!appId || !appCertificate) {
        console.error("Agora App ID or Certificate not configured.");
        throw new functions.https.HttpsError(
            "internal",
            "Agora credentials not configured on the server."
        );
    }

    // 3. Get requested channel ID and UID
    const channelName = data.channelId;
    if (!channelName || typeof channelName !== "string") {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "The function must be called with a 'channelId'."
        );
    }

    const uid = data.uid || 0; 
    let role = RtcRole.PUBLISHER;

    // Token expires in 1 hour
    const expirationTimeInSeconds = 3600;
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

    // 4. Generate token
    const token = RtcTokenBuilder.buildTokenWithUid(
        appId,
        appCertificate,
        channelName,
        uid,
        role,
        privilegeExpiredTs
    );

    return { token: token };
});
