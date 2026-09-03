# Travel Planner

Travel Planner is a Flutter application for building personalized,
multi-destination trips. It combines traveler preferences, destination dates,
budgets, hotels, places, routes, and daily schedules in one planning flow.

## What the app does

- Creates trips with multiple destinations.
- Searches for destinations at the city, state, or country level.
- Keeps independent dates, budgets, hotels, and schedules for every destination.
- Orders destinations chronologically and prevents overlapping date selections.
- Estimates driving or flight time between destinations.
- Includes multi-day travel time when determining available destination dates.
- Generates day-by-day itineraries from traveler preferences and budget.
- Recommends nearby hotels, dining, and activities using Google place data.
- Displays itinerary stops and daily routes on an interactive map.
- Lets users edit travel estimates, hotels, destinations, and generated schedules.
- Saves each destination schedule independently.
- Combines every destination into a complete trip review with costs and global
  day numbering.
- Saves multi-destination trips so their hotels and schedules can be restored.

## AI travel planner

The built-in travel assistant helps users refine a generated destination plan
with natural-language requests such as:

- Make the trip cheaper.
- Make day 2 more relaxed.
- Add more food stops.
- Remove museums.
- Reduce walking.

The assistant proposes a structured change before modifying the trip. The user
can apply or cancel the proposal, and accepted itinerary changes are checked by
the planner's deterministic budget and schedule validation rules.

## Typical planning flow

1. Sign in and save travel preferences.
2. Add the first destination.
3. Choose its dates, budget, travelers, and hotel.
4. Generate and review its daily schedule.
5. Refine the schedule manually or with the AI travel planner.
6. Save the destination schedule.
7. Add more destinations and repeat the process.
8. Review the complete trip, destination subtotals, and estimated total cost.
9. Save the trip for later.

## Planning principles

- Each destination owns its own hotel, budget, dates, and itinerary.
- The AI interprets requests but does not directly invent or write trip data.
- Planner validation remains responsible for schedule and budget safety.
- Approximate prices and travel times remain editable by the user.
- Live hotel room pricing is not presented as guaranteed booking data.
