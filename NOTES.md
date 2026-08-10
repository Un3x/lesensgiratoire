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
- **En revanche l'affichage national n'est pas représentatif.** À l'échelle de la France, 38 956 ronds-points relèvent du seuil de vingt mètres et le plafond de 2 000 marqueurs en écarte 95 %. Les retenus sont les plus grands diamètres : une région dense en petits ouvrages paraît vide alors qu'elle est recensée. L'état l'énonce, mais la carte donne une image fausse de la répartition.
- Le plafond ne se fait plus sentir dès l'échelle de l'agglomération : Bordeaux 663 ouvrages, Lille 352, Marseille 287, Strasbourg 147, tous servis. La région parisienne au sens large en compte 3 623 et reste tronquée.
- Aucun regroupement de marqueurs n'est implémenté. Un échantillonnage réparti dans l'emprise, ou un agrégat par maille, rendrait la vue nationale honnête — ce n'est pas fait.

## Photographies

- Aucune variante d'image : `image_processing` n'est pas installé, les fichiers sont servis à leur taille d'origine. À ajouter dès que des versements réels arrivent.
- Aucune modération, aucune limitation de débit, aucun plafond de taille sur les versements.

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
