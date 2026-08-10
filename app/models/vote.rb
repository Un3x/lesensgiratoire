class Vote < ApplicationRecord
  CATEGORIES = %w[plus_beau plus_moche moins_entretenu].freeze

  belongs_to :roundabout

  enum :category, CATEGORIES.index_by(&:to_sym)

  validates :category, presence: true
  validates :year, presence: true, numericality: { only_integer: true, in: 2026..2100 }
  validates :voter_token, presence: true
  validates :roundabout_id, uniqueness: { scope: [ :category, :year, :voter_token ],
    message: "a déjà fait l'objet d'un suffrage dans cette catégorie pour cette année" }

  scope :for_year, ->(year) { where(year: year) }
end
