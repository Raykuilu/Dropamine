# Journal des versions

Version française du journal (le journal de référence est CHANGELOG.md, en anglais). Les versions plus anciennes ne sont qu'en anglais.

## 3.11.1

### Nouveautés
- La chasse BiS peut être coupée, pour les complétionnistes qui ne veulent que le carnet de collection : Réglages > Chasse et collection (« Chasse BiS »), la visite guidée, ou `/drop chasse off` / `on`. Coupée : plus d'onglet Chasse, plus d'essais comptés, plus d'alerte « objet recherché » ni de cadre au butin, rien sur la chasse dans `/drop hiscores`. Le carnet de collection continue et ta liste de chasse est gardée.
- Visite guidée : le carnet de collection et la chasse BiS ont chacun leur page, pour ne plus les confondre.
- `/drop hiscores` : tu coches ce que tu partages (temps de jeu, carnet de collection avec la liste des objets obtenus, succès, records, chasse) ; la fenêtre liste ce qui est inclus. dropamine.app montre alors ton carnet objet par objet.
- Liste de chasse depuis dropamine.app : coche des objets suggérés sur ta fiche, copie la commande et colle-la en jeu (`/drop <code>` : tout code du site fonctionne, inutile de retenir la commande). Les doublons sont ignorés et la limite de 20 objets est respectée.
- Sorties de groupe depuis dropamine.app : le bouton « Rappel dans le jeu » donne une commande `/drop <code>` ; Dropamine affiche alors un toast 15 min avant puis à l'heure, avec le `/w` de l'organisateur (clic sur le toast, ou sur le nom dans la ligne du chat, pour lui chuchoter). `/drop sortie` liste tes sorties, `/drop sortie vider` les oublie.
- Rangs de métier : l'infobulle et le toast de rang disent où trouver le maître pour ta faction (par exemple Travail du cuir 150 : Darnassus pour l'Alliance).
- Carnet de collection : clic droit sur l'icône d'un objet pour le marquer obtenu ou non.
- Rappel, une fois par jour au plus : quand ton carnet a de nouveaux objets depuis ton dernier `/drop hiscores`, une ligne dans le chat t'invite à recoller ta ligne sur dropamine.app, pour que ceux qui ont besoin des mêmes donjons te trouvent.

### Corrections
- Essais de chasse : un objet sans boss unique (plusieurs sources, monstres) ne compte que dans un donjon où il tombe, et une seule fois par sortie (des butins dans le même donjon à moins d'une heure d'écart = la même sortie). Les mauvais comptes d'avant (par exemple 54 « essais » sur la Marque de Kern) sont remis à zéro une fois.
- Carnet de collection : un objet vu dans la fenêtre de butin, ou gagné par un autre joueur au jet de groupe, n'est plus marqué comme le tien ; seuls « Vous recevez le butin » ou tes sacs et ton équipement comptent.
- Liste de chasse : les noms d'objets passent dans la langue de ton jeu dès que le jeu connaît l'objet (les objets importés pouvaient rester en anglais).

## 3.11.0

### Nouveautés
- `/drop hiscores` : une ligne d'export à coller sur dropamine.app (compétences d'armes, Défense, niveau, métiers, guilde), pour que ton entrée dans les classements utilise tes vraies compétences d'armes au lieu d'une estimation. L'addon n'envoie rien : tu copies et tu colles toi-même.

## 3.10.0

### Nouveautés
- Paliers de guilde (coupé par défaut) : un message de guilde quand ton niveau total franchit un palier (Progression > Annonces, avec un bouton d'essai).
- Maîtres d'armes : `/drop armes` liste aussi les armes que ta classe peut encore apprendre et où (Hurlevent, Forgefer, Darnassus, Orgrimmar, Les Pitons-du-Tonnerre, Fossoyeuse). Le rappel « arme non apprise » marche avant même ta visite chez un maître d'armes.
- Onglet Hardcore (Avancé > Hardcore), prêt pour le futur mode Hardcore de Forever : quand ta cible est élite, de niveau inconnu (??) ou a 3 niveaux de plus que toi, le cadre du panneau pulse en rouge, un bandeau dit pourquoi (« Élite · niveau ?? ») et la goutte bat en rouge, avec une ligne dans son infobulle. Les cases gardent leurs couleurs. Un son d'alerte joue une fois par cible dangereuse, même avec les sons de l'addon coupés (option « Son d'alerte sur la cible », avec un bouton d'essai). Deux curseurs règlent la taille et la force de la lueur du panneau et du halo de la goutte (0 % coupe chacun ; bouger un curseur montre l'alerte 4 s). Actif seulement sur un personnage Hardcore ; `/drop hc` dit si le Hardcore est officiel, manuel ou simulé (`/drop hc simu` le simule).
- Hardcore non officiel : « Je joue en Hardcore (mode non officiel) » dans l'onglet Hardcore (ou `/drop hc on|off`) active les aides Hardcore pour ce personnage seulement.
- Lien avec SkillUp Forever (seulement si SkillUp Forever est installé, Métiers > SkillUp Forever) :
  - L'infobulle des cases métier affiche l'étape en cours et la suivante de SkillUp, à la place du « Prochain +1 » de Dropamine.
  - Un toast seulement quand l'étape suivante t'envoie quelque part : un maître de recettes, un vendeur ou un donneur de quête. Les rangs de métier gardent le rappel de rang de Dropamine (pas de second toast).
  - Alt+clic sur une case métier pose le point de SkillUp sur la carte pour l'étape.
  - Lu seulement au survol et au plus toutes les 2 s, jamais en combat.
  - Aiguille GPS : tant que ce point est actif (point du jeu, sans TomTom ni Shortest Path), la goutte devient une aiguille qui pointe vers lui : vert devant, jaune sur le côté, rouge derrière, distance dans l'infobulle. À ~10 m : toast « Arrivé » et le point est retiré. Alt+clic sur la goutte pour le retirer. Coupée en donjon, ou avec l'option « Aiguille GPS dans la goutte ».
- Carnet de collection, Métiers : avec SkillUp Forever (facultatif), chaque métier affiche son total exact de recettes et la liste de celles qui te manquent, rangées par rang (Apprenti 1-75, Compagnon 76-150, Expert 151-225, Artisan 226-300 ; clic + / – pour plier, ton rang actuel ouvert par défaut), avec où obtenir chacune (vendeur et zone, quête, butin et chance, butin du monde, maître) et si un autre de tes personnages la connaît déjà (« Patron » quand seuls Questie ou AtlasLoot savent où). La liste de droite a une barre de défilement. Sans lui, la Cuisine et le Secourisme restent complets et les autres métiers suggèrent SkillUp.
- Toast « Nouvelle recette ! » quand ton personnage apprend une recette, avec ta progression dans ce métier quand SkillUp Forever est installé (Progression > Annonces).
- Rangs de Pêche : la quête d'Artisan demande maintenant Pêche 225 (comme la Cuisine et le Secourisme), et le rappel de rang dit où aller : le vieux Heming à Baie-du-Butin pour le livre d'Expert, Nat Pagle au marécage d'Âprefange pour la quête d'Artisan.
- Alias de commandes en anglais : `/drop hunt` (et `add` / `remove`), `/drop summary`, `/drop collapse`, `/drop expand` ; l'aide et le README en anglais utilisent les commandes anglaises.
- Visite guidée : la page des thèmes a aussi une case « Afficher le niveau total », et la dernière page cite les deux compagnons facultatifs, Dungeon Journal et SkillUp Forever.
- Carnet de collection : le même léger surlignage sous la souris partout (catégories, donjons, recettes, lignes Apprenti / Compagnon / Expert) ; les noms de recettes trop longs sont coupés par « … » et donnés en entier, avec leur source, dans l'infobulle.
- Les fenêtres de copie (`/drop debug`, `/drop bug`, export / import de profil) prennent le style des fenêtres du jeu, avec le portrait Dropamine.
- Bouton de la minicarte : quand un autre addon charge déjà LibDataBroker et LibDBIcon (Details, Questie, DBM…), le bouton de Dropamine passe par eux, pour ressembler aux autres boutons et rejoindre les sacs à boutons. Dropamine n'embarque toujours aucune bibliothèque ; sans elles, son propre bouton (même taille et bordure) reste.

### Corrections
- Les sources de recettes se mettent à jour dès que SkillUp Forever a fini de charger ses données.
- Carnet de collection : le bouton « Tri : niveau / % » restait bloqué sur % ; faire glisser la barre de défilement s'arrête quand on relâche la souris, même hors de la barre ; le surlignage au survol va jusqu'à la barre de défilement.
