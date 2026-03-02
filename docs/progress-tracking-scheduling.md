# Progress Tracking Scheduling

## What is already implemented

- Characters queried in Armory screens are persisted in `tracked_characters`.
- Snapshot collection can run in batch through `CollectTrackedCharactersSnapshotsJob`.
- Snapshots now store `captured_at` (timestamp), enabling multiple captures per day.

## Manual trigger

```bash
bin/rails runner "CollectTrackedCharactersSnapshotsJob.perform_now"
```

## Running with Sidekiq

The job uses Active Job API, so it can run on Sidekiq by setting:

```ruby
# config/application.rb or environment config
config.active_job.queue_adapter = :sidekiq
```

Then enqueue periodically using your scheduler of choice (e.g. sidekiq-cron,
OS cron calling `rails runner`, or platform scheduler).

## Example slots

Recommended collection slots:

- 09:00
- 14:00
- 21:00

These provide day coverage and make timeline/hour filters useful for change analysis.

## Scheduler configured in this project

The file `config/recurring.yml` now includes these recurring entries for
`CollectTrackedCharactersSnapshotsJob`:

- `09:00` every day
- `14:00` every day
- `21:00` every day

Configured for:

- `development`
- `production`
