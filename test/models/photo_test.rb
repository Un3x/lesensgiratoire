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

  test "une observation jointe porte par défaut la licence CC BY-SA 4.0 et n'exige pas de source" do
    photo = Photo.new(roundabout: @roundabout, taken_on: Date.current, image: @image, author: "Une visiteuse")

    assert_equal "CC BY-SA 4.0", photo.licence
    assert photo.valid?
    assert_not photo.distante?
  end

  test "une observation jointe n'admet qu'une licence de la liste" do
    photo = Photo.new(roundabout: @roundabout, taken_on: Date.current, image: @image, author: "x", licence: "Tous droits réservés")
    assert_not photo.valid?
    assert_includes photo.errors.attribute_names, :licence

    photo.licence = nil
    assert_not photo.valid?

    photo.licence = "CC0 1.0"
    assert photo.valid?
  end

  test "une observation jointe sous licence d'attribution nomme son auteur, sauf sous CC0" do
    photo = Photo.new(roundabout: @roundabout, taken_on: Date.current, image: @image, licence: "CC BY 4.0")
    assert_not photo.valid?
    assert_includes photo.errors.attribute_names, :author

    photo.licence = "CC0 1.0"
    assert photo.valid?
  end

  test "un fichier qui n'est pas une image est refusé" do
    photo = Photo.new(roundabout: @roundabout, taken_on: Date.current, author: "x",
      image: fixture_file_upload("observation.txt", "text/plain"))

    assert_not photo.valid?
    assert_includes photo.errors.attribute_names, :image
  end

  test "un fichier de plus de dix mégaoctets est refusé" do
    photo = Photo.new(roundabout: @roundabout, taken_on: Date.current, author: "x", image: @image)
    photo.image.blob.byte_size = 10.megabytes + 1

    assert_not photo.valid?
    assert_includes photo.errors.attribute_names, :image
  end

  test "une observation jointe attend sa validation, une observation distante est publiée d'emblée" do
    jointe = Photo.create!(roundabout: @roundabout, taken_on: Date.current, image: @image, author: "x")
    releve = Photo.releve_vierge
    Photo.verser({ "lat" => @roundabout.lat.to_f, "lon" => @roundabout.lon.to_f, "url" => PANORAMAX[:image_url],
      "date" => "2025-01-01", "licence" => "etalab-2.0", "auteur" => "x", "source" => "https://s" }, releve)

    assert_equal [ Photo.find_by(image_url: PANORAMAX[:image_url]) ], Photo.publiees.to_a
    assert_nil jointe.validated_at
  end

  test "une observation postérieure au jour de versement est irrecevable" do
    photo = Photo.new(roundabout: @roundabout, taken_on: Date.current.tomorrow, image: @image)

    assert_not photo.valid?
  end

  test "les observations se lisent de la plus récente à la plus ancienne" do
    ancienne = Photo.create!(roundabout: @roundabout, taken_on: Date.new(2024, 3, 1), image: @image, author: "x")
    recente = Photo.create!(roundabout: @roundabout, taken_on: Date.new(2026, 3, 1), image: @image, author: "x")

    assert_equal [ recente, ancienne ], @roundabout.photos.to_a
  end

  test "les mentions vides ne sont pas conservées" do
    photo = Photo.create!(roundabout: @roundabout, taken_on: Date.current, image: @image, author: " Une visiteuse ", licence: " CC0 1.0 ", source_url: "  ")

    assert_equal "Une visiteuse", photo.author
    assert_equal "CC0 1.0", photo.licence
    assert_nil photo.source_url
  end
end
