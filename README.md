
# Collection Analyzer (Rails)

This Rails application fetches a character's `characterIdx` from an external API
and then retrieves the character collection `values` to present in a web page.

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
