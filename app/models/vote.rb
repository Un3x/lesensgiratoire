class Vote < ApplicationRecord
  belongs_to :roundabout

  validates :liked, inclusion: { in: [ true, false ], message: "doit être favorable ou défavorable" }
  validates :year, presence: true, numericality: { only_integer: true, in: 2000..2100 }
  validates :voter_token, presence: true
  validates :roundabout_id, uniqueness: { scope: [ :year, :voter_token ],
    message: "a déjà recueilli votre avis au titre de cet exercice" }

  scope :for_year, ->(year) { where(year: year) }
  scope :favorable, -> { where(liked: true) }
  scope :defavorable, -> { where(liked: false) }
end
