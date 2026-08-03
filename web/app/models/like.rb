class Like < ApplicationRecord
  belongs_to :user
  belongs_to :post, counter_cache: true

  validates :user_id, uniqueness: { scope: :post_id }

  after_create_commit  { RankedFeed.bust_cache }
  after_destroy_commit { RankedFeed.bust_cache }
end
