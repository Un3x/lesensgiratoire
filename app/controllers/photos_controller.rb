class PhotosController < ApplicationController
  def create
    @roundabout = Roundabout.find(params[:roundabout_id])
    @photo = Photo.new(photo_params.merge(roundabout: @roundabout))

    if @photo.save
      redirect_to @roundabout, notice: "L'observation du #{l(@photo.taken_on)} a été reçue et sera examinée avant publication."
    else
      render "roundabouts/show", status: :unprocessable_content
    end
  end

  private
    def photo_params
      params.expect(photo: [ :image, :taken_on, :author, :licence ])
    end
end
