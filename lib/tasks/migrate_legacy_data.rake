namespace :migrate do
  desc <<~DESC
    Import legacy matches.json/manual_transactions.json/ledger.json into Match/MatchTransaction/MatchAdjustment.

    Old ids only meant anything relative to the CSV snapshot they came from, so each leg is
    re-resolved against live HCB transactions by date+amount (fuzzy-matched by memo when there's
    more than one candidate). Runs as a dry run by default -- pass DRY_RUN=0 to actually write.

    Usage:
      bin/rails "migrate:legacy_matches[/path/to/legacy_source,<hcb_organization_id>,<local_user_id>]"
      DRY_RUN=0 bin/rails "migrate:legacy_matches[/path/to/legacy_source,<hcb_organization_id>,<local_user_id>]"

    <local_user_id> is the id of an already-logged-in local User whose HCB token will be used to
    fetch live transactions for the target org (the importer has no OAuth credentials of its own).
  DESC
  task :legacy_matches, [ :legacy_dir, :organization_id, :as_user_id ] => :environment do |_, args|
    dry_run = ENV["DRY_RUN"] != "0"
    user = User.find(args[:as_user_id])
    client = Hcb::Client.new(user)

    report = LegacyMigration::MatchImporter.new(
      client: client,
      organization_id: args[:organization_id],
      legacy_dir: args[:legacy_dir],
      dry_run: dry_run
    ).call

    puts "Dry run: #{report.dry_run}"
    puts "#{report.dry_run ? "Would create" : "Created"}: #{report.created}"
    puts "Skipped (unresolved legs, see tmp/legacy_migration/*.json): #{report.skipped}"
    puts "Re-run with DRY_RUN=0 to commit." if report.dry_run
  end
end
