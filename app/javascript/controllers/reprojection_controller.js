import { Controller } from "@hotwired/stimulus"

const LARGEUR = 960
const RAPPORT = 9 / 16

export default class extends Controller {
  static values = { url: String, heading: Number, pitch: Number, fov: Number }
  static targets = ["origine", "mention"]

  connect() {
    this.equirectangulaire = new Image()
    this.equirectangulaire.crossOrigin = "anonymous"
    this.equirectangulaire.addEventListener("load", () => this.dessiner(), { once: true })
    this.equirectangulaire.addEventListener("error", () => this.renoncer(), { once: true })
    this.equirectangulaire.src = this.urlValue
  }

  disconnect() {
    this.equirectangulaire?.removeAttribute("src")
  }

  dessiner() {
    const largeur = LARGEUR
    const hauteur = Math.round(largeur * RAPPORT)

    let source
    try {
      source = this.pixelsSource()
    } catch {
      return this.renoncer()
    }

    const toile = document.createElement("canvas")
    toile.width = largeur
    toile.height = hauteur
    toile.className = "observation__image"
    const contexte = toile.getContext("2d")
    const vue = contexte.createImageData(largeur, hauteur)

    this.projeter(source, vue.data, largeur, hauteur)

    contexte.putImageData(vue, 0, 0)
    toile.setAttribute("role", "img")
    toile.setAttribute("aria-label", this.origineTarget.alt)
    this.origineTarget.replaceWith(toile)
    this.mentionTarget?.removeAttribute("hidden")
  }

  pixelsSource() {
    const brut = document.createElement("canvas")
    brut.width = this.equirectangulaire.naturalWidth
    brut.height = this.equirectangulaire.naturalHeight

    const contexte = brut.getContext("2d", { willReadFrequently: true })
    contexte.drawImage(this.equirectangulaire, 0, 0)

    const pixels = contexte.getImageData(0, 0, brut.width, brut.height)
    return { data: pixels.data, largeur: brut.width, hauteur: brut.height }
  }

  projeter(source, sortie, largeur, hauteur) {
    const focale = largeur / 2 / Math.tan((this.fovValue * Math.PI) / 180 / 2)
    const inclinaison = (this.pitchValue * Math.PI) / 180
    const cap = (this.headingValue * Math.PI) / 180
    const cosI = Math.cos(inclinaison)
    const sinI = Math.sin(inclinaison)
    const cosC = Math.cos(cap)
    const sinC = Math.sin(cap)

    for (let ligne = 0; ligne < hauteur; ligne++) {
      const vy = ligne - hauteur / 2
      const vy2 = vy * cosI - focale * sinI
      const vz2 = vy * sinI + focale * cosI

      for (let colonne = 0; colonne < largeur; colonne++) {
        const vx = colonne - largeur / 2
        const vx3 = vx * cosC + vz2 * sinC
        const vz3 = -vx * sinC + vz2 * cosC

        const norme = Math.sqrt(vx3 * vx3 + vy2 * vy2 + vz3 * vz3)
        const lon = Math.atan2(vx3, vz3)
        const lat = Math.asin(vy2 / norme)

        const u = Math.min(source.largeur - 1, Math.max(0, ((lon / (2 * Math.PI) + 0.5) * source.largeur) | 0))
        const v = Math.min(source.hauteur - 1, Math.max(0, ((lat / Math.PI + 0.5) * source.hauteur) | 0))

        const depuis = (v * source.largeur + u) * 4
        const vers = (ligne * largeur + colonne) * 4
        sortie[vers] = source.data[depuis]
        sortie[vers + 1] = source.data[depuis + 1]
        sortie[vers + 2] = source.data[depuis + 2]
        sortie[vers + 3] = 255
      }
    }
  }

  renoncer() {
    this.element.dataset.reprojection = "indisponible"
  }
}
