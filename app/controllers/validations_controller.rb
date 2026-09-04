class ValidationsController < ApplicationController
  http_basic_authenticate_with name: "validation", password: ENV.fetch("VALIDATION_MOT_DE_PASSE") { SecureRandom.hex }

  def index
    @photos = Photo.en_attente.includes(:roundabout, image_attachment: :blob).order(:created_at)
  end

  def update
    photo = Photo.en_attente.find(params[:id])
    photo.update!(validated_at: Time.current)
    redirect_to validations_path, notice: "L'observation du #{l(photo.taken_on)} a été admise au dossier."
  end

  def destroy
    photo = Photo.en_attente.find(params[:id])
    photo.destroy!
    redirect_to validations_path, notice: "L'observation du #{l(photo.taken_on)} a été rejetée."
  end
end
