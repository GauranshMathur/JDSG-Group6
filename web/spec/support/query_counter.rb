# Counts the SQL a block issues, so specs can assert a query budget.
#
# The point is not speed in the test suite — it is that query count is the thing
# network latency multiplies. A page costing one query per post is invisible on
# SQLite, where a query is a function call, and is seconds of page load once the
# database is over a network. See docs/latency.md (N-6.1, N-6.2).
module QueryCounter
  # Schema loads and transaction bookkeeping are Active Record talking to
  # itself, not the work the page asked for, so they are not counted.
  IGNORED = /\A(SCHEMA|TRANSACTION)\z/

  def queries_in
    collected = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name].to_s.match?(IGNORED)
      collected << payload[:sql].to_s.gsub(/\s+/, " ").strip
    end
    yield
    collected
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  def count_queries(&block) = queries_in(&block).size
end
