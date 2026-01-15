# Gamification Feature Spec

## Overview

Add subtle gamification elements to encourage consistent workout habits without being intrusive or distracting from the core exercise tracking experience.

## Design Principles

1. **Subtle over flashy**: Gamification should feel like a natural part of the UI, not an interruption
2. **Informative, not pushy**: Show progress without guilt-tripping missed days
3. **Personal progress focus**: Compare against yourself, not others
4. **Discoverable**: Users notice elements organically rather than being forced to engage
5. **Non-blocking**: Never require interaction to continue using the app

## Features

### 1. Workout Streaks

Track consecutive days with at least one completed workout.

**Display:**
- Small flame/streak icon with day count on the home screen
- Icon appears only after 2+ consecutive days (no "1 day streak" clutter)
- Muted color scheme (amber/orange) that doesn't dominate the UI

**Behavior:**
- Streak resets at midnight local time if no workout completed
- Grace period: after 7 consecutive workout days, user gets 1 rest day that doesn't break the streak
- No notifications or pop-ups about streak status
- Streak history viewable in statistics (longest streak, current streak)

**Edge cases:**
- Rest days don't break streaks if earned (see grace period above)
- Multiple workouts per day count as one day toward streak
- Grace day resets after being used (next grace day earned after another 7 consecutive days)

### 1b. Smart Rest Day Suggestions

Based on exercise science recommendations, suggest rest days based on workout volume.

**Research basis:**
- Under 30 reps/day: daily training is generally safe
- 70-100+ reps/day: rest days recommended (48-72 hour muscle recovery)
- Training to failure: 48-72 hours between sessions optimal
- General guideline: 3-5 workout days per week

**Display:**
- Subtle hint on home screen when rest is recommended: "Recovery day suggested"
- Only shown after high-volume sessions (70+ reps) on consecutive days
- Non-blocking, purely informational

**Behavior:**
- Analyze last 3 days of workout volume
- If 2+ consecutive days with 70+ reps each → suggest rest
- If any session in last 48 hours was marked as "high effort" → suggest rest
- Suggestion disappears after 24 hours or next workout, whichever comes first

### 2. Personal Bests

Track and subtly highlight when users achieve personal records.

**Tracked metrics:**
- Most reps in a single session (per exercise type)
- Longest workout duration
- Best rep pace (reps per minute)
- Highest single-day total reps

**Display:**
- Small "PB" badge appears next to the metric on workout completion screen
- Badge is subtle (small crown icon or simple "PB" text)
- No celebratory animation or modal - just a visual indicator
- Personal bests listed in statistics screen

**Behavior:**
- Only count valid reps toward personal bests
- Ties don't trigger PB indicator (must exceed previous best)

### 3. Progressive Challenge: Beat Yesterday

Encourage incremental improvement by showing yesterday's performance.

**Display:**
- During workout: small text showing "Yesterday: X reps" below the main counter
- Only shown if user worked out yesterday (same exercise type)
- Text changes to subtle checkmark when yesterday's count is exceeded
- No color change or animation when goal is met - just the indicator swap

**Behavior:**
- Compares same exercise type only (pushups vs pushups)
- Optional: can be disabled in settings
- No penalty or negative indicator if goal isn't met

### 4. Milestone Markers

Celebrate cumulative achievements without interruption.

**Milestones tracked:**
- Total reps (all time): 10, 100, 500, 1,000, 2,500, 5,000, 10,000, etc.
- Total workouts completed: 10, 25, 50, 100, etc.
- Total workout time: 1hr, 5hr, 10hr, 24hr, etc.

**Display:**
- Milestone achievements shown as a small banner at top of home screen after next app open
- Banner is dismissible with a tap or auto-dismisses after 3 seconds
- Milestone badges collected in a "Achievements" section within statistics
- Badges use simple, monochrome icons (not colorful game-style badges)

**Behavior:**
- Milestones only trigger once (no re-earning)
- No sound or haptic feedback for milestones
- Achievement section is a simple list, not a trophy case

### 5. Weekly Summary Card

Provide weekly perspective on workout consistency.

**Display:**
- Shown on home screen on Mondays (or first app open of the week)
- Small card showing:
  - Days active last week (e.g., "4 of 7 days")
  - Total reps last week
  - Comparison to previous week ("+12% reps" or just raw numbers)
- Card is dismissible and doesn't reappear once dismissed

**Behavior:**
- Week runs Monday to Sunday
- No judgment language ("Great job!" or "You missed days")
- Pure data presentation

## UI Integration

### Home Screen
```
┌─────────────────────────────┐
│  [Weekly Summary Card]      │  ← Dismissible, Mondays only
├─────────────────────────────┤
│                             │
│   🔥 5 day streak           │  ← Small, top corner
│                             │
│   [ Start Workout ]         │
│                             │
│   Recent: 25 pushups        │
│   Yesterday: 22 pushups     │  ← Subtle reference
│                             │
└─────────────────────────────┘
```

### Workout Complete Screen
```
┌─────────────────────────────┐
│                             │
│        28 reps              │
│        ᴾᴮ                   │  ← Tiny PB indicator if applicable
│                             │
│   Duration: 2:34            │
│   Invalid: 2                │
│                             │
│   Yesterday: 25 ✓           │  ← Checkmark if beaten
│                             │
│   [ Done ]    [ Share ]     │
│                             │
└─────────────────────────────┘
```

### Statistics Screen Addition
```
Achievements section:
- Current streak: 5 days
- Longest streak: 12 days
- Personal bests:
  - Pushups: 45 reps (Jan 10)
  - Burpees: 18 reps (Jan 8)
- Milestones reached: 4/12
  [100 reps ✓] [500 reps ✓] [1000 reps] [10 workouts ✓] ...
```

## Data Model Changes

### New Fields in Database

**User Preferences Table** (new):
```sql
CREATE TABLE user_preferences (
  key TEXT PRIMARY KEY,
  value TEXT
);
-- Keys: 'show_yesterday_comparison', 'gamification_enabled'
```

**Achievements Table** (new):
```sql
CREATE TABLE achievements (
  id TEXT PRIMARY KEY,           -- e.g., 'milestone_1000_reps'
  type TEXT,                     -- 'milestone', 'personal_best', 'streak'
  achieved_at TEXT,              -- ISO 8601 timestamp
  value INTEGER                  -- The value when achieved
);
```

**Streak Tracking:**
- Calculate from workouts table (no separate storage needed)
- Query: consecutive days with at least one workout, counting backward from today

**Personal Bests:**
- Calculate from workouts table using MAX queries
- Cache in achievements table for quick access

## Settings

Add a "Gamification" section in settings:

- **Show streak counter**: Toggle (default: on)
- **Show "Beat Yesterday" comparison**: Toggle (default: on)
- **Show milestone notifications**: Toggle (default: on)

Master toggle: "Enable all gamification features" that controls all above

## Implementation Priority

1. **Phase 1**: Streak tracking and display (foundational, low complexity)
2. **Phase 2**: Personal bests detection and display
3. **Phase 3**: Beat Yesterday comparison
4. **Phase 4**: Milestones and achievements
5. **Phase 5**: Weekly summary card

## Out of Scope (Future Considerations)

- Social features / leaderboards (conflicts with privacy-first approach)
- Daily challenges or suggested workouts
- Push notifications about streaks or achievements
- Rewards or unlockables
- Sounds or complex animations for achievements

## Open Questions

1. ~~Should rest days be a feature to preserve streaks intentionally?~~ **Resolved**: Yes, earned after 7 consecutive days
2. ~~Is the 4-hour grace period for streaks appropriate?~~ **Resolved**: Changed to 1 rest day after 7 consecutive workout days
3. Should personal bests be per-workout-mode (Timer/Rep Goal/Free) or combined?
4. How prominent should the streak indicator be - always visible or only on hover/tap?
5. Should the 70+ rep threshold for rest suggestions be configurable based on user fitness level?
