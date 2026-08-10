# CLAUDE.md — lesensgiratoire

**Le Sens Giratoire** — site de recensement et de classement des ronds-points de France. Parodie structurelle de SensCritique : on note et on classe. Sous-titre : « La France tourne en rond ».

Projet du dimanche, sans deadline. Défaut : **Rails vanilla, le moins de code possible, aucune dépendance non demandée.**

## Le ton (non négociable)

Pince-sans-rire institutionnel. Sérieux parfait sur un sujet absurde. Le comique naît du sérieux — **jamais de la vanne**.

Vaut pour tout ce qui est visible : libellés, messages d'erreur, e-mails, noms de catégories, pages statiques.

- Pas d'emoji, pas de clin d'œil appuyé, pas d'exclamation
- Une fiche de rond-point doit se lire comme un document administratif
- Vouvoiement, français, registre neutre

En cas de doute sur un libellé drôle : proposer, ne pas trancher. L'éditorial se décide hors du code.

## Stack

- Rails + PostgreSQL
- Déploiement Scalingo
- Domaine `lesensgiratoire.fr` (IONOS)

## État

V1 fonctionnelle en local : carte, fiche, versement de photos, suffrages, palmarès. Pas de déploiement. Points ouverts dans `NOTES.md`.

## Commandes

```bash
bin/setup            # dépendances, création et préparation des bases
bin/dev              # serveur de développement (http://localhost:3000)
bin/rails db:seed    # charge db/seeds/*.json, idempotent (appariement par position)
bin/rails test       # modèles et parcours d'intégration
bin/rubocop          # rails-omakase
```

Pour un nouveau jeu de données, déposer le fichier dans `db/seeds/` au format du recensement girondin et relancer `bin/rails db:seed`.

## Contraintes dures (non négociables)

### Dépôt public

`Un3x/lesensgiratoire` est **public**. Aucune clé d'API, aucun credential, aucun dump de données personnelles ne doit y entrer — y compris dans l'historique, y compris dans les fixtures.

### ODbL — la licence contraint le code

Les données viennent d'OpenStreetMap, sous ODbL. Deux obligations qui se traduisent en code :

1. **Attribution visible** sur toute vue affichant des données ou un fond de carte : « © les contributeurs OpenStreetMap ».
2. **La base dérivée doit rester publiable.** L'objectif est de déposer le jeu de données sur data.gouv.fr sous ODbL. Le schéma doit permettre un export propre et documenté des ronds-points enrichis — ce n'est pas une tâche de fin de projet, ça se conçoit avec les migrations.

Les photos importées de sources tierces portent leurs propres licences : prévoir auteur, licence et lien par photo dès la modélisation.

## Modèle métier

- **Rond-point** — position, diamètre, commune (code INSEE), nom vernaculaire
- **Photos** — une **timeline d'observations datées**, pas une photo unique. Un rond-point change au fil des saisons.
- **Avis** — un avis binaire, favorable ou défavorable, **un seul par rond-point et par visiteur**, rattaché au navigateur sans inscription et **scopé par année**. D'où deux palmarès annuels : les ronds-points les plus et les moins appréciés de l'exercice.
- Les catégories thématiques (le plus dangereux, le plus fleuri, …) seront **inférées** plus tard par croisement de données externes, jamais soumises au vote. Ne figer aucune liste de catégories dans le modèle.
- **Carte d'accueil** — toute la France. Filtre d'affichage par défaut à **20 m de diamètre**, qui écarte les raquettes de retournement. Seuil d'affichage, jamais d'import.

## Import OSM — pièges mesurés

Ces quatre points ont été vérifiés sur données réelles. Les ignorer coûte cher.

1. **Un rond-point n'est pas un `way`.** 59 % des ways `junction=roundabout` sont des segments ouverts : un rond-point est découpé en arcs, un par branche entrante. Compter les ways surestime de 40 à 90 %. Il faut regrouper géométriquement (centroïdes à moins de 70 m).
2. **Le projet raisonne en diamètre**, les géométries brutes en rayon. Facteur deux, source d'erreur classique.
3. **Les identifiants OSM sont instables** — les ways se scindent et fusionnent entre deux imports. L'identité d'un rond-point est sa **position**, pas son ID OSM. Réapparier au ré-import par proximité du centroïde ; stocker les `osm_way_id` membres à titre indicatif.
4. **Les noms sont bruités.** 23 % des ronds-points ont un `name`, mais la majorité sont des noms de voie qui débordent sur le segment (« Rue du Jard »). Ne garder que les noms de lieu (Rond-point, Giratoire, Place, Carrefour, Esplanade) — environ 9 % du total.

Source d'import : extrait **Geofabrik** `france-latest.osm.pbf` (~5 Go, quotidien), filtré hors application par `osmium tags-filter`. **Pas Overpass** : trop instable pour un import national. Le rattachement à la commune passe par `geo.api.gouv.fr` ou la BAN.

Aucune source publique ne contient l'ornement : 2,5 % des ronds-points seulement. Le contenu est à produire, pas à importer.

## Style de code

- Rails vanilla d'abord : `validates`, `normalizes`, `enum`, scopes, Turbo. Si Rails a une opinion, la suivre.
- Pas de service object, de layer ou d'abstraction pour un seul appelant. Un modèle un peu gras vaut mieux qu'un modèle maigre entouré d'objets à usage unique.
- **Pas de commentaires** — le code doit se suffire. Exception : un « pourquoi » non évident.
- Tout fichier se termine par une newline.

## Commits & PRs

- Le message explique le **pourquoi**, pas le quoi. Sujet + une à deux lignes maximum, jamais la narration du diff.
- Le sujet énonce le changement de comportement en termes métier, pas l'artefact produit.
- Pas de trailer `Co-Authored-By`
- **Ne jamais désactiver la signature GPG** (`--no-gpg-sign`) — demander si la signature échoue
- Ne jamais sauter les hooks pré-commit (`--no-verify`) — corriger la cause

## Hors périmètre

Le suivi projet vit dans un vault séparé, à `/home/unex/Documents/mylife_in_a_vault/projects/sensgiratoire/` : `README.md` (concept, décisions), `STATUS.md` (état), `LOG.md` (historique), `OSM.md` (mesures d'import détaillées).

**Ne pas modifier ces fichiers depuis ce dépôt.** L'assistant du vault s'en charge.
