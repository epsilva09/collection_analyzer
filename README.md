
# Collection Analyzer (Rails)

This Rails application fetches a character's `characterIdx` from an external API
and then retrieves the character collection `values` to present in a web page.

It also consumes the more detailed payload returned by `/armory/collection` and
identifies which in‑game collections are **nearly complete** (default threshold 80%).
These are surfaced in both the index and compare views.

Setup

```bash
cd /home/epsilva09/projects/collection_analyzer
bundle install
bin/rails db:create db:migrate
```

Run

```bash
bin/rails server -b 0.0.0.0 -p 3000
```

Open http://localhost:3000 or GET `/armory?name=Cadamantis`.

Configuration

- To change the API base URL set the environment variable `ASC_API_BASE_URL`.

Tests

```bash
bin/rails test
```

Files of interest

- `app/services/armory_client.rb` — encapsulates external API requests.
- `app/controllers/armories_controller.rb` — controller that serves the UI and JSON.
- `app/views/armories/index.html.erb` — HTML view showing the `values`.

Compare feature

- Visit `/armory/compare?name_a=Cadamantis&name_b=OtherName` or open the Compare page from `/armory/compare`.
- The page shows common collection values and those unique to each character.

Progress overview

- A new route `/armory/progress` lists in‑progress collections for a character.
- Collections are bucketed by progress: 1–29 %, 30–59 %, and near completion (≥ 80 %).
- Each entry shows how much is missing, the rewards/status granted, and any specific materials still required for that collection.
