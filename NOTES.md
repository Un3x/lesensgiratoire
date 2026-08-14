# Points restés ouverts après la v1

Aucune étape du brief n'a été bloquée. Ce qui suit est approximatif ou différé.

## Import national

Le recensement national est chargé : `db/seeds/roundabouts_france.json.gz`, 60 047 entrées, 1,7 Mo compressé contre 13 Mo en clair. Le chargeur lit indifféremment `.json` et `.json.gz`.

- **Le seed a duré 9 min 55 s** pour 60 047 entrées, dont 58 238 inscriptions et 1 809 appariements sur des ouvrages déjà en base. L'estimation d'une quinzaine de minutes était pessimiste. Le coût reste linéaire : une requête de proximité par entrée.
- L'appariement a préservé les photographies et les avis attachés aux 1 808 ronds-points girondins déjà recensés. Aucune paire d'ouvrages distante de moins de 70 m ne subsiste en base.
- Le fichier national contient une paire d'ouvrages distante de moins de 70 m, fusionnée à l'import : 60 047 entrées pour 60 046 lignes. Le rayon d'appariement n'est donc plus sans effet sur les données d'origine comme il l'était sur le jeu girondin.
- Le seed n'efface jamais : un ouvrage disparu d'OpenStreetMap reste en base après ré-import. Aucune procédure de retrait n'existe.
- 3 494 ronds-points sont dépourvus de commune, 50 920 de dénomination.
- 751 ouvrages sont situés outre-mer (La Réunion, Guadeloupe, Mayotte). **Ils sont hors de l'emprise par défaut** `RoundaboutsController::FRANCE_BBOX`, qui ne couvre que la métropole : une requête sans emprise ne les renvoie jamais. La carte les affiche si l'on s'y déplace, mais rien n'y conduit.

## Rendu de la carte à l'échelle nationale

Mesuré dans Chromium et Firefox sur les 60 046 ouvrages, sans avertissement console.

- Le serveur tient : 87 à 92 ms pour l'emprise France entière, 19 à 80 ms pour une agglomération. Premier relevé rendu en moins d'une seconde.
- **L'affichage national est représentatif depuis l'échantillonnage.** Les 2 000 marqueurs sont prélevés uniformément parmi les 38 956 de l'emprise, et non plus par diamètre décroissant. Le diamètre médian affiché passe de 76,8 m à 31,9 m, soit exactement celui du recensement. Part de l'Île-de-France : 6,60 % dans l'échantillon pour 6,33 % au recensement ; pourtour méditerranéen 11,25 % pour 10,76 % ; Massif central 1,25 % pour 1,30 % — contre 0,65 % sous l'ancien tri, qui effaçait de moitié les régions à petits ouvrages.
- Le tirage repose sur une colonne `sample_key`, entier aléatoire attribué à l'inscription par défaut de la base et indexé. Il est donc stable d'un relevé à l'autre : les marqueurs ne sautillent pas au déplacement de la carte.
- **La colonne a été retenue sur mesure, pas par principe.** Trier à la volée sur un hachage de l'identifiant coûte cher à cette volumétrie : `md5(id::text)` porte la réponse nationale de 67 à 144 ms, `hashtext` et `hashint8` à 105 ms. La colonne indexée la laisse à 68 ms, soit le coût de l'ancien tri par diamètre. L'échantillonnage ne coûte donc rien.
- Le curseur de diamètre reste le moyen de retrouver la carte des grands ouvrages : à 55 m, 4 359 ronds-points subsistent. Les deux lectures restent disponibles, mais celle par défaut ne ment plus.
- Le plafond ne se fait plus sentir dès l'échelle de l'agglomération : Bordeaux 663 ouvrages, Lille 352, Marseille 287, Strasbourg 147, tous servis. La région parisienne au sens large en compte 3 623 et reste tronquée.
- Aucun regroupement de marqueurs n'est implémenté. Un échantillonnage réparti dans l'emprise, ou un agrégat par maille, rendrait la vue nationale honnête — ce n'est pas fait.
- Le rayon et l'opacité des marqueurs suivent le niveau de zoom, et le liseré ne réapparaît qu'à partir du zoom 10 : les zones denses se lisent en dégradé au lieu de former une masse. Cela corrige la lisibilité, pas la représentativité — les 95 % écartés par le plafond le restent.
- Leaflet 1.9.4 émet deux avertissements de dépréciation dans Firefox (`MouseEvent.mozPressure`, `MouseEvent.mozInputSource`) au glisser-déposer de la carte, et à cette seule occasion. Ils viennent de la bibliothèque, pas du code du site.

## Photographies

- Une observation porte soit un fichier joint, soit une adresse distante (`image_url`), jamais rien. Les clichés Panoramax ne sont pas téléchargés : le dépôt ne les héberge pas et le service public n'est pas ré-hébergé.
- L'attribution — auteur, licence, lien vers la source — est exigée par validation dès qu'une observation est distante, et rendue sous chaque cliché. Les licences sont mélangées, `etalab-2.0` et `CC-BY-SA-4.0` : elles ne sont jamais globalisées en pied de page.
- 4 388 observations Panoramax sont versées sur 2 231 ouvrages — 3,7 % du recensement, mais 1 167 d'entre eux portent désormais une timeline de plusieurs dates : 608 en portent 2, 314 en portent 3, et 63 atteignent le plafond de 6. Diamètre médian des ouvrages illustrés : 22,5 m, contre 24,5 m pour l'ensemble. Prises de vue de 2010 à 2026.
- **Le `sd` est retenu, pas le `thumb`.** Le `thumb` fait invariablement 500 px de large pour 26 Ko médians ; la colonne de la fiche en fait 576. Il s'afficherait donc plus étroit que la mise en page ne le permet, et flou sur écran à haute densité. Le `sd` fait 2 048 px pour 120 à 580 Ko, s'affiche en 576 × 433 et reste net. Une fiche ne porte qu'une observation et l'image est chargée en différé chez Panoramax : le poids est supportable. Le `thumb` redeviendra le bon choix le jour où une vue de liste ou une galerie affichera plusieurs clichés à la fois.
- Sur 30 clichés échantillonnés, 3 sont des panoramiques équirectangulaires 2:1 et 27 des photographies ordinaires en 4:3 ou 16:9. La réserve formulée avant livraison ne concerne donc qu'environ un dixième du lot.
- **Le cadrage est jugé par croisement de `ecart_deg` et `rapport`, sans seuil arbitraire** : l'axe de visée doit tomber sur l'ouvrage. L'ouvrage occupe une demi-largeur apparente de `asin(1 / rapport)` — 32° à la médiane — et l'observation est retenue tant que l'écart de visée n'excède pas cette demi-largeur. `Photo::CADRAGE_TOLERANCE_DEG` vaut 0 : c'est le seul réglage, si l'on veut relâcher ou durcir.
- 540 observations sur 2 770 sont écartées, 19,5 %. Le critère récupère 173 des 457 qu'un seuil fixe à 35° écartait, dont le Rond-Point de Segorbe (fiche 517, écart 38° mais objectif au ras de l'anneau), et en écarte 256 que ce seuil gardait : des clichés lointains où le rond-point n'est qu'une tache loin de l'axe.
- Sur les quatre fiches servant de témoins, le critère classe juste : Segorbe, Arcachon et Aix conservent leur cliché, la fiche 561 des Abatilles — un trottoir, écart 46° pour une demi-largeur de 31° — le perd.
- Une ligne dépourvue de `rapport` retombe sur une demi-ouverture par défaut de 35° (`Photo::DEMI_OUVERTURE_DEFAUT_DEG`), c'est-à-dire l'ancien seuil fixe. Une ligne dépourvue d'`ecart_deg` est retenue.
- **Deux voies d'alimentation, un seul chemin de versement.** `panoramax:import` lit un fichier JSONL, `panoramax:moisson` interroge l'API et calcule lui-même l'écart de visée depuis le cap de la caméra (`view:azimuth`) et le rapport depuis le diamètre de l'ouvrage. Les deux passent par le même filtre de cadrage et le même enregistrement.
- La moisson **réconcilie** la timeline d'un ouvrage : elle évince les observations distantes qu'elle ne retient plus. Sans quoi elle s'ajoutait à l'existant — les mêmes vues circulent sous plusieurs hôtes Panoramax (`panoramax.openstreetmap.fr`, `panoramax.ign.fr`, et des instances tierces), et un premier passage sans éviction avait produit 1 725 couples (ouvrage, date) en double. Une date ne porte plus qu'une observation distante, garanti par validation.
- Une prise de vue à champ de 300° ou plus échappe au critère de cadrage : une panoramique contient l'ouvrage quel que soit le cap. À date égale, le classement par résiduel préfère néanmoins une photographie plate.
- **Environ un quart des observations sont des panoramiques équirectangulaires** (13 sur 50 échantillonnées). Elles sont désormais **redressées dans le navigateur** : le serveur ne stocke que le cap visé, l'inclinaison et l'angle de champ, le client télécharge l'équirectangulaire chez Panoramax et en dessine la vue rectilinéaire sur un canvas 2D. Aucune image dérivée n'est hébergée, aucune dépendance ajoutée ni côté Ruby ni côté JavaScript.
- Le cap est absolu, mesuré depuis le nord, de la caméra vers le centre de l'ouvrage. La colonne x = 0 de l'équirectangulaire vaut le nord géographique — Panoramax normalise ses panoramiques, le cap de la caméra (`view:azimuth`) n'intervient donc pas dans le redressement. L'inclinaison est de −12° par défaut (`Photo::INCLINAISON_DEFAUT_DEG`, positif vers le haut) et l'angle de champ de 75°, en seize neuvièmes.
- Le redressement coûte 20 ms de lecture des pixels et 68 ms de calcul par cliché, pour une sortie de 960 × 540 depuis une source de 2 048 × 1 024. Il se fait à l'affichage de la fiche, sans blocage perceptible.
- **Le redressement dépend des en-têtes CORS de Panoramax**, sans lesquels le canvas serait souillé et les pixels illisibles. Vérifié : `panoramax.openstreetmap.fr` répond `Access-Control-Allow-Origin: *`, `panoramax.ign.fr` renvoie l'origine appelante. À revérifier depuis le domaine de production. Deux instances tierces marginales (`panoramax.mapcomplete.org`, `images.panoramax.basi.re`, 7 clichés) n'ont pas été vérifiées.
- Si l'image ne se charge pas ou que le canvas est souillé, l'équirectangulaire brute reste affichée : la vue redressée est un enrichissement, pas une condition. Sans JavaScript, la fiche montre la brute.
- **Le filtre de distance est plan et ignore la dénivellation.** Une caméra passant sous un ouvrage en pont produit une vue redressée inutilisable. Aucun signalement par le visiteur n'est encore prévu.
- La moisson porte sur les 2 231 ouvrages déjà connus de Panoramax, en 8 à 10 minutes. L'étendre au recensement entier demanderait environ 60 000 requêtes, soit une quinzaine d'heures : la tâche accepte un rang de départ et un décompte pour être reprise par tranches.
- Le rejeu du fichier **converge dans les deux sens** : il verse ce qui redevient recevable et retire ce qui ne l'est plus, apparié par `(rond-point, url)`. Le durcissement du critère a ainsi retiré 256 observations et en a versé 173 en un seul passage. Les observations jointes à la main ne sont jamais touchées. Un second passage ne bouge plus.
- `i`, `thumb`, `distance_m` et `rapport` ne sont pas conservés, et `ecart_deg` sert au filtrage sans être stocké : un changement de seuil exige donc de rejouer le fichier. `rapport` vaut approximativement la distance de prise de vue divisée par le rayon de l'ouvrage — médiane 1,89, soit un objectif situé juste à l'extérieur de l'anneau.
- Le JSONL est versé compressé, `db/seeds/photos_panoramax.jsonl.gz`, 178 Ko contre 1,2 Mo en clair. La tâche rake lit les deux formes.
- Aucune variante d'image : `image_processing` n'est pas installé, les fichiers joints sont servis à leur taille d'origine.
- Aucune modération, aucune limitation de débit, aucun plafond de taille sur les versements.
- Le formulaire de versement n'expose pas `image_url` et le contrôleur ne l'accepte pas : une adresse distante n'entre que par `bin/rails panoramax:import`. Un visiteur ne peut pas faire pointer une observation vers une image arbitraire.
- La base de développement contient une observation Panoramax supplémentaire sur la fiche n° 13, versée à la main avant livraison pour vérifier le rendu. Elle n'est pas dans le JSONL.

## Avis

- L'avis est binaire et unique par rond-point et par exercice. Le modèle ne porte aucune liste de catégories : les catégories thématiques seront inférées par croisement de données externes, pas soumises au vote.
- Un avis est révisable jusqu'à la clôture de l'exercice — le sens s'inverse sur l'enregistrement existant. Il ne peut pas être retiré : rien ne permet de revenir à l'absence d'avis.
- Le jeton de session est trivial à réinitialiser : l'avis n'a aucune valeur probante. Acceptable sans comptes utilisateurs, à revoir si le palmarès devient un enjeu.
- Les deux classements sont indépendants : un ouvrage très fréquenté peut figurer dans les deux. Aucun score net n'est calculé, aucun seuil de participation n'est exigé.
- La base de développement contient 159 avis de démonstration répartis sur 42 ouvrages, hors seed.

## Divers

- Leaflet 1.9.4 est vendorisé (`vendor/javascript/leaflet.js`, `vendor/assets/stylesheets/`) : jspm ne le résout pas en ESM. Mise à jour manuelle. La référence de sourcemap a été retirée du fichier pour éviter un 404 en console.
- La vérification Chromium et Firefox a été faite avec Playwright hors du dépôt : aucun test système n'est versé.
- L'export ODbL vers data.gouv.fr n'est pas écrit. Le schéma s'y prête — position faisant identité, `osm_way_ids` conservés à titre indicatif — mais rien ne produit le jeu de données.
- Aucune page statique (mentions, méthode de recensement, licence détaillée). L'attribution OpenStreetMap est portée par le pied de page et par chaque carte.
