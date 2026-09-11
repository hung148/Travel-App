# NghienTravel traveler check

Use a verified test account and a development build. The production AI endpoints
are deployed, but authenticated end-to-end acceptance is still outstanding.
Do not paste passwords, payment card details, or API keys into an itinerary.

## Existing itinerary

1. From your profile, choose **Add my existing plan**.
2. Choose Da Nang, September 18–19, 2026, and `Asia/Ho_Chi_Minh`.
3. Paste this fictional example:

   ```text
   2026-09-18 08:30 Airport pickup. Meet at Terminal 1 exit.
   Provider: Example Transfer. Booking reference: DEMO-PICKUP-18.
   2026-09-18 14:00 Hotel check-in. Provider: Example Hotel.
   Booking reference: DEMO-HOTEL-18. Ask reception about breakfast.
   2026-09-19 Museum visit. Time to be confirmed.
   ```

4. Review every extracted field. The museum time should remain unknown.
   Mark a booking confirmed only after checking its details.
5. Edit the pickup time to 09:00. Add a custom activity. Move or remove an item.
   An item without coordinates should remain usable without a map marker.
6. Approve and save. Leave the page, close the app, reopen it, and open the trip.
7. Check dates, times, references, notes, and confirmed status persisted.
8. Open **Today** and browse to September 18. Verify the pickup is listed at
   09:00 before the hotel. Browse September 19 and check the unknown time.
9. Use **Edit plan → Edit bookings and schedule** to add known coordinates
   to one item. Save and try **Open directions**. Check the destination in maps.
10. Open an older generated trip. Check its itinerary and map, then use
    **Edit plan → Refine with planner**. A confirmed booking must not be
    silently moved, removed, or changed by an AI proposal.

Record the device/browser, step, expected result, actual result, and whether
you could recover. Include screenshots only if booking/contact details are hidden.
Please also say which part was confusing or took too long.

## Chrome account-deletion check (developer or owner)

Use a disposable account you control in development; never a traveler's account.

1. Register, verify email, and save a trip with multiple itinerary days.
2. Add preferences and disposable feedback/community content where available.
3. Record the account UID locally, then delete the account from the Chrome app.
4. Confirm sign-in no longer works and Authentication no longer lists that UID.
5. In Firestore, verify the UID has no remaining profile, owned trips,
   itineraries, preferences, feedback, reviews, or tips. Check both owner fields
   and itinerary parent trip IDs. Other accounts' data must still exist.
6. Record success or the exact failing step. Automated deletion tests already
   pass, but this checks the browser Firebase Auth path and actual cloud data.
