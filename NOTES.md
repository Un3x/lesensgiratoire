# Points restés ouverts après la v1

Aucune étape du brief n'a été bloquée. Ce qui suit est approximatif ou différé.

## Import national

- Le seed apparie chaque enregistrement par une requête de proximité : 1 808 ronds-points en 17 secondes. À 90 000, compter une quinzaine de minutes. Si c'est trop, passer à un appariement par lots ou à un index géographique (PostGIS n'est pas installé).
- L'emprise servie par `/ronds-points.json` est bornée à 2 000 marqueurs (`RoundaboutsController::MAX_MARKERS`). Au-delà, les plus grands diamètres sont retenus et l'état l'énonce. Aucun regroupement de marqueurs n'est implémenté : à réévaluer sur les données nationales, le rendu canvas de Leaflet tenant déjà quelques dizaines de milliers de cercles.
- Le rayon d'appariement est de 70 m à vol d'oiseau. Le jeu girondin n'a aucune paire en deçà de 71 m : la marge est mince, un ré-import dont les centroïdes bougent de quelques mètres reste sûr, un jeu plus dense ne le serait pas.

## Photographies

- Aucune variante d'image : `image_processing` n'est pas installé, les fichiers sont servis à leur taille d'origine. À ajouter dès que des versements réels arrivent.
- Aucune modération, aucune limitation de débit, aucun plafond de taille sur les versements.

## Suffrages

- Les trois catégories sont provisoires, l'éditorial reste à arbitrer.
- Le jeton de session est trivial à réinitialiser : le suffrage n'a aucune valeur probante. Acceptable sans comptes utilisateurs, à revoir si le palmarès devient un enjeu.
- Un suffrage ne peut pas être retiré une fois exprimé.
- La base de développement contient 252 suffrages de démonstration, hors seed.

## Divers

- Leaflet 1.9.4 est vendorisé (`vendor/javascript/leaflet.js`, `vendor/assets/stylesheets/`) : jspm ne le résout pas en ESM. Mise à jour manuelle. La référence de sourcemap a été retirée du fichier pour éviter un 404 en console.
- La vérification Chromium et Firefox a été faite avec Playwright hors du dépôt : aucun test système n'est versé.
- L'export ODbL vers data.gouv.fr n'est pas écrit. Le schéma s'y prête — position faisant identité, `osm_way_ids` conservés à titre indicatif — mais rien ne produit le jeu de données.
- Aucune page statique (mentions, méthode de recensement, licence détaillée). L'attribution OpenStreetMap est portée par le pied de page et par chaque carte.
