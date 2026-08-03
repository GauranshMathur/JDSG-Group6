class Post < ApplicationRecord
  MAX_BODY_LENGTH = 280
  MAX_IMAGES = 4
  IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
  IMAGE_FEED_SIZE = [ 600, 600 ].freeze

  belongs_to :user
  belongs_to :parent, class_name: "Post", counter_cache: :replies_count, optional: true
  has_many :replies, class_name: "Post", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :likes, dependent: :destroy
  has_many :reposts, dependent: :destroy
  has_many :post_tags, dependent: :destroy
  has_many :tags, through: :post_tags
  has_many_attached :images

  validates :body, presence: true, length: { maximum: MAX_BODY_LENGTH }
  validate :images_content_type_allowed
  validate :images_count_within_limit

  after_save :sync_tags
  after_create_commit  { RankedFeed.bust_cache }
  after_destroy_commit { RankedFeed.bust_cache }

  # Newest first, with id breaking ties so the ordering is total and stable.
  # Without the tie-break, posts sharing a created_at could swap places between
  # requests and be shown twice or skipped by the cursor below.
  #
  # The author is loaded with the page because every rendered post shows it.
  # Left lazy this is one query per post — invisible on SQLite and seconds of
  # page load once the database is over a network. See docs/latency.md.
  #
  # eager_load rather than includes: includes preloads the users in a second
  # query, while eager_load joins them into the one that fetches the posts. So
  # attributing posts to their authors costs no extra round trip at all.
  scope :top_level, -> { where(parent_id: nil) }
  scope :timeline, -> { top_level.eager_load(:user).order(created_at: :desc, id: :desc) }
  scope :search, ->(query) { where("posts.body LIKE ?", "%#{sanitize_sql_like(query)}%") }

  # Keyset pagination: the page of posts strictly older than the given position.
  # Offset pagination would shift as new posts arrive at the head of the
  # timeline, causing rows to repeat across pages.
  #
  # Columns are table-qualified because timeline joins users, which has its own
  # created_at and id — unqualified, this comparison is ambiguous and the
  # database is entitled to resolve it against the wrong table.
  scope :older_than, ->(created_at, id) {
    where("posts.created_at < :created_at OR (posts.created_at = :created_at AND posts.id < :id)",
          created_at: created_at, id: id)
  }

  # Opaque cursor identifying this post's position in the timeline. Microsecond
  # precision matters: truncating to seconds would make the comparison above skip
  # posts written in the same second.
  def cursor
    "#{created_at.iso8601(6)},#{id}"
  end

  # Parses a cursor back into its parts, returning nil for anything malformed so
  # that a bad ?after= param falls back to the first page rather than erroring.
  #
  # Time.zone.parse returns nil for an unparseable string instead of raising, so
  # the rescue below does not catch it. Letting that nil through would compare
  # every row against NULL in older_than, match nothing, and render an empty
  # feed — which is worse than the error it was meant to avoid.
  def self.parse_cursor(value)
    return nil if value.blank?

    created_at, id = value.split(",", 2)
    return nil if created_at.blank? || id.blank?

    parsed_created_at = Time.zone.parse(created_at)
    return nil if parsed_created_at.nil?

    [ parsed_created_at, Integer(id) ]
  rescue ArgumentError, TypeError
    nil
  end

  def written_by?(other)
    other.present? && user_id == other.id
  end

  # A post that changes silently after people have read it is a different object
  # from one that shows it changed — someone can agree with a post and later find
  # they agreed with something else.
  #
  # The marker only says *that* it changed, not what it was: no history is kept,
  # so the previous wording is gone. That remains an open question, and the cost
  # of leaving it open accrues from now, because the edits happening in the
  # meantime are the ones that cannot be recovered later.
  #
  # The tolerance is because created_at and updated_at are written from the same
  # clock read on insert but are not guaranteed to be bit-identical.
  EDIT_TOLERANCE = 1.second

  def edited?
    updated_at > created_at + EDIT_TOLERANCE
  end

  def image_variants
    images.map { |img| img.variant(resize_to_limit: IMAGE_FEED_SIZE, format: :webp, saver: { strip: true }) }
  end

  HASHTAG_REGEX = /#(\w+)/

  private

  def images_content_type_allowed
    images.each do |img|
      unless IMAGE_CONTENT_TYPES.include?(img.blob.content_type)
        errors.add(:images, "must be PNG, JPEG, WebP or GIF images")
        break
      end
    end
  end

  def images_count_within_limit
    errors.add(:images, "can have at most #{MAX_IMAGES} images") if images.size > MAX_IMAGES
  end

  def sync_tags
    parsed_names = body.scan(HASHTAG_REGEX).flatten.map(&:downcase).uniq
    current_tags = parsed_names.map { |name| Tag.find_or_create_by!(name: name) }
    self.tags = current_tags
  end
end
