# Demo seed for the Lumio presentation.
#
# Creates the demo account vlad@gmail.com with 4 categories and 10 long-form
# notes: 6 already categorized, 4 intentionally left uncategorized so the
# autocategorize features can be demonstrated live.
#
# Re-running the seed resets the demo account to this exact state.

user = User.find_or_create_by!(email: "vlad@gmail.com") do |u|
  u.password = "password"
  u.password_confirmation = "password"
end

# Reset the demo account so every presentation starts from the same state.
user.chats.destroy_all
user.notes.destroy_all
user.categories.destroy_all

work     = user.categories.create!(title: "Work")
health   = user.categories.create!(title: "Health & Fitness")
travel   = user.categories.create!(title: "Travel")
learning = user.categories.create!(title: "Learning")

def create_note(user, title:, content:, category: nil)
  note = user.notes.create!(title: title, content: content)
  note.categories = [ category ] if category
  note
end

# --- Categorized notes -------------------------------------------------------

create_note(user, category: work,
  title: "Q3 Product Roadmap — Lumio Launch Plan",
  content: <<~TEXT)
    The Q3 goal is to ship Lumio 1.0 to public beta by September 15th. The three launch-blocking
    workstreams are AI summaries, semantic chat over notes, and the mobile app parity pass.

    AI summaries are owned by me. The summary pipeline runs as a background job: when a user requests
    a summary, we enqueue GenerateNoteSummaryJob, which calls Claude Haiku through RubyLLM and stores
    the result on the note_summaries table with a status machine (pending, processing, completed,
    failed). The main open risk is rate limiting under load — we agreed to add a per-user throttle of
    10 summary requests per minute before launch.

    Semantic chat is the flagship feature. Every note is embedded into Pinecone on create and update
    via EmbedNoteJob. When the user asks a question, we embed the query, retrieve the top 5 matching
    note chunks, and pass them to the model as context. Answers must always cite their source notes —
    that citation UI is what differentiates us from a generic chatbot.

    Mobile parity is behind: the React Native app still lacks category filtering and the chat screen.
    Estimate is 3 weeks of work, so it needs to start no later than August 10th. If it slips, we
    launch web-only and follow with mobile in October.

    Success metrics for the beta: 500 signups in the first month, 40% of users creating at least 5
    notes, and 25% of users trying the chat feature at least once.
  TEXT

create_note(user, category: work,
  title: "1:1 Notes with Andrei — Backend Performance",
  content: <<~TEXT)
    Met with Andrei on Tuesday to go over the backend performance audit before the beta launch.

    The notes index endpoint was the worst offender: it was doing an N+1 across note_categories and
    categories, adding roughly 40 extra queries per request for a user with 20 notes. Fixed with
    includes(:categories, :note_summary), which brought p95 latency from 480ms down to 95ms on
    staging data.

    Pinecone upserts were being done synchronously in an after_save callback at one point, which
    added 300-600ms to every note save. Moving them to EmbedNoteJob (Sidekiq, default queue) made
    saves feel instant again. We added retry_on with 3 attempts and a 5 second wait for transient
    Pinecone errors.

    Andrei flagged that JWT denylist lookups happen on every authenticated request and the table
    will grow unbounded. Action item for me: add a scheduled job that purges expired denylist rows
    nightly. Low effort, prevents a slow degradation later.

    We also agreed on a database indexing pass: composite index on note_categories(note_id,
    category_id) is already unique, but chats.user_id and messages.chat_id needed coverage — both
    are in place now. Next 1:1 is scheduled for July 15th and the topic is load testing the chat
    endpoint with 50 concurrent users.
  TEXT

create_note(user, category: health,
  title: "Half-Marathon Training Plan — 12 Weeks",
  content: <<~TEXT)
    Registered for the Bucharest half-marathon on October 12th. Goal time is 1:55, which means
    holding about 5:27 per kilometer for 21.1 km. Current comfortable pace is 6:10/km over 10 km,
    so there is real work to do over the next 12 weeks.

    The plan is four runs per week. Tuesday is intervals: 6 to 8 repeats of 800m at 5:00/km pace
    with 90 seconds of recovery jogging. Thursday is a tempo run, starting at 5 km at threshold
    pace and building to 8 km by week eight. Saturday is an easy conversational run of 5 to 7 km,
    and Sunday is the long run, starting at 10 km and adding 1.5 km per week, peaking at 19 km two
    weeks before race day.

    Strength work happens Monday and Friday: squats, Romanian deadlifts, calf raises, and core.
    Nothing heavy — the point is injury prevention, especially for the left knee that acted up
    during last year's 10k training block.

    Nutrition rules during the block: 2 grams of protein per kilogram of body weight, carbs
    front-loaded before quality sessions, no alcohol in the final four weeks. Long runs over 90
    minutes get a gel at the 50-minute mark to practice race fueling.

    Taper starts October 1st: volume drops 40% in week one and 60% in race week, keeping just a
    few short strides to stay sharp.
  TEXT

create_note(user, category: travel,
  title: "Japan Trip Itinerary — October",
  content: <<~TEXT)
    Two weeks in Japan, October 20th to November 3rd, flying into Tokyo Narita and out of Osaka
    Kansai. Booked the flights with Turkish Airlines for 780 EUR round trip with a layover in
    Istanbul.

    Tokyo, days 1-5: staying in Shinjuku at a mid-range hotel (about 110 EUR/night). Planned:
    teamLab Planets on day 2 (tickets already bought), a day trip to Kamakura for the Great Buddha
    and the coastal hike, Tsukiji outer market for breakfast at least twice, and an evening in
    Golden Gai. Reservation attempt for a sushi omakase at Sushi Saito is almost certainly hopeless,
    backup is Sushi Tokyo Ten in Shinjuku.

    Hakone, days 6-7: one night in a ryokan with a private onsen (booked, 220 EUR including kaiseki
    dinner). If the weather cooperates, the pirate ship crossing of Lake Ashi has views of Mount
    Fuji. Buying the Hakone Free Pass to cover the loop of cable cars, ropeways, and boats.

    Kyoto, days 8-12: machiya guesthouse in Gion. Early mornings are the strategy — Fushimi Inari
    at 7am before the crowds, Arashiyama bamboo grove at 8am. Day trip to Nara to see the deer and
    Todai-ji. One evening reserved for a kaiseki dinner, budget 90 EUR per person.

    Osaka, days 13-14: street food crawl in Dotonbori — takoyaki, okonomiyaki, kushikatsu. Day trip
    option to Himeji Castle if energy allows. The JR Pass no longer makes financial sense at the new
    price, so I'm buying individual shinkansen tickets: Tokyo-Odawara, Odawara-Kyoto, Kyoto-Osaka,
    roughly 130 EUR total.

    Total budget: 3,200 EUR per person including flights, hotels, food, and transport.
  TEXT

create_note(user, category: learning,
  title: "Designing Data-Intensive Applications — Chapters 1-3",
  content: <<~TEXT)
    Reading notes from Kleppmann's DDIA, first three chapters.

    Chapter 1 frames every data system around three concerns: reliability (the system works
    correctly even when things go wrong), scalability (there are strategies for keeping performance
    good as load grows), and maintainability (engineers can work on it productively over time). The
    key insight is that load must be described with concrete parameters — requests per second, read
    to write ratio, fan-out — before any scaling conversation makes sense. Twitter's home timeline
    is the classic fan-out example: precomputing timelines on write is cheap for most users but
    breaks for celebrities with millions of followers, so they use a hybrid.

    Chapter 2 compares data models. Relational handles many-to-many relationships well and shines
    when the access patterns are not known in advance. Document models win when data comes in
    self-contained trees and you mostly load the whole document. Graph models fit when anything can
    relate to anything. The chapter's warning: schema-on-read is not schema-free, it just moves the
    schema into application code.

    Chapter 3 is storage engines. Log-structured engines (LSM-trees: Cassandra, RocksDB) turn all
    writes into sequential appends and compact in the background — great write throughput, but reads
    may check several SSTables, mitigated by Bloom filters. Page-oriented engines (B-trees: Postgres,
    MySQL) update in place and usually win on reads. Rule of thumb from the chapter: LSM for
    write-heavy, B-tree for read-heavy, and always benchmark with your own workload.

    Personal takeaway for Lumio: our workload is read-heavy with modest write volume, so Postgres
    with proper indexes is exactly the right call, and the Pinecone index handles the one truly
    specialized access pattern (vector similarity) that Postgres would struggle with at scale.
  TEXT

create_note(user, category: travel,
  title: "Weekend in Lisbon — Budget & Highlights",
  content: <<~TEXT)
    Three-day city break in Lisbon with Ana, flying out Friday morning with Wizz Air (89 EUR return
    each) and back Sunday night.

    Stayed in Alfama in a small guesthouse near the Fado Museum, 75 EUR per night. Alfama was the
    right call — steep, tiled, quiet in the mornings, and the miradouros (viewpoints) at Santa Luzia
    and Portas do Sol are five minutes away. Take tram 28 once for the experience, then never again:
    it is packed and pickpocket-prone. Walking or the 737 bus is better.

    Food highlights: pasteis de nata at Manteigaria (better than the famous Belem ones, no queue),
    grilled sardines at a hole-in-the-wall in Alfama during dinner, bifana sandwich at O Trevo on
    Praca Luis de Camoes, and a splurge dinner at a modern Portuguese place in Principe Real that
    ran 65 EUR for two with wine. Ginjinha (sour cherry liqueur) from the tiny standing bar near
    Rossio, 1.50 EUR a shot.

    Day trip to Sintra on Saturday: catch the 8:40 train from Rossio station (5 EUR return), go
    straight to Pena Palace at opening to beat the tour buses, then Quinta da Regaleira for the
    initiation well. Skip the Moorish castle if short on time. Back in Lisbon by 17:00.

    Total spend for the weekend: about 420 EUR per person, everything included. Would go back just
    for the food and the light — the golden hour over the Tagus from the Alfama viewpoints is worth
    the trip alone.
  TEXT

# --- Uncategorized notes (for the autocategorize demo) -----------------------

create_note(user,
  title: "Sprint Retro Takeaways — June",
  content: <<~TEXT)
    Retro for the June sprint, whole team present, format was start/stop/continue.

    What went well: the feature pipeline held up — 14 tickets closed against a plan of 12, and the
    two hotfixes that came in mid-sprint were absorbed without pushing anything out. Code review
    turnaround averaged under 4 hours, which everyone wants to protect. The decision to demo
    work-in-progress every Wednesday caught two design misunderstandings early, before they became
    rework.

    What to stop: scope creep through Slack. Three tickets grew by more than half their original
    estimate because requirements were added in comment threads instead of going through triage.
    New rule: any scope change gets a ticket comment and re-estimation, or it waits for next sprint.

    What to start: a rotating on-call for flaky CI. The test suite failed spuriously 9 times this
    sprint, and each time someone context-switched to investigate. One person per week owns CI
    health so the rest of the team stays focused.

    Action items: Maria writes the scope-change rule into the team handbook by Friday. I set up the
    CI on-call rotation in PagerDuty. Andrei investigates the two slowest test files, which account
    for 40% of suite runtime. Velocity target for July stays at 12 tickets — we are not raising it
    just because June went well.
  TEXT

create_note(user,
  title: "Meal Prep Plan — Cutting Phase",
  content: <<~TEXT)
    Twelve-week cut starting Monday, goal is to go from 84 kg to 78 kg while keeping strength on the
    main lifts. Daily targets: 2,100 calories, 170 g protein, 220 g carbs, 60 g fat.

    Sunday prep session, about two hours: grill 1.5 kg of chicken thighs, bake a tray of salmon
    fillets, cook a big pot of jasmine rice and another of lentils, roast two trays of vegetables
    (broccoli, peppers, zucchini), and hard-boil a dozen eggs. Everything portioned into glass
    containers — five lunches and four dinners covered, weeknight cooking eliminated.

    Daily structure: breakfast is skyr with berries, honey, and 30 g of oats (about 450 kcal, 40 g
    protein). Lunch is a prepped container of chicken, rice, and vegetables (650 kcal). Afternoon
    snack is an apple with a scoop of whey. Dinner rotates between salmon with lentils and a
    stir-fry from the prep containers (600 kcal). That leaves roughly 250 kcal of buffer for coffee
    with milk, a square of dark chocolate, or extra rice on training days.

    Rules that make cutting sustainable for me: one flexible meal per week, eaten out with zero
    tracking. No liquid calories except the post-workout shake. If weight loss stalls for two
    consecutive weeks, drop 100 kcal from carbs, never from protein. Weigh-ins daily, but only the
    7-day rolling average counts — daily fluctuations of a kilo are water, not fat.

    Expected rate: about 0.5 kg per week, which should land at 78 kg right around week twelve
    without any strength loss on squat, bench, or deadlift.
  TEXT

create_note(user,
  title: "Iceland Road Trip Research — Car Rental & Route",
  content: <<~TEXT)
    Research for a 7-day Iceland ring road trip next June, two people, camping and guesthouses mixed.

    Car rental is the biggest decision. A 2WD compact (Kia Rio class) runs about 55 EUR/day in June,
    while a 4x4 (Dacia Duster class) is around 95 EUR/day. Verdict from the research: 2WD is fine
    for the ring road (Route 1) itself, which is fully paved, but all F-roads into the highlands
    legally require 4x4, and rental insurance is void if you take a 2WD onto them. Since the plan
    skips the highlands this trip, 2WD it is — that saves about 280 EUR.

    Insurance: gravel protection (GP) is genuinely worth it, windscreen chips from gravel are the
    single most common damage claim in Iceland. Sand and ash protection (SAAP) matters mainly for
    the south coast in storms; June risk is low, skipping it. Booking through the rental company
    directly rather than a broker, so there is no claim-time finger pointing.

    Route, counterclockwise from Reykjavik: day 1 Golden Circle (Thingvellir, Geysir, Gullfoss),
    day 2 south coast (Seljalandsfoss, Skogafoss, Reynisfjara black sand beach, overnight in Vik),
    day 3 Skaftafell and the Jokulsarlon glacier lagoon, day 4 the east fjords to Egilsstadir, day
    5 Myvatn area (Dettifoss, Hverir geothermal field, Myvatn nature baths as the cheaper Blue
    Lagoon alternative), day 6 Akureyri and the Troll Peninsula, day 7 back to Reykjavik via
    Hvalfjordur.

    Fuel estimate: the full loop is about 1,600 km, at 9 EUR per 100 km that is roughly 145 EUR.
    Groceries from Bonus supermarkets instead of restaurants keeps food to about 25 EUR per person
    per day. Total estimate for two people: around 2,400 EUR excluding flights.
  TEXT

create_note(user,
  title: "Rails 8 Study Notes — Solid Queue vs Sidekiq",
  content: <<~TEXT)
    Spent the evening comparing Solid Queue (the new Rails 8 default) with Sidekiq to decide what a
    greenfield Rails app should use in 2026.

    Solid Queue runs jobs out of the primary database using FOR UPDATE SKIP LOCKED, so there is no
    Redis dependency at all. That is the whole pitch: one less piece of infrastructure, jobs are
    transactionally consistent with your data (enqueue inside a transaction and the job only becomes
    visible if the transaction commits), and the queue is inspectable with plain SQL. Mission
    Control provides the dashboard. Throughput is respectable — thousands of jobs per second on
    decent Postgres hardware — which covers the vast majority of apps.

    Sidekiq still wins on raw throughput (tens of thousands of jobs per second on Redis), has a
    mature ecosystem of middleware, and Sidekiq Pro adds batches with callbacks, which have no clean
    Solid Queue equivalent yet. The operational cost is running and monitoring Redis, plus the
    classic gotcha: enqueue inside a transaction that later rolls back, and the job fires against
    data that does not exist. after_commit discipline is mandatory.

    The decision framework I landed on: default to Solid Queue for new apps — simpler ops, good
    enough throughput, transactional enqueue is a real correctness win. Reach for Sidekiq when you
    need batches, very high throughput, per-queue latency guarantees, or you already run Redis for
    caching anyway and the marginal cost is zero.

    Lumio currently runs Sidekiq because embeddings and summary generation were built before Rails 8
    shipped, and Redis was already in the stack. Migrating is possible but not worth it — the jobs
    are simple and the queue depth never exceeds a few hundred.
  TEXT

puts "Seeded demo account:"
puts "  email:    vlad@gmail.com"
puts "  password: password"
puts "  categories: #{user.categories.count} | notes: #{user.notes.count} (#{user.notes.left_joins(:note_categories).where(note_categories: { id: nil }).count} uncategorized)"
