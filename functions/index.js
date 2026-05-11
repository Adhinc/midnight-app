const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const { RtcTokenBuilder, RtcRole } = require("agora-access-token");

const { CloudTasksClient } = require("@google-cloud/tasks");
const tasksClient = new CloudTasksClient();

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
        const requestedLanguage = requestData.language || "English";
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

        console.log(`New broadcast for topic: ${requestedTopic} in ${requestedLanguage}. Finding listeners...`);

        // Find all listeners who are online, match topic AND language
        const listenersSnapshot = await db.collection("users")
            .where("role", "==", "listener")
            .where("isOnline", "==", true)
            .where("topics", "array-contains", requestedTopic)
            .where("languages", "array-contains", requestedLanguage)
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

/**
 * Handle call status changes to schedule payment safety checks.
 */
exports.onCallStatusUpdate = functions.firestore
    .document("requests/{requestId}")
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        const oldData = change.before.data();
        const requestId = context.params.requestId;

        // If status just changed to 'connected', schedule a safety check in 2 minutes
        if (newData.status === "connected" && oldData.status !== "connected") {
            const project = JSON.parse(process.env.FIREBASE_CONFIG).projectId;
            const location = "us-central1"; // Update to your region if different
            const queue = "payment-safety-guard";
            const queuePath = tasksClient.queuePath(project, location, queue);

            const url = `https://${location}-${project}.cloudfunctions.net/autoProcessPayment`;
            const payload = { requestId };

            // Schedule for 130 seconds from now (2 mins + 10s buffer)
            const inSeconds = 130;
            const scheduleTime = (Date.now() / 1000) + inSeconds;

            const secret = functions.config().system ? functions.config().system.task_secret : "dev_secret";
            const task = {
                httpRequest: {
                    httpMethod: "POST",
                    url,
                    body: Buffer.from(JSON.stringify(payload)).toString("base64"),
                    headers: {
                        "Content-Type": "application/json",
                        "Authorization": `Bearer ${secret}`
                    },
                },
                scheduleTime: { seconds: scheduleTime },
            };

            console.log(`Scheduling auto-payment check for request ${requestId} in ${inSeconds}s`);
            try {
                await tasksClient.createTask({ parent: queuePath, task });
            } catch (error) {
                console.error("Error scheduling Cloud Task:", error);
            }
        }
        return null;
    });

/**
 * Cloud Task handler to process abandoned calls.
 */
exports.autoProcessPayment = functions.https.onRequest(async (req, res) => {
    // 1. Security check: Only allow requests with the secret header
    const authHeader = req.headers.authorization;
    const secret = functions.config().system ? functions.config().system.task_secret : "dev_secret";
    if (authHeader !== `Bearer ${secret}`) {
        console.warn("Unauthorized attempt to hit autoProcessPayment");
        return res.status(401).send("Unauthorized");
    }

    const { requestId } = req.body;
    if (!requestId) return res.status(400).send("Missing requestId");

    try {
        const requestRef = db.collection("requests").doc(requestId);
        await db.runTransaction(async (transaction) => {
            const requestDoc = await transaction.get(requestRef);
            if (!requestDoc.exists) return;

            const data = requestDoc.data();

            // IF call is still 'connected' or 'ending' AND not yet paid
            if ((data.status === "connected" || data.status === "ending") && !data.isPaid) {
                console.log(`Auto-processing payment for abandoned request: ${requestId}`);

                const seekerId = data.seekerId;
                const listenerId = data.listenerId;
                const amount = 50; // Base session cost

                if (!seekerId || !listenerId) return;

                const seekerRef = db.collection("users").doc(seekerId);
                const listenerRef = db.collection("users").doc(listenerId);

                const seekerDoc = await transaction.get(seekerRef);
                const listenerDoc = await transaction.get(listenerRef);

                // Debit Seeker (ONLY if they have enough balance)
                const currentSeekerBalance = seekerDoc.data().walletBalance || 0;
                if (currentSeekerBalance < amount) {
                    console.log(`Seeker ${seekerId} has insufficient balance (₹${currentSeekerBalance}) for auto-debit.`);
                    // Mark as completed but UNPAID so admin can review
                    transaction.update(requestRef, {
                        status: "completed",
                        isPaid: false,
                        autoProcessed: true,
                        paymentError: "insufficient_balance",
                        completedAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                    return;
                }

                transaction.update(seekerRef, {
                    walletBalance: currentSeekerBalance - amount
                });

                // Credit Listener (assuming 60/40 split or fixed ₹30 for now)
                const currentListenerBalance = listenerDoc.data().walletBalance || 0;
                const payout = 30;
                transaction.update(listenerRef, {
                    walletBalance: currentListenerBalance + payout
                });

                // Mark as completed and paid
                transaction.update(requestRef, {
                    status: "completed",
                    isPaid: true,
                    autoProcessed: true,
                    completedAt: admin.firestore.FieldValue.serverTimestamp()
                });

                // Record transactions
                const seekerTxRef = seekerRef.collection("transactions").doc();
                transaction.set(seekerTxRef, {
                    title: "Session Payment (Auto)",
                    amount: amount,
                    date: admin.firestore.FieldValue.serverTimestamp(),
                    isCredit: false,
                    requestId: requestId
                });

                const listenerTxRef = listenerRef.collection("transactions").doc();
                transaction.set(listenerTxRef, {
                    title: "Session Earning (Auto)",
                    amount: payout,
                    date: admin.firestore.FieldValue.serverTimestamp(),
                    isCredit: true,
                    requestId: requestId
                });
            }
        });
        return res.status(200).send("Processed");
    } catch (error) {
        console.error("Auto-payment processing failed:", error);
        return res.status(500).send("Internal Server Error");
    }
});
