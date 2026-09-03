import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"

const NOMBRE = new Intl.NumberFormat("fr-FR")

export default class extends Controller {
  static targets = ["toile", "seuil", "seuilValeur", "regime", "etat"]
  static values = {
    url: String,
    ficheUrl: String,
    minDiameter: Number,
    center: Array,
    zoom: Number
  }

  connect() {
    this.carte = L.map(this.toileTarget, {
      preferCanvas: true,
      center: this.centerValue,
      zoom: this.zoomValue,
      zoomControl: false
    })

    L.control.zoom({ position: "topright", zoomInTitle: "Agrandir", zoomOutTitle: "Réduire" }).addTo(this.carte)

    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: "© les contributeurs OpenStreetMap"
    }).addTo(this.carte)

    this.calque = L.layerGroup().addTo(this.carte)
    this.carte.on("moveend", () => this.recenser())
    this.carte.on("zoomend", () => this.restyler())
    this.recenser()
  }

  disconnect() {
    this.controleur?.abort()
    this.carte?.remove()
  }

  seuilModifie() {
    this.minDiameterValue = Number(this.seuilTarget.value)
    this.seuilValeurTarget.textContent = `${NOMBRE.format(this.minDiameterValue)} m`
    this.recenser()
  }

  regimeModifie() {
    this.recenser()
  }

  async recenser() {
    clearTimeout(this.minuteur)
    this.minuteur = setTimeout(() => this.charger(), 200)
  }

  async charger() {
    const limites = this.carte.getBounds()
    const parametres = new URLSearchParams({
      bbox: [limites.getWest(), limites.getSouth(), limites.getEast(), limites.getNorth()].join(","),
      min_diameter: this.minDiameterValue,
      junction_type: this.regimeTargets.find((radio) => radio.checked)?.value ?? ""
    })

    this.controleur?.abort()
    this.controleur = new AbortController()

    let releve
    try {
      const reponse = await fetch(`${this.urlValue}?${parametres}`, {
        headers: { Accept: "application/json" },
        signal: this.controleur.signal
      })
      if (!reponse.ok) throw new Error(reponse.statusText)
      releve = await reponse.json()
    } catch (erreur) {
      if (erreur.name === "AbortError") return
      this.etatTarget.textContent = "Le recensement est momentanément indisponible."
      return
    }

    this.dessiner(releve.roundabouts)
    this.etatTarget.textContent = this.libelle(releve)
  }

  dessiner(ronds_points) {
    this.calque.clearLayers()
    const aspect = this.aspect()

    for (const rond_point of ronds_points) {
      L.circleMarker([rond_point.lat, rond_point.lon], aspect)
        .bindPopup(this.fiche(rond_point))
        .addTo(this.calque)
    }
  }

  restyler() {
    const aspect = this.aspect()
    this.calque.eachLayer((marqueur) => marqueur.setStyle(aspect))
  }

  aspect() {
    const echelle = this.carte.getZoom() - 5

    return {
      radius: Math.min(8, Math.max(2, 2 + echelle * 0.7)),
      weight: this.carte.getZoom() >= 10 ? 1 : 0,
      fillOpacity: Math.min(0.85, Math.max(0.3, 0.3 + echelle * 0.07)),
      color: "#1c3d5a",
      fillColor: "#4a7fa5"
    }
  }

  fiche(rond_point) {
    const designation = rond_point.name || "Rond-point sans nom"
    const commune = rond_point.commune ? `<p>Commune de ${escapeHtml(rond_point.commune)}</p>` : ""
    const diametre = rond_point.d ? `<p>Diamètre : ${NOMBRE.format(rond_point.d)} m</p>` : ""

    return `<div class="carte__infobulle">
      <p class="carte__infobulle-titre">${escapeHtml(designation)}</p>
      ${commune}${diametre}
      <a href="${this.ficheUrlValue}/${rond_point.id}">Consulter la fiche</a>
    </div>`
  }

  libelle({ total, sampled, limit }) {
    if (total === 0) return "Aucun rond-point ne correspond aux critères de recherche."
    if (sampled) {
      return `${NOMBRE.format(total)} ronds-points recensés dans l'emprise affichée. La carte en représente ${NOMBRE.format(limit)}, prélevés uniformément : la densité figurée est celle du recensement. Rapprochez-vous pour obtenir le relevé complet.`
    }
    return `${NOMBRE.format(total)} ${total > 1 ? "ronds-points recensés" : "rond-point recensé"} dans l'emprise affichée.`
  }
}

function escapeHtml(valeur) {
  const noeud = document.createElement("span")
  noeud.textContent = valeur
  return noeud.innerHTML
}
