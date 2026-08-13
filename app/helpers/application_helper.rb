module ApplicationHelper
  def tuiles_orthophoto
    "https://data.geopf.fr/wmts?SERVICE=WMTS&VERSION=1.0.0&REQUEST=GetTile" \
      "&LAYER=ORTHOIMAGERY.ORTHOPHOTOS&STYLE=normal&TILEMATRIXSET=PM&FORMAT=image/jpeg" \
      "&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}"
  end

  def tuiles_plan
    "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
  end
end
