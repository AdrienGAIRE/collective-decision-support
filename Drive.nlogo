globals [
 xprep
 yprep
 colorprep
]

breed [clients client]

breed [preparateurs preparateur]

breed [bornes borne]

breed [entrees entree]

breed [bouchons bouchon]

clients-own [
  commande
  time
  heure_commande
  heure_livraison
  xcor_borne
  ycor_borne
  borne_target
  servi ; Permet de savoir si le client a été servi afin qu'il libère la borne
  en_cours ; Permet de savoir si un preparateur s'occupe de la commande du client
]

bornes-own [
  libre
]

preparateurs-own [
  client_target ; Permet de connaitre le client dont il s'occupe
  commande_en_cours
  x_ini ; Les coordonnées initiales permettent de replacer les préparateurs à leur place lors des phases de stand-by
  y_ini
  fini ; Permet de savoir si le préparateur a récupéré tous les articles
  xcor_borne  ; Permet de savoir à quelle borne le préparateur doit livrer
]

to draw_entreprot
 ; on nettoie tout: la fenetre graphique, les variables globales, ...
  clear-all
  ; position du premier preparateur a l initialisation de l entrepot
  set xprep 85
  set yprep -35
  set colorprep [red orange yellow lime sky violet magenta brown gray pink]
  ; on remets a zero le compteur de tick
  reset-ticks
  ; mur nord entreprot
  ask patches with [pycor = 65 and pxcor >= -80 and pxcor <= 90] [set pcolor white]
  ; mur sud entreprot
  ask patches with [pycor = -40 and pxcor >= -80 and pxcor <= 90] [set pcolor white]
  ; mur est entrepot
  ask patches with [pxcor = -80 and pycor >= -40 and pycor <= 65] [set pcolor white]
  ; mur ouest entreprot
   ask patches with [pxcor = 90 and pycor >= -40 and pycor <= 65] [set pcolor white]
  ; E/S entreprot sur mur sud
  ask patches with [pycor = -40 and pxcor >= 50 and pxcor <= 75] [set pcolor black]
  ; les bornes du drive
  ask patches with [pycor > -65 and pycor < -50 and pxcor > -50 and pxcor < 40 and pxcor mod 12 = 0] [
    set pcolor cyan
    if pycor = -60 [
    sprout-bornes 1[
    set size 5
    set shape "cylinder"
    set label who
    set heading 0
    set color green
    set libre true
    ]
    ]
  ]
  ; l entree du parking
  init-entree
  ; les rayonnages
  ask patches with [ pxcor > -80 + 15 and pxcor < 90 - 16 and pycor < 65 - 16 and pycor > 65 - 16 - 28 and pxcor mod 16 = 0] [set pcolor white]
  ask patches with [ pxcor > -80 + 15 and pxcor < 90 - 16 - 33 and pycor < 65 - 16 - 28 - 16 and pycor > -40 + 16 and pxcor mod 16 = 0]  [set pcolor white]
  ; les preparateurs
  creer-preparateur
end

to init-entree
  ask patch 98 -45 [
    sprout-entrees 1 [
    set size 5
    set heading 270
    set color blue
    set shape "arrow" ]
    ]
  ; Créé l'image affichée en cas de bouchon
    ask patch 90 -55 [
      sprout-bouchons 1[
        set size 10
        set color red
        set shape "face sad"
        set label "Bouchons !"
        hide-turtle]
      ]
end

to creer-preparateur
  create-preparateurs nb_preparateurs [
  setxy xprep yprep
  set x_ini xprep
  set y_ini yprep
  set yprep yprep + 10
  set size 8
  set color one-of colorprep
  set colorprep remove color colorprep
  set shape "preparateur"
  set heading 270
  set commande_en_cours []
  set fini false
  set xcor_borne -1
  set client_target ""
  ]
end

to go-entree
  let x random-poisson (flux_client / 10000.0)
  while [ x > 0]
    [ ask one-of entrees
        [
         hatch-clients 1 [ init-client ]]
      set x x - 1
    ]
end

to init-client
  set shape "car"
  set heading 270
  set size 8
  set color blue - 3 + random 6
  set time 0
  set heure_commande ticks
  set heure_livraison heure_commande + delai_preparation_commande
  set xcor_borne -1
  set servi false
  set en_cours false
  ; Permet de créer une commande sous forme d'une liste de coordonnées d'articles.
  let x (random (nombre_article_max - nombre_article_min)) + nombre_article_min - 1 ; nb d'articles de la commande
  set commande (list (list ((- 64 + (random 8) * 16) - 4 + (random 2) * 9 ) (22 + random 27))) ; Correspond au premier élément de la commande
  while [x > 0] [
    ifelse random 2 = 1 [ set commande lput (list ((- 64 + (random 9) * 16) - 4 + (random 2) * 9 ) (22 + random 27)) commande ][ set commande lput (list ((- 64 + (random 7) * 16) - 4 + (random 2) * 9 ) (4 - random 27)) commande]
    set x x - 1
  ]
  ; La commande est ensuite triée pour que les préparateurs soient plus rapides
  set commande sort-by [ item 0 ?1 > item 0 ?2] commande
  end

to go-preparateur

  ; Les préparateurs en stand-by récupère la commande d'un client dont personne ne s'occupe pour le moment
  ask preparateurs with [commande_en_cours = [] and fini = false and xcor_borne = -1 and xcor = x_ini ] [
    set client_target one-of clients with [en_cours = false] with-min [heure_livraison]
    if client_target != nobody [
      set commande_en_cours [commande] of client_target
      ask client_target [set en_cours true]
    ]
  ]

  ; On est en phase de recherche d'articles.
  ask preparateurs with [ commande_en_cours != [] and fini = false and xcor_borne = -1] [
    if ycor < 18 and xcor > 80 [; On sort de la position de départ.
      ifelse heading != 270 [right 1][ fd 1]
    ]
    if ycor > 18 and xcor > 80 [; On sort de la position de départ.
      ifelse heading != 270 [left 1][fd 1]
    ]

    if ycor < 18 and xcor <= 80 and xcor > 76 [; On va dans la rangée centrale.
      ifelse heading != 0 [right 1][ fd 1]
    ]
    if ycor > 18 and xcor <= 80 and xcor > 76 [; On va dans la rangée centrale.
      ifelse heading != 180 [left 1][fd 1]
    ]

    ;On est dans la rangée centrale et maintenant on va chercher les articles.
    if xcor < item 0 ( item 0 commande_en_cours ) and ycor = 18 [ ; on avance dans la rangée centrale.
      ifelse heading != 90 [right 1][ fd 1]
    ]
    if xcor > item 0 ( item 0 commande_en_cours ) and ycor = 18 [
      ifelse heading != 270 [ifelse ( 270 - heading ) mod 360 <= 180 [right 1][left 1]][ fd 1]
    ]
    if xcor != item 0 ( item 0 commande_en_cours ) and ycor < 18 and xcor <= 80[ ; on avance vers la rangée centrale.
      ifelse heading != 0 [right 1][ fd 1]
    ]
    if xcor != item 0 ( item 0 commande_en_cours ) and ycor > 18 and xcor <= 80[
      ifelse heading != 180 [left 1][ fd 1]
    ]

    if xcor = item 0 ( item 0 commande_en_cours ) and ycor < item 1 ( item 0 commande_en_cours ) [ ; on avance dans la rangée de l'item
      ifelse heading != 0 [right 1][ fd 1]
    ]
    if xcor = item 0 ( item 0 commande_en_cours ) and ycor > item 1 ( item 0 commande_en_cours ) [
      ifelse heading !=  180 [left 1][ fd 1]
    ]
    if xcor = item 0 ( item 0 commande_en_cours ) and ycor = item 1 ( item 0 commande_en_cours ) [ ; on prend l'article
    set commande_en_cours but-first commande_en_cours
      if commande_en_cours = [] [
        set fini true
      ]
    ]
  ]

  ; On est en phase de sortie.
  ask preparateurs with [ commande_en_cours = [] and fini = true and xcor_borne = -1][
    if ycor < 8  and xcor != 58[; On va vers l'allée centrale
      ifelse heading != 0 [left 1][ fd 1]
    ]
    if ycor > 8  and xcor != 58[
      ifelse heading != 180 [left 1][fd 1]
    ]

    if xcor < 58 and ycor = 8 [ ; on avance dans la rangée centrale.
      ifelse heading != 90 [ifelse ( 90 - heading ) mod 360 <= 180 [right 1][left 1]][ fd 1]
    ]
    if xcor > 58 and ycor = 8 [
      ifelse heading != 270 [ifelse ( 270 - heading ) mod 360 <= 180 [right 1][left 1]][ fd 1]
    ]
    if xcor = 58  and ycor > -45 [ ; On avance vers la porte.
      ifelse heading != 180 [right 1][fd 1]
    ]
    if xcor = 58  and ycor = -45 [
      if ([xcor_borne] of client_target) != -1 [
        set xcor_borne ( [ xcor_borne ] of client_target )
      ]
    ]
  ]

  ; On est en phase déplacement vers borne.
  ask preparateurs with [ commande_en_cours = [] and fini = true and xcor_borne != -1 ][
    if ycor > -45 [; je descend.
      ifelse heading != 180 [right 1][fd 1]
    ]
    if xcor < xcor_borne and ycor = -45 [ ; on va vers la borne
      ifelse heading != 90 [right 1][ fd 1]
    ]
    if xcor > xcor_borne and ycor = -45 [ifelse heading != 270 [right 1][ fd 1]]
    if xcor = xcor_borne and ycor < -55 [ifelse heading != 0 [right 1][ fd 1]] ; on va vers la borne
    if xcor = xcor_borne and ycor > -55 [ifelse heading != 180 [left 1][fd 1]]
    if xcor = xcor_borne and ycor = -55 [
      set fini false
      ask client_target [set servi true]
    ]
  ]

  ; Une fois arrivé, le préparateur peut retourner en stand-by, on se dirige donc vers l'entrepôt
  ask preparateurs with [commande_en_cours = [] and xcor_borne != -1 and fini = false] [
    if ycor < -45 and heading != 0 and xcor < 70 [right 1]
    if ycor < -45 and heading = 0 and xcor < 70 [fd 1]
    if ycor = -45 and heading != 90 and xcor < 70 [right 1]
    if ycor = -45 and heading = 90 and xcor < 70 [fd 1]
    if ycor = -45 and heading != 0 and xcor = 70 [left 1]
    if ycor = -45 and heading = 0 and xcor = 70 [set xcor_borne -1]
  ]

  ; Une fois de retour, le préparateur retourne à sa place initiale pour s'occuper d'une nouvelle commande
  ask preparateurs with [commande_en_cours = [] and xcor_borne = -1 and fini = false] [
    if ycor < y_ini and heading = 0 and xcor < x_ini [fd 1]
    if ycor = y_ini and heading != 90 and xcor < x_ini [right 1]
    if ycor = y_ini and heading = 90 and xcor < x_ini [fd 1]
    if ycor = y_ini and heading != 270 and xcor = x_ini [left 1]
    if ycor = y_ini and heading != 270 and xcor = x_ini [
      set xcor_borne -1
      set client_target nobody
      ]
  ]
end

to go-client
  tick
  ; Petite modification pour que les clients se garent dans l'ordre d'arrivée.
  ask clients with [heure_livraison <= ticks and xcor_borne = -1] with-min [heure_livraison] [
    let borne_libre one-of bornes with [libre = true]
    ifelse borne_libre != nobody [
    set xcor_borne ([xcor] of borne_libre) - 6
    set ycor_borne [ycor] of borne_libre
    set borne_target borne_libre
    ask borne_libre [set libre false]
    ask bouchons [hide-turtle] ; Retire l'affichage des bouchons
    ][ask bouchons [show-turtle]] ; Affichage en cas de bouchon
  ]

  ; les clients se garent.
  ask clients with [xcor_borne != -1 and servi = false] [
    if xcor > xcor_borne [fd 1]
    if xcor <= xcor_borne and heading > 180 [left 1]
    if heading = 180 and ycor > ycor_borne [fd 1]
    if abs (xcor - xcor_borne) < 2 and abs (ycor - ycor_borne) < 2 [ask borne_target [ set color red ] ]
  ]

  ; Départ des clients
  ask clients with [servi = true][
    if ycor = -70 [ask borne_target [ set libre true set color green ] ]
    if ycor > -75 [fd 1]
    if ycor = -75 [die]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
386
10
1154
610
100
75
3.7711443
1
10
1
1
1
0
0
0
1
-100
100
-75
75
0
0
1
ticks
30.0

BUTTON
9
111
136
144
NIL
draw_entreprot
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
168
246
201
delai_preparation_commande
delai_preparation_commande
20
2000
1000
1
1
NIL
HORIZONTAL

SLIDER
10
213
245
246
flux_client
flux_client
0
100
10
1
1
NIL
HORIZONTAL

SLIDER
11
257
183
290
nb_preparateurs
nb_preparateurs
0
10
6
1
1
NIL
HORIZONTAL

BUTTON
150
112
376
145
Lancer la simulation
go-preparateur\ngo-client\ngo-entree\n
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
11
349
183
382
nombre_article_max
nombre_article_max
nombre_article_min
20
10
1
1
NIL
HORIZONTAL

SLIDER
11
303
183
336
nombre_article_min
nombre_article_min
1
nombre_article_max
5
1
1
NIL
HORIZONTAL

@#$#@#$#@
## SUJET

  L’objectif de ce TP est de modeliser et simuler le fonctionnement d’un drive composé d’un entrepôt et d’une zone de chargement.

  Les clients de ce drive passent une commande sur Internet et se rendent ensuite à l’entrepôt en voiture pour recupérer leurs courses. Durant ce laps de temps, des préparateurs rassemblent le contenu de la commande dans des sacs mis en caddy. Ils doivent pour cela parcourir l’entrepôt pour rassembler les differents produits de la commande.

  Lorsque le client arrive à l’entrepôt en voiture, il se gare à l’une des bornes et déclare sa présence. Quelques minutes plus tard, un employé du drive apporte la commande du client jusqu’a sa voiture.


## MODIFICATIONS DU PROGRAMME INITIAL

  Le programme initial permet de commencer sans se soucier des détails d'affichage ou de structure globale, cependant, il y avait quelques erreurs:

 - Une voiture dont l'heure de livraison était passée risquait de ne jamais aller ce garer, ce qui est bien dommage pour le préparateur qui a préparé sa commande.
 - Les voitures se garent dans un ordre aléatoire, et non pas par ordre d'arrivée, ce qui énerve les premiers, qui finissent par klaxonner violement.
 - Il arrivait que deux personnes partent à peu près en même temps pour se garer sur la même place... Mais du coup, le deuxième emboutissait l'arrière du premier, et les factures nous étaient renvoyées pour cause de mauvaise gestion du parking.

  Nous avons aussi pensé que savoir s'il y a ou non des bouchons est un facteur important, c'est pour cela qu'un affichage particulier est mis en place pour indiquer le mécontentement des clients qui attendent.

  Une fois tout celà fait, il a été temps de partir à l'assaut du rangement de l'entrepôt.


## LES COMMANDES

  Pour simplifier la vie des préparateurs qui oublient sans cesse où sont stocké les produits d'entretient, et notemment les pastilles canard WC, nous avons décidé de leur donner les commander sous forme de coordonnées. De cette façon, il est plus facile de vérifier s'ils vont bien au bon endroit et le code en est simplifié, il suffit de faire correspondre les coordonnées du préparateur avec celles de la commande.
  Une commande est créée lors de l'apparition du client, comprenant un nombre d'élément aléatoire dans l'intervale choisi pour la simulation. La commande est donc une liste de liste, et les coordonnées sont toutes à 4 patchs des rayonnages, pour éviter que les préparateurs ne rentrent directement dedans et ne se casse le nez.


## LE DÉPLACEMENT DES PRÉPARATEURS

 Nous avons défini 6 états pour les préparateurs:
 - Stand-by : sans commande, les préparateur attendent à leur place initiale qu'un client passe commande.
 - Récupération des articles : c'est le moment de travailler, les préparateurs avancent dans la ligne centrale, s'engageant dans les rayons juste le temps de récupérer un article.
 - Aller à la sortie : les préparateurs vont à la porte afin de scruter si leur client est garé et noter le numéro de la borne.
 - Livrer le client : une fois le client garé, il faut vite aller le servir pour qu'il puisse partir au plus vite, en ayant payé bien sûr !
 - Revenir au bercail : c'est bien beau tout ça, mais on va pas rester sur le parking ! Les préparateurs se dirigent ensuite vers la porte de l'entrepôt.
 - Retour en stand-by : là encore, on va pas juste regarder la porte, mais on va retourner à sa position initiale pour attendre la prochaine commande.

  L'avantage de définir autant de petits états est de pouvoir les coder séparément en des mouvements simples, ainsi que d'identifier rapidement là où se trouvent les erreurs.
  Pour le côté esthétique, on a pris le temps d'afficher quand ils se tournent, ainsi que de choisir inteligemment le sens dans lequel ils se tournent. La liste d'article est aussi triée pour que le parcours soit un peu plus court.



@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
true
0
Polygon -7500403 true true 120 0 136 21 156 39 165 60 168 74 194 87 216 97 237 115 250 141 250 165 240 225 150 300 135 300 75 300 75 0 120 0
Circle -16777216 true false 30 30 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 220 138 222 168 165 166 165 91 195 106 204 111 211 120
Circle -7500403 true true 47 195 58
Circle -7500403 true true 47 47 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

client
true
0
Polygon -7500403 true true 120 0 136 21 156 39 165 60 168 74 194 87 216 97 237 115 250 141 250 165 240 225 150 300 135 300 75 300 75 0 120 0
Circle -16777216 true false 30 30 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 220 138 222 168 165 166 165 91 195 106 204 111 211 120
Circle -7500403 true true 47 195 58
Circle -7500403 true true 47 47 58

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

preparateur
true
0
Circle -7500403 true true 210 240 60
Polygon -7500403 true true 210 240 105 255 15 225 0 240 0 255 75 270 0 285 0 300 15 315 105 285 210 300
Rectangle -7500403 true true 206 255 225 285
Polygon -7500403 true true 210 240 150 180 150 195 195 255
Circle -7500403 true true 0 30 30
Circle -7500403 true true 0 105 30
Polygon -7500403 true true 45 15 60 15 60 135 165 165 165 210 150 195 150 180 45 150 45 15
Line -7500403 true 60 30 150 15
Line -7500403 true 150 15 150 165
Line -7500403 true 60 45 150 30
Line -7500403 true 60 60 150 45
Line -7500403 true 60 75 150 60
Line -7500403 true 60 90 150 75
Line -7500403 true 60 105 150 90
Line -7500403 true 60 120 150 105
Line -7500403 true 60 135 150 120
Line -7500403 true 150 135 60 150
Line -7500403 true 135 165 135 15
Polygon -7500403 true true 150 150 120 150 90 150 150 165
Polygon -7500403 true true 60 15 150 0 150 15 60 30
Line -7500403 true 120 15 120 165
Line -7500403 true 105 15 105 150
Line -7500403 true 90 15 90 150
Line -7500403 true 75 30 75 150

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
