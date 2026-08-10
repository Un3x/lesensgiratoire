class Photo < ApplicationRecord
  belongs_to :roundabout

  has_one_attached :image

  validates :image, presence: true
  validates :taken_on, presence: true,
    comparison: { less_than_or_equal_to: ->(_) { Date.current },
                  message: "ne peut pas être postérieure à la date du jour" }

  normalizes :author, :licence, :source_url, with: -> { it&.strip.presence }
end
