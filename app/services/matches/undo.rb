module Matches
  class Undo
    Result = Struct.new(:success?, :error, :status, keyword_init: true)

    def initialize(match:, user:)
      @match = match
      @user = user
    end

    def call
      return failure("Match not found", :not_found) unless @match
      return failure("Match already undone", :not_found) if @match.undone?

      ActiveRecord::Base.transaction do
        @match.update!(undone_at: Time.current, undone_by: @user)
        @match.match_transactions.active.update_all(undone_at: Time.current)
      end
      Result.new(success?: true)
    end

    private

    def failure(error, status)
      Result.new(success?: false, error: error, status: status)
    end
  end
end
