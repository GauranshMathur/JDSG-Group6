Rails.application.config.after_initialize do
  RankedFeed.warm if Post.table_exists?
rescue ActiveRecord::NoDatabaseError
  nil
end
