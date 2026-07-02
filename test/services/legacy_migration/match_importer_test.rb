require "test_helper"
require "tmpdir"

class LegacyMigration::MatchImporterTest < ActiveSupport::TestCase
  def setup
    @dir = Dir.mktmpdir
    File.write(File.join(@dir, "ledger.json"), {
      ledger: [
        { id: 1, date: "2025-01-01", memo: "Donation A", amount: 100.0 },
        { id: 2, date: "2025-01-02", memo: "Grant B", amount: -100.0 },
        { id: 4, date: "2025-01-04", memo: "Donation D", amount: 40.0 }
      ]
    }.to_json)
    File.write(File.join(@dir, "manual_transactions.json"), {
      transactions: [ { id: -1, date: "2025-01-05", memo: "fee", amount: -5.0 } ]
    }.to_json)
    File.write(File.join(@dir, "matches.json"), {
      matches: [
        { id: 10, incoming_ids: [ 1 ], outgoing_ids: [ 2 ], note: "", discrepancy: 0.0 },
        { id: 11, incoming_ids: [ 3 ], outgoing_ids: [ -1 ], note: "", discrepancy: -5.0 },
        { id: 12, incoming_ids: [ 4 ], outgoing_ids: [ -1 ], note: "old note", discrepancy: 35.0 }
      ]
    }.to_json)

    live_transactions = [
      { "id" => "txn_A", "date" => "2025-01-01", "memo" => "Donation A", "amount_cents" => 10_000 },
      { "id" => "txn_B", "date" => "2025-01-02", "memo" => "Grant B", "amount_cents" => -10_000 },
      { "id" => "txn_D", "date" => "2025-01-04", "memo" => "Donation D", "amount_cents" => 4_000 }
    ]
    @client = FakeHcbClient.new(transactions: live_transactions)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def import(dry_run:)
    LegacyMigration::MatchImporter.new(client: @client, organization_id: "org_1", legacy_dir: @dir, dry_run: dry_run).call
  end

  test "resolves real legs against live transactions and manual legs into adjustments" do
    report = import(dry_run: false)

    assert_equal 2, report.created
    assert_equal 1, report.skipped

    balanced = Match.find_by(legacy_id: 10)
    assert_equal [ "txn_A" ], balanced.incoming_transaction_ids
    assert_equal [ "txn_B" ], balanced.outgoing_transaction_ids

    with_adjustment = Match.find_by(legacy_id: 12)
    assert_equal [ "txn_D" ], with_adjustment.incoming_transaction_ids
    assert_equal "old note", with_adjustment.note
    assert_equal(-500, with_adjustment.adjustments.sole.amount_cents)
    assert_equal "fee", with_adjustment.adjustments.sole.memo

    assert_nil Match.find_by(legacy_id: 11)
  end

  test "dry run reports what would happen without writing anything" do
    assert_no_difference -> { Match.count } do
      report = import(dry_run: true)
      assert_equal 2, report.created
      assert_equal 1, report.skipped
    end
  end

  test "re-running is idempotent" do
    import(dry_run: false)
    assert_no_difference -> { Match.count } do
      report = import(dry_run: false)
      assert_equal 0, report.created
    end
  end

  test "attributes imported matches to a sentinel legacy-import user" do
    import(dry_run: false)
    importer = User.find_by(hcb_user_id: "legacy-import")
    assert importer
    assert_equal importer, Match.find_by(legacy_id: 10).created_by
  end
end
