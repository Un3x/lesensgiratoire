import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"

export default class extends Controller {
  static values = { lat: Number, lon: Number, zoom: Number }

  connect() {
    this.carte = L.map(this.element, {
      center: [this.latValue, this.lonValue],
      zoom: this.zoomValue,
      zoomControl: false,
      scrollWheelZoom: false,
      attributionControl: true
    })

    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: "© les contributeurs OpenStreetMap"
    }).addTo(this.carte)

    L.circleMarker([this.latValue, this.lonValue], {
      radius: 8,
      weight: 2,
      color: "#1c3d5a",
      fillColor: "#4a7fa5",
      fillOpacity: 0.85
    }).addTo(this.carte)
  }

  disconnect() {
    this.carte?.remove()
  }
}
