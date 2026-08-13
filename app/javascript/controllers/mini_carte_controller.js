import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"

export default class extends Controller {
  static values = {
    lat: Number,
    lon: Number,
    zoom: Number,
    tuiles: String,
    attribution: String,
    marqueur: Boolean
  }

  connect() {
    this.carte = L.map(this.element, {
      center: [this.latValue, this.lonValue],
      zoom: this.zoomValue,
      zoomControl: false,
      scrollWheelZoom: false,
      attributionControl: true
    })

    L.tileLayer(this.tuilesValue, {
      maxZoom: 20,
      attribution: this.attributionValue
    }).addTo(this.carte)

    if (this.marqueurValue) {
      L.circleMarker([this.latValue, this.lonValue], {
        radius: 8,
        weight: 2,
        color: "#1c3d5a",
        fillColor: "#4a7fa5",
        fillOpacity: 0.85
      }).addTo(this.carte)
    }
  }

  disconnect() {
    this.carte?.remove()
  }
}
