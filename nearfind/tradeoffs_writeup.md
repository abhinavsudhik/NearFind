# NearFind Architecture Tradeoffs & Roadmap

For this prototype, we opted for client-side timers running on the customer's device to trigger order cancellations when acceptance windows expire. While client-side timers are significantly simpler to build and sufficient for demo validation, they introduce a major architectural vulnerability: if a user closes the app, kills the process, or loses internet connectivity, the timer lifecycle fails, leaving expired orders in an orphaned state.

In a production environment, this business logic must run server-side. We would implement Firebase Cloud Functions triggered by Firestore document writes. When an order is placed, a Cloud Function would schedule a task using Google Cloud Tasks or Firebase Extensions (like Firestore Scheduled Writes) to check the order status after the target duration (e.g., 2 or 3 minutes) and execute the cancellation atomically.

With more time, our next priorities would be:
1. **Dynamic Geolocation:** Replacing static store coordinates with real-time location indexing to query stores within a set radius.
2. **Push Notifications:** Integrating Firebase Cloud Messaging (FCM) to alert delivery partners and retailers of new orders, replacing passive stream polling.
3. **Multi-Retailer Onboarding:** Implementing proper authentication, profiles, and routing for separate merchant accounts.
4. **Payment Gateway:** Integrating Stripe or Razorpay to support secure checkouts before orders enter the retailer queue.
