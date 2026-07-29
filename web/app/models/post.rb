class Post < ApplicationRecord
  MAX_BODY_LENGTH = 280
  MAX_AUTHOR_NAME_LENGTH = 50
  DEFAULT_AUTHOR_NAME = "anonymous".freeze

  # There is no authentication yet, so authorship is a plain string supplied with
  # the post. Milestone 2 replaces this with a belongs_to :user association.
  validates :author_name, presence: true, length: { maximum: MAX_AUTHOR_NAME_LENGTH }
  validates :body, presence: true, length: { maximum: MAX_BODY_LENGTH }

  before_validation :apply_default_author_name

  # Newest first, with id breaking ties so the ordering is total and stable.
  # Without the tie-break, posts sharing a created_at could swap places between
  # requests and be shown twice or skipped by the cursor below.
  scope :timeline, -> { order(created_at: :desc, id: :desc) }

  # Keyset pagination: the page of posts strictly older than the given position.
  # Offset pagination would shift as new posts arrive at the head of the
  # timeline, causing rows to repeat across pages.
  scope :older_than, ->(created_at, id) {
    where("created_at < :created_at OR (created_at = :created_at AND id < :id)",
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

  private

  def apply_default_author_name
    self.author_name = DEFAULT_AUTHOR_NAME if author_name.blank?
  end
end
