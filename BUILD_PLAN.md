# Let Me Know — Build Plan

Team 14 (UGBA 190D): Arissa Zheng, Arushi Desai, Kevin Padilla, Adonis Som, Runn Kiriruangchai, Sarah Elnahas

## 1. Scope: what the prototype includes

Everything below comes from the Week 11 pitch deck or the Week 10 ideation template. Nothing else is in scope.

| # | Feature | Source |
|---|---------|--------|
| F1 | Sign in with a verified campus email | Ideation: "log on through their verified campus email" |
| F2 | Map view of the college town | Ideation: "enter a map view of their college town" |
| F3 | Pins for live student reports from the last 24 hours. Tap a pin to read it (text, image, and/or video). | Deck: Solution. Ideation: "visual pins of live reportings from the last 24 hours" |
| F4 | Report an incident | Deck: "report and view incidents". Test task: "Report an issue about being followed near Moffitt" |
| F5 | Destination search at the top of the map | Ideation: "At the top of the map, users will be able to enter a location". Deck Next Steps #3 |
| F6 | Suggested safer routes that avoid live incidents, unlit streets, and sparsely populated areas | Deck: Solution. Ideation: "see suggested routes, avoiding reported live incidents" |
| F7 | Settings page with route preferences (avoid poor lighting, prefer less crowded, etc.) | Ideation: "in a settings page, users can turn on preferences" |
| F8 | Routes self-correct when new incident reports come in | Ideation: "Routes will be able to self-correct based on live incident reports" |

The three route mockups in the ideation template set the visual direction: a green route line, red incident pins, a filter control at the top right, and a tapped pin that shows a callout.

### Not in scope
Anything that isn't in the materials above. That includes SOS or emergency-call buttons, friend tracking, chat, upvotes, comments, push notifications, WarnMe ingestion, and moderation tooling. If we want any of these later, we add them to the deck first.

### Open questions for the team (the deck doesn't specify these)
- **Incident types:** Should a report carry a category (for example *followed*, *harassment*, *aggressive behavior*)? The pain-points slide lists types, but neither document defines a picker. Default: free text plus optional media, no categories.
- **Anonymity:** Do reports show who posted them? Default: anonymous to other users, tied to a verified account behind the scenes.
- **"Sparsely populated" data:** The ideation template says "preference-based location tracking." In a prototype with no real users, crowd density has to come from seeded or simulated pings. See §2.3.

## 2. Data sources: access check (Nov 17, 2026)

### 2.1 Berkeley streetlights: ✅ free, no key needed
- The portal page `w9v4-y3pu` is only a map visualization. The data behind it is dataset **`dz4s-un9u`** ("Streetlights20170921").
- Socrata API, no authentication:
  - JSON: `https://data.cityofberkeley.info/resource/dz4s-un9u.json?$limit=50000`
  - GeoJSON: `https://data.cityofberkeley.info/resource/dz4s-un9u.geojson?$limit=50000` (about 8 MB)
- **7,850 lights.** Useful fields: `latitude`, `longitude`, `wattage`, `condition`, `heads`, `mounting_h`, `address`, `group`.
- ⚠️ **Caveat 1, the data is old.** The latest install and audit dates are 2015, from the LED conversion. The data doesn't show outages.
- ⚠️ **Caveat 2, the central campus is barely covered.** Only about 30 lights fall inside the core campus box, against about 330 on Southside. UC owns campus path lighting, and the city doesn't publish it. Fill the gap with OpenStreetMap `lit=yes/no` tags on footways. Valhalla's pedestrian costing can read these.
- Plan: download a snapshot once into `data/streetlights.geojson`, then score each street segment by the lamps within about 30 m.

### 2.2 Maps and routing

**Google Maps Platform** (pricing as of 2026; Google replaced the old $200 credit with free caps per SKU):

| SKU | Free per month | After the cap |
|-----|----------------|---------------|
| Maps SDK (native iOS/Android map) | Unlimited | — |
| Dynamic Maps (JavaScript/web map) | 10,000 loads | $7 / 1k |
| Routes: Compute Routes Essentials | 10,000 | $5 / 1k |
| Routes: Compute Routes Pro | 5,000 | $10 / 1k |
| Places Autocomplete (New) | 10,000 | $2.83 / 1k |
| Geocoding | 10,000 | $5 / 1k |

- A class prototype easily stays at **$0**. However, Google requires a Cloud billing account with a credit card on file just to get an API key.
- ⚠️ **Blocker for F6:** Google's route modifiers only offer avoid tolls, highways, ferries, and indoor. **You can't tell Google to avoid an area or a point.** The workaround is to ask for alternative routes, then rescore them ourselves by incidents, lamps, and crowd density. That works poorly on a walkable grid where Google returns one or two near-identical walking options.

**Free and open-source options** (all on GitHub, all built on OpenStreetMap):

| Tool | Avoid incident areas? | Lighting | Hosting | Notes |
|------|-----------------------|----------|---------|-------|
| **Valhalla** (`valhalla/valhalla`) | ✅ `exclude_polygons`, `exclude_locations` | ✅ pedestrian `use_lit` (OSM lit tags) | Docker, self-hosted | Best fit for F6 and F8 |
| **GraphHopper** (`graphhopper/graphhopper`) | ✅ custom model `areas` with priority multipliers | Via custom model | Java, self-hosted | Can *penalize* areas instead of banning them |
| **openrouteservice** (`GIScience/openrouteservice`) | ✅ `avoid_polygons` (works with foot-walking) | ❌ | Free hosted API with a key (about 2,000 directions a day), or self-host | Quickest way to start: no server needed |
| OSRM | ❌ | ❌ | — | Not suitable |

**Map display:** Apple **MapKit** is free in a native iOS app with no key or billing. On the web, **MapLibre** plus OpenFreeMap tiles is free.

**Original recommendation (superseded by §3):** Use **MapKit** to draw the map and run search and autocomplete (MKLocalSearchCompleter), and use **openrouteservice** to compute routes with `avoid_polygons` built from the last 24 hours of reports. Weight the result with our own streetlight and crowd score. This is $0, needs no credit card, and avoiding incidents works out of the box. Swap in a self-hosted Valhalla later if we want `use_lit` and finer weighting. *(Update Nov 19: we use Valhalla now. See §3.)*

### 2.3 Crowd density ("sparsely populated areas")
- No free public source gives pedestrian density per street. Google's Popular Times isn't available through any API.
- Per the ideation template, the app collects opt-in location pings from its own users and shows them as the blue glow (§3). **For the prototype, seed simulated pings** (dense on Telegraph, Bancroft, and Sproul in the evening; sparse on side streets at night) and label them as simulated in the UI copy.

### 2.4 Live incident reports
- These need a shared backend so one student's report appears for everyone (F3, F8).
- **Supabase free tier** (chosen): Postgres with PostGIS for "reports within the route corridor," Storage for photos and video, Realtime for live pin updates, and Auth email OTP restricted to `@berkeley.edu` (F1). Cost: $0.
- Seed it with sample reports based on the research (for example "followed near Moffitt," "aggressive man with bullwhip near Telegraph," "man shoved student on walk to campus"), marked as demo data.

## 3. Decisions (Nov 17, 2026)

| Area | Decision | Why |
|------|----------|-----|
| Platform | Native **SwiftUI** app for iOS 26 | Liquid Glass (`.glassEffect`) is built into the framework |
| Map + heat maps | **Google Maps SDK for iOS** plus the `google-maps-ios-utils` heat map layer | Matches the deck. The native map SDK is free with no usage cap. The heat map layer takes custom color gradients and handles all 7,850 lamps. |
| Destination search | **Google Places API (New) autocomplete** | 10k free requests a month, and the deck names Google |
| Safe routing | **Valhalla** pedestrian routing on the free public FOSSGIS server (`valhalla1.openstreetmap.de`), using `exclude_polygons` + `use_lit` + `alternates` | Google Routes can't avoid areas (§2.2). No key or account needed. Tested Nov 19: a Southside → Haas walk avoided a test polygon and returned 1 alternate. openrouteservice sign-up was down (503). |
| Database | **Supabase** (Postgres + PostGIS, Auth, Storage, Realtime) | Team choice |

### Heat map layers (team spec)
- **Streetlight density: yellow glow.** Heat map built from the 7,850 city lamps, with a gradient from transparent to warm yellow (`#FFD60A`). The data is static, so it's bundled in the app as `streetlights.json` (only latitude, longitude and wattage are kept; wattage sets the weight).
- **Student population density: blue glow.** Built from preference-based location tracking. A user turns on location sharing in Settings, and the app then sends a coarse ping every few minutes while open. Supabase aggregates recent pings, the app pulls the aggregate, and it renders a gradient from transparent to blue (`#0A84FF`). Until real users exist, simulated pings are seeded and labeled as simulated.
- Each layer can be toggled from the filter button at the top right of the map (see the ideation mockup).

### Google Cloud setup still needed
A test call on Nov 17 showed the key is valid, but **no APIs are enabled** (Geocoding, Places and Routes all returned PERMISSION_DENIED). In the Cloud Console, for the key's project:
1. Enable **Maps SDK for iOS** and **Places API (New)**.
2. Add a key restriction: iOS apps only, limited to this app's bundle ID. The key has been shared in chat, so restrict it.

The key is stored in `Config/Secrets.xcconfig`, which git ignores. `Config/Secrets.example.xcconfig` is the committed template.

## 4. Architecture

```
iOS app (SwiftUI, iOS 26, Liquid Glass)
 ├─ Google map view: incident pins (F3), route polylines (F6)
 │    ├─ yellow heat map layer: streetlights (bundled)
 │    └─ blue heat map layer: population (Supabase aggregate)
 ├─ Glass search bar: Places autocomplete (F5)
 ├─ Report sheet: text + PhotosPicker media (F4)
 ├─ Settings: route preferences + location-sharing opt-in (F7)
 └─ RouteService
      ├─ reports from the last 24h (Supabase)
      ├─ avoid_polygons (≈40 m buffer per incident)
      ├─ Valhalla pedestrian (use_lit), alternates
      ├─ score alternatives: lamp coverage + population density
      └─ re-run when a Realtime insert lands near the active route (F8)
Supabase: auth (berkeley.edu email OTP), reports (PostGIS), location_pings, storage
```

## 5. Design system
- iOS 26 **Liquid Glass** wherever possible: `GlassEffectContainer` + `.glassEffect()` for the floating search bar, the filter/layers button and the map controls; system sheets (glass by default) for the report form and pin detail; `.buttonStyle(.glass)` / `.glassProminent` for primary actions; SF Symbols throughout.
- Colors: green safe route, red incident pins, yellow light glow, blue population glow. Everything else uses system semantic colors so light and dark mode both work.
- Figma: the file `7Q8V21WpnZdSssI8QoIFZQ` is currently empty. Build the screens below from Apple's iOS 26 UI kit components and wire them as a click-through prototype.

### Screens (shared between code and Figma)
1. Sign in: campus email, then a one-time code (F1)
2. Map home: glass search bar, layers/filter button, red pins, yellow and blue glows (F2, F3)
3. Pin detail sheet: text, image/video, time posted (F3)
4. Report sheet: location (current or dropped pin), description, attach media, submit (F4)
5. Search results / destination picker (F5)
6. Route view: suggested safer route(s) with why each is safer (F6)
7. Re-routed state: banner shows the route changed because of a new report (F8)
8. Settings: route preferences + location-sharing opt-in (F7)

## 6. Local development and testing

**Toolchain (this Mac: macOS 15.6.1, about 24 GB free)**
- Install **Xcode 26** from the App Store. It's free, needs macOS 15.6 or later, and is required for the iOS 26 SDK and Liquid Glass. Only Command Line Tools are installed right now.
- Install an **iOS 26 Simulator runtime** (about 8 GB), from Xcode → Settings → Components.
- ⚠️ Disk space is tight. Xcode plus a simulator runtime takes about 20 GB, so free up some space first.

**Running the app**
- Build and run in the iOS Simulator. No Apple developer account is needed for the simulator. Running on a physical iPhone works with a free Apple ID (the build expires after 7 days). TestFlight for user testing needs the $99/year program.
- Location: the simulator can fake a GPS position or play back a GPX walk (for example Southside → Haas at night). That lets us test re-routing (F8) and location pings without walking anywhere.
- Multiple "students": run two simulators at once. File a report on one and watch the pin and re-route appear on the other.

**Supabase**
- Option A (recommended, given the disk space): a **hosted free Supabase project**. Nothing to install, and teammates' phones can reach it.
- Option B: **local Supabase** via `brew install supabase/tap/supabase` plus Docker Desktop, then `supabase start`. Docker is installed but its daemon isn't running. The simulator reaches it at `http://localhost:54321`, and OTP emails land in the local Mailpit inbox at `localhost:54324`, so no real email is needed. This costs several GB of Docker images.
- Schema, seed reports and seed pings live in `supabase/migrations` and `supabase/seed.sql`, so both options load the same data.

**Valhalla routing**
- No key needed. The public FOSSGIS server is fair-use only (about 1 request per second, no uptime guarantee), which is fine for a prototype and user testing. If it's ever unreliable, run Valhalla locally with Docker (`ghcr.io/valhalla/valhalla-scripted` with a NorCal OSM extract) and point the app at `localhost:8002`.

## 7. Build phases
1. **Setup (team):** install Xcode 26, enable the Google APIs and restrict the key, create the Supabase project (done).
2. **Data:** reduce the streetlights snapshot to a bundled JSON file; write the Supabase schema and seed data.
3. **Figma:** screens 1–8 with iOS 26 components, wired as a prototype.
4. **Code:** app skeleton → map + both glows + pins → report → search → safe routing → settings → live re-route.
5. **User-testing build:** the two tasks from the deck ("Report being followed near Moffitt", "Get to Haas for a late-night meeting").

## Sources
- Google Maps Platform pricing: https://developers.google.com/maps/billing-and-pricing/pricing
- Google Routes API route modifiers: https://developers.google.com/maps/documentation/routes/route-modifiers
- openrouteservice plans and limits: https://openrouteservice.org/plans/ · routing options: https://giscience.github.io/openrouteservice/api-reference/endpoints/directions/routing-options
- Valhalla: https://github.com/valhalla/valhalla · GraphHopper: https://github.com/graphhopper/graphhopper
- Berkeley streetlights: https://data.cityofberkeley.info/City-Government/Streetlights/w9v4-y3pu (data: `dz4s-un9u`)
