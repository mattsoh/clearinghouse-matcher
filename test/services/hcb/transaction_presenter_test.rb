require "test_helper"

class Hcb::TransactionPresenterTest < ActiveSupport::TestCase
  test "presents a credit as incoming with a positive dollar amount" do
    presenter = Hcb::TransactionPresenter.new({ "id" => "txn_1", "date" => "2026-01-01", "memo" => "Donation", "amount_cents" => 12_345, "tags" => [ "complete" ], "code" => "200" })

    assert_equal "in", presenter.direction
    assert_equal 123.45, presenter.amount
    assert_equal "complete", presenter.tags
    assert_equal "Donation (200)", presenter.category_label
  end

  test "falls back to a humanized label for an unrecognized category code" do
    presenter = Hcb::TransactionPresenter.new({ "id" => "txn_4", "date" => "2026-01-04", "amount_cents" => 100, "code" => "incoming_disbursement" })

    assert_equal "Incoming disbursement (incoming_disbursement)", presenter.category_label
  end

  test "presents a debit as outgoing with a negative dollar amount" do
    presenter = Hcb::TransactionPresenter.new({ "id" => "txn_2", "date" => "2026-01-02", "memo" => "Grant", "amount_cents" => -5_000 })

    assert_equal "out", presenter.direction
    assert_equal(-50.0, presenter.amount)
  end

  test "reads the user name from the sender of an ACH transfer, check, transfer, or Wise transfer" do
    %w[ach_transfer check transfer wise_transfer].each do |type|
      presenter = Hcb::TransactionPresenter.new({ "id" => "txn_5", "amount_cents" => 100, type => { "sender" => { "name" => "Jane D." } } })

      assert_equal "Jane D.", presenter.user_name
    end
  end

  test "reads the user name from the cardholder of a card charge" do
    presenter = Hcb::TransactionPresenter.new({ "id" => "txn_6", "amount_cents" => -100, "card_charge" => { "card" => { "user" => { "name" => "Sam R." } } } })

    assert_equal "Sam R.", presenter.user_name
  end

  test "reads the user name from the submitter of a check deposit" do
    presenter = Hcb::TransactionPresenter.new({ "id" => "txn_7", "amount_cents" => 100, "check_deposit" => { "submitter" => { "name" => "Lee K." } } })

    assert_equal "Lee K.", presenter.user_name
  end

  test "has no user name for transaction types with no internal HCB sender, like donations" do
    presenter = Hcb::TransactionPresenter.new({ "id" => "txn_8", "amount_cents" => 100, "donation" => { "donor" => { "name" => "External Donor" } } })

    assert_equal "", presenter.user_name
  end

  test "as_json matches the legacy frontend's expected field shape" do
    presenter = Hcb::TransactionPresenter.new({ "id" => "txn_3", "date" => "2026-01-03", "memo" => "Fee", "amount_cents" => -100 })
    json = presenter.as_json

    assert_equal %i[id date memo amount direction tags user_name category_label].sort, json.keys.sort
  end
end
