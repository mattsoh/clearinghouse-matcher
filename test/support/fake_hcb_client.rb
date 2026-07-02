# Stands in for Hcb::Client in tests so nothing hits the real HCB API.
# Construct with canned responses for whichever methods a given test exercises.
class FakeHcbClient
  def initialize(transactions: [], members: [], user: {}, organizations: [])
    @transactions = transactions
    @members = members
    @user = user
    @organizations = organizations
  end

  def user = @user
  def organizations = { "data" => @organizations }

  def organization(_id, expand: [])
    { "id" => "org_1", "name" => "Test Org", "users" => @members }
  end

  def transactions(_organization_id, after: nil, limit: 100)
    page = after ? @transactions.drop_while { |t| t["id"] != after }.drop(1) : @transactions
    { "data" => page.first(limit), "has_more" => false, "total_count" => @transactions.size }
  end

  def transaction(id)
    @transactions.find { |t| t["id"] == id }
  end
end
