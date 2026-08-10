require "test_helper"

class PhotoTest < ActiveSupport::TestCase
  PANORAMAX = {
    image_url: "https://api.panoramax.xyz/images/abc/sd.jpg",
    author: "Service départemental",
    licence: "etalab-2.0",
    source_url: "https://panoramax.ign.fr/#pic=abc"
  }.freeze

  setup do
    @roundabout = Roundabout.create!(lat: 44.837789, lon: -0.579180, diameter_m: 42.0)
    @image = fixture_file_upload("observation.png", "image/png")
  end

  test "une observation sans date de prise de vue est irrecevable" do
    photo = Photo.new(roundabout: @roundabout, image: @image)

    assert_not photo.valid?
    assert_includes photo.errors.attribute_names, :taken_on
  end

  test "une observation sans photographie ni adresse distante est irrecevable" do
    photo = Photo.new(roundabout: @roundabout, taken_on: Date.current)

    assert_not photo.valid?
    assert_includes photo.errors.attribute_names, :image
  end

  test "une adresse distante tient lieu de photographie jointe" do
    photo = Photo.new(roundabout: @roundabout, taken_on: Date.current, **PANORAMAX)

    assert photo.valid?
    assert photo.distante?
    assert_equal PANORAMAX[:image_url], photo.illustration
  end

  test "une observation distante exige auteur, licence et source" do
    %i[author licence source_url].each do |mention|
      photo = Photo.new(roundabout: @roundabout, taken_on: Date.current, **PANORAMAX.merge(mention => nil))

      assert_not photo.valid?, "#{mention} devrait être exigé"
      assert_includes photo.errors.attribute_names, mention
    end
  end

  test "une observation jointe n'exige pas les mentions d'attribution" do
    photo = Photo.new(roundabout: @roundabout, taken_on: Date.current, image: @image)

    assert photo.valid?
    assert_not photo.distante?
  end

  test "une observation postérieure au jour de versement est irrecevable" do
    photo = Photo.new(roundabout: @roundabout, taken_on: Date.current.tomorrow, image: @image)

    assert_not photo.valid?
  end

  test "les observations se lisent de la plus récente à la plus ancienne" do
    ancienne = Photo.create!(roundabout: @roundabout, taken_on: Date.new(2024, 3, 1), image: @image)
    recente = Photo.create!(roundabout: @roundabout, taken_on: Date.new(2026, 3, 1), image: @image)

    assert_equal [ recente, ancienne ], @roundabout.photos.to_a
  end

  test "les mentions de licence vides ne sont pas conservées" do
    photo = Photo.create!(roundabout: @roundabout, taken_on: Date.current, image: @image, author: "  ", licence: " CC BY-SA 4.0 ")

    assert_nil photo.author
    assert_equal "CC BY-SA 4.0", photo.licence
  end
end
