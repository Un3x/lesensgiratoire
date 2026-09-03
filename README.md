# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Pipeline de données


### Ronds-points

| Étape | Source / outil | Résultat |
|---|---|---|
| Récolte | OpenStreetMap via Overpass, une requête par département (`admin_level=6`), trois miroirs en parallèle (`overpass-api.de`, `overpass.kumi.systems`, `overpass.private.coffee`) | 143 494 ways `junction=roundabout`, ~2 h, aucun échec |
| Regroupement | Union-find sur centroïdes à moins de 70 m | 60 047 ouvrages (ratio ways/ouvrages 0,418) |
| Mesure | Diamètre calculé sur la grappe | Médiane 24 m, p99 86 m. Filtre d'affichage 20 m, jamais d'exclusion à l'import |
| Noms | Préfixe Rond-point / Giratoire / Place / Carrefour / Esplanade | 9 127 noms exploitables (15 %) |
| Commune | `geo.api.gouv.fr` ou BAN `api-adresse.data.gouv.fr/reverse/`, une requête par ouvrage | 56 553 rattachés (94 %), ~10 min |
| Ré-import | Réappariement par proximité du centroïde (< 70 m), `osm_way_id` stockés à titre indicatif | Résiste aux scissions et fusions de ways |

Rafraîchissements futurs : extrait Geofabrik France `.osm.pbf` filtré par `osmium tags-filter`, pour ne plus solliciter Overpass.

### Images

| Étape | Source / critère | Résultat |
|---|---|---|
| Tags OSM | `mapillary`, `wikidata` P18, `image`, `wikimedia_commons`, `panoramax` | 21 ouvrages illustrables sur 60 047. Voie abandonnée |
| Panoramax par emprise | API par bbox de 50 m autour du centroïde | 50 % des ouvrages couverts |
| Exclusion 360° | `pers:interior_orientation.field_of_view >= 300` | 28 % restants |
| Visée et distance | `view:azimuth` pointant vers l'ouvrage à ± un demi-champ, rapport distance/rayon entre 1,2 et 4, tri par proximité de 2 | 2 770 ouvrages illustrés (4,6 %) |
| Reprojection 360° | Équirectangulaire, x = 0 au nord géographique, champ ~75°, 16/9, inclinaison −12°, calcul dans le navigateur sur canvas | ~21 000 ouvrages supplémentaires, moisson en cours |

Les images ne sont jamais copiées. On stocke l'identifiant Panoramax, le cap, l'inclinaison et l'angle de champ ; le client télécharge l'original.

Limite connue : le filtre de distance est en 2D et ne voit pas la dénivellation (ouvrage sur pont, caméra sur la voie en dessous).

### Licences

| Ressource | Licence | Conséquence |
|---|---|---|
| OpenStreetMap | ODbL 1.0 | Notre table est une base dérivée, donc share-alike. Publication prévue sur data.gouv.fr en `odc-odbl` |
| Panoramax | Par photo : 2 472 CC-BY-SA-4.0, 298 etalab-2.0 | Attribution par photo (auteur, licence, lien), jamais globalisée |
| Wikimedia Commons | CC BY-SA, hétérogène | Droit d'auteur, pas droit de base. Juxtaposition sans adaptation = attribution seule. Vérifier au cas par cas |
| geo.api.gouv.fr, BAN | Licence Ouverte Etalab | Compatible ODbL |
| IGN BD TOPO | Licence Ouverte Etalab | Écartée (noms de voie, aucun ornement, 382 862 tronçons). En réserve pour recoupement |
| Mapillary | CC BY-SA, Meta | Non utilisé |

Distinction ODbL : la carte affichée est une œuvre produite (attribution seule) ; le stockage de la table est une base dérivée (share-alike). C'est le stockage qui engage.

Ce qu'aucune source ne donne : l'ornement. 2,5 % des ouvrages girondins ont un objet `tourism=artwork`, `historic=memorial`, `amenity=fountain` ou `man_made=sculpture` à proximité, un seul avec image. Le contenu est à produire par les visiteurs.
