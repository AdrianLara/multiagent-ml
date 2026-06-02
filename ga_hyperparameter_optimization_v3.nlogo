extensions[py]
globals [results-table X_train_g X_test_g y_train_g y_test_g]


turtles-own [
  chromosome-depth
  chromosome-split
  chromosome-leaf
  fitness
  max-depth
  min-split
  min-leaf
  role
  generation
  group
]

to setup
  ca
  ask patches [set pcolor white]
  setup-turtles
end

to setup-turtles

  crt n-turtles [
    set fitness 0
    set xcor random-xcor
    set ycor random-ycor
    set max-depth 1 + random 8    ;; 1-8
    set min-split 10 + random 41        ;; 10-50
    set min-leaf 10 + random 21       ;; 10–30
    set role " "
    set generation 1
    set color 6
    set label generation
    set label-color 15
    set group 1
  ]
  let current-gen max [generation] of turtles
  train-test-split-data
  encode-depth
  encode-split
  encode-leaf
end

to python-session
  py:setup py:python
  (py:run
    "from sklearn import datasets, tree"
    "from sklearn.model_selection import train_test_split"
    "from sklearn.metrics import accuracy_score"
  )
end

to train-test-split-data
  (py:run
    "#iris = datasets.load_iris()"
    "iris = datasets.load_digits()"
    "X_train, X_test, y_train, y_test = train_test_split("
    "    iris.data.tolist(), iris.target.tolist(), train_size=0.3, random_state=42)"
  )
  set X_train_g py:runresult "X_train"
  set X_test_g  py:runresult "X_test"
  set y_train_g py:runresult "y_train"
  set y_test_g  py:runresult "y_test"
end

to train-classifiers
  ask turtles with [fitness = 0] [
    py:set "max_depth" max-depth
    py:set "min_samples_split" min-split
    py:set "min_samples_leaf" min-leaf
    py:set "X_train" X_train_g
    py:set "y_train" y_train_g

    (py:run
      "from sklearn.model_selection import cross_val_score"
      "clf = tree.DecisionTreeClassifier(max_depth=max_depth,"
      "    min_samples_split=min_samples_split, min_samples_leaf=min_samples_leaf)"
      "scores = cross_val_score(clf, X_train, y_train, cv=5)"
      "acc = scores.mean()"
    )
    set fitness py:runresult "round(acc, 5)"
  ]
  export-generation-results
  build-results-table
  print-results
end

to final-test-best
  let best max-one-of turtles [fitness]

  let best-depth [max-depth] of best
  let best-split [min-split] of best
  let best-leaf  [min-leaf] of best
  let best-role [role] of best
  let best-group [group] of best
  let best-generation [generation] of best



  py:set "best_depth" best-depth
  py:set "best_split" best-split
  py:set "best_leaf" best-leaf
  py:set "X_train_final" X_train_g
  py:set "y_train_final" y_train_g
  py:set "X_test_final" X_test_g
  py:set "y_test_final"y_test_g



  (py:run
    "clf_final = tree.DecisionTreeClassifier(max_depth=best_depth, min_samples_split=best_split, min_samples_leaf=best_leaf)"
    "clf_final.fit(X_train_final, y_train_final)"
    "y_pred_final = clf_final.predict(X_test_final)"
    "final_accuracy = accuracy_score(y_test_final, y_pred_final)"
    "print('depth real:', clf_final.get_depth())"
    "print('leaves real:', clf_final.get_n_leaves())"
    "print('params:', clf_final.get_params())"
    "print ('----------------------------')"
    "print(clf_final.tree_.node_count)"
    "print(clf_final.feature_importances_)"
    "print ('----------------------------')"
  )
  show (word "dept: " best-depth "| split: " best-split " |leaf: " best-leaf)
  show (word "Agente: " [who] of best)
  show ("n-turtles | parent-ratio|n-generations|depth|split|leaf|role|group|generation|final_accuracy")
  show (word n-turtles"|"  parent-ratio "|"n-generations "|"best-depth "|"best-split "|"best-leaf "|"best-role "|"best-group"|" best-generation "|" py:runresult "final_accuracy")


end

to next-generation

  let elite max-one-of turtles [fitness]
  let elite-depth [max-depth] of elite
  let elite-split [min-split] of elite
  let elite-leaf [min-leaf] of elite
  let elite-gen [generation] of elite
  let elite-group [group] of elite
  let elite-fitness [fitness] of elite

  reproduce
  apply-mutation
  kill-previous
  update-survivors-group
  train-classifiers
  ;export-generation-results

  ;; reintroducir elite si no sobrevivió
  if not any? turtles with [max-depth = elite-depth and min-split = elite-split and min-leaf = elite-leaf] [
    ask one-of turtles with [fitness <= elite-fitness][die]
    create-turtles 1 [
      set max-depth elite-depth
      set min-split elite-split
      set min-leaf elite-leaf
      set fitness 0
      set generation elite-gen
      set role "elite"
      set label generation
      set group elite-group
      set label-color 15
      set color 55
      setxy random-xcor random-ycor
    ]
    encode-depth
    encode-leaf
    encode-split
  ]
;  let current-group max [group] of turtles
;  ask turtles[
;    set group current-group + 1
;  ]
  plot-fitness
  plot-hyperparams
end

to reproduce
  let current-group max [group] of turtles
  let parents select-parents
  let parent-list sort parents
  let current-gen max [generation] of turtles
  let n length parent-list

  ;; actualizar generación de padres
  ask parents [
    ;set generation current-gen + 1
    set role "parent"
    set group current-group + 1
  ]

  ;; crear hijos
  let i 0
  while [i < n - 1] [
    let p1 item i parent-list
    let p2 item (i + 1) parent-list
    ;let p2 item ((i + 1) mod length parent-list) parent-list

   let children crossover p1 p2
    foreach children [
      child ->
      create-turtles 1 [
        set chromosome-depth item 0 child
        set chromosome-leaf item 1 child
        set chromosome-split item 2 child

        ;; decodificar a hiperparámetros
        let val-depth bin-to-dec chromosome-depth
        let val-leaf bin-to-dec chromosome-leaf
        let val-split bin-to-dec chromosome-split

        ;evitar valores incorrectos en hiperparametros
        ifelse val-depth = 0[
          set max-depth 1
          set chromosome-depth [0 0 1]
        ][
          set max-depth val-depth
        ]
        ifelse val-leaf = 0[
          set min-leaf 1
          set chromosome-leaf [0 0 0 0 1]
        ][
          set min-leaf val-leaf
        ]
        ifelse val-split < 2[
          set min-split 2
          set chromosome-split [0 0 0 0 1 0]
        ][
          set min-split val-split
        ]

        set fitness 0
        set generation current-gen + 1
        set role "child"
        set label generation
        set label-color 15
        set color 15 + random 50
        setxy random-xcor random-ycor
        set group current-group + 1
      ]
    ]
    set i i + 2
  ]
end

to update-survivors-group
  let current-group max [group] of turtles
  ask turtles with [group < current-group] [
    set group current-group
    set role "survivor"
  ]
end

;to kill-previous
;  let current-group max [group] of turtles
;  let prev turtles with [group = current-group]
;  show word "lista a eliminar" prev
;
;  if current-group = 1 [
;    set prev turtles with [group = 1]
;  ]
;
;  if any? prev [
;    let n-kill floor (count prev * parent-ratio)
;    show word "mataremos" n-
;    ask n-of n-kill prev [ die ]
;  ]
;end

to kill-previous
  let current-group max [group] of turtles
  let current-turtles turtles with [fitness != 0]

  if any? current-turtles [
    let n-kill floor (n-turtles * parent-ratio)
    ask n-of n-kill current-turtles [
      die
    ]
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;CRUCE;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to-report select-parents
  let sorted sort-by [[a b] -> [fitness] of a > [fitness] of b] turtles
  ;let n-parents floor (count turtles / 2)
  let n-selected floor (count turtles * parent-ratio)

  ;; seguridad mínima
  if n-selected < 2 [ set n-selected 2 ]

  report turtle-set sublist sorted 0 n-selected
end

to-report crossover [parent1 parent2]
  ;; leaf
  let c1-leaf [chromosome-leaf] of parent1
  let c2-leaf [chromosome-leaf] of parent2
  let cut-leaf 1 + random (length c1-leaf - 1)

  let child1-leaf sentence (sublist c1-leaf 0 cut-leaf) (sublist c2-leaf cut-leaf length c2-leaf)
  let child2-leaf sentence (sublist c2-leaf 0 cut-leaf) (sublist c1-leaf cut-leaf length c1-leaf)

  ;; split
  let c1-split [chromosome-split] of parent1
  let c2-split [chromosome-split] of parent2
  let cut-split 1 + random (length c1-split - 1)

  let child1-split sentence (sublist c1-split 0 cut-split) (sublist c2-split cut-split length c2-split)
  let child2-split sentence (sublist c2-split 0 cut-split) (sublist c1-split cut-split length c1-split)

  ;; depth
  let c1-depth [chromosome-depth] of parent1
  let c2-depth [chromosome-depth] of parent2
  let cut-depth 1 + random (length c1-depth - 1)

  let child1-depth sentence (sublist c1-depth 0 cut-depth)
                               (sublist c2-depth cut-depth length c2-depth)

  let child2-depth sentence (sublist c2-depth 0 cut-depth)
                               (sublist c1-depth cut-depth length c1-depth)

  ;; mutación
  ;set child1-leaf mutate child1-leaf
  ;set child2-leaf mutate child2-leaf
  ;set child1-split mutate child1-split
  ;set child2-split mutate child2-split

  report (list
    (list child1-depth child1-leaf child1-split )
    (list child2-depth child2-leaf child2-split )
  )
end

to apply-mutation
  ask turtles with [generation >= 2] [

    let old-depth chromosome-depth
    let old-leaf chromosome-leaf
    let old-split chromosome-split

    set chromosome-depth mutate chromosome-depth
    set chromosome-leaf mutate chromosome-leaf
    set chromosome-split mutate chromosome-split


    ;; si hubo cambios
    if chromosome-leaf != old-leaf or
       chromosome-split != old-split or
       chromosome-depth != old-depth [
;      show (word "MUTACION turtle " who)
;      show (word "depth: " old-depth " -> " chromosome-depth)
;      show (word "leaf: " old-leaf " -> " chromosome-leaf)
;      show (word "split: " old-split " -> " chromosome-split)
      ;; decodificar
      set max-depth bin-to-dec chromosome-depth
      set min-leaf bin-to-dec chromosome-leaf
      set min-split bin-to-dec chromosome-split

      validate-hyperparams

;      show (word "nuevos hiperparametros: depth=" max-depth
;                 " leaf=" min-leaf
;                 " split=" min-split)

      ;; obligar reentrenamiento
      set fitness 0
    ]
  ]
  train-classifiers
end

to-report mutate [bits]
  ;; mutación normal
  let mutated map [b ->
    ifelse-value (random-float 1 < p-mutation)
      [1 - b]
      [b]
  ] bits
  let val bin-to-dec mutated

  if val < 2 [
    let idx random length mutated
    set mutated replace-item idx mutated 1
  ]
  report mutated
end

to validate-hyperparams
  if max-depth = 0 [
    set max-depth 1
    set chromosome-depth [0 0 1]
  ]

  if min-leaf = 0 [
    set min-leaf 1
    set chromosome-leaf [0 0 0 0 1]
  ]

  if min-split < 2 [
    set min-split 2
    set chromosome-split [0 0 0 0 1 0]
  ]
end



;;;;;;;;;;;;;;;;;;;;;; decimal - to binary;;;;;;;;;;;;;;;;;;;;
to encode-depth
  ask turtles [
    let val max-depth   ;; normalizar 1–8 → 0–7
    let bits []
    repeat 3 [
      set bits fput (val mod 2) bits
      set val floor (val / 2)
    ]
    set chromosome-depth bits
  ]
end

to encode-leaf
  ask turtles [
    let val min-leaf
    let bits []

    repeat 5 [
      set bits fput (val mod 2) bits
      set val floor (val / 2)
    ]

    set chromosome-leaf bits
  ]
end

to encode-split
  ask turtles [
    let val min-split
    let bits []

    repeat 6 [
      set bits fput (val mod 2) bits
      set val floor (val / 2)
    ]

    set chromosome-split bits
  ]
end

;;;;;;;;;;;;;;;;;;;;;; binary - decimal;;;;;;;;;;;;;;;;;;;;

to-report bin-to-dec [bits]
  let value 0
  foreach bits [
    b ->
    set value (value * 2) + b
  ]
  report value
end

to decode-depth
  ask turtles [
    set max-depth bin-to-dec chromosome-depth
  ]
end

to decode-leaf
  ask turtles [
    let val bin-to-dec chromosome-leaf
    set min-leaf val
  ]
end

to decode-split
  ask turtles [
    let val bin-to-dec chromosome-split
    set min-split 10 + val
  ]
end

;;;;;;;;;;;;;;;;;;SHOW RESULTS LIST;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to build-results-table
  set results-table []

  ask turtles [
    set results-table lput
      (list who group max-depth min-split min-leaf role generation fitness )
      results-table
  ]
end

to print-results
  let current-turtles turtles with [fitness > 0]

  if any? current-turtles [
    let avg-fitness precision (mean [fitness] of current-turtles) 4
    let best-fitness precision (max [fitness] of current-turtles) 4
    ;let avg-split precision (mean [min-split] of current-turtles) 4
    ;let avg-leaf precision (mean [min-leaf] of current-turtles) 4

    clear-output
    sort-results
    output-print " id | group | depth | spl | lf |  role  | gen | fitness |"

    foreach results-table [ row ->
      output-print (word
        item 0 row " | "
        item 1 row " | "
        item 2 row " | "
        item 3 row " | "
        item 4 row " | "
        item 5 row " | "
        item 6 row " | "
        item 7 row " | "
        ;avg-fitness " | "
        ;;best-fitness " | "
      )
    ]
  ]
end
to sort-results
  set results-table sort-by [[a b] -> item 0 a < item 0 b] results-table
end


;;;;;;;;;;;;;;;;;;;;;;;Graphics;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to plot-fitness
  let current-gen max [generation] of turtles
  let current-turtles turtles with [fitness > 0]

  let avg-fitness mean [fitness] of current-turtles
  let best-fitness max [fitness] of current-turtles

  set-current-plot "Fitness by Generation"

  set-current-plot-pen "avg-fitness"
  plotxy current-gen avg-fitness

  set-current-plot-pen "best-fitness"
  plotxy current-gen best-fitness
end

to plot-hyperparams
  let current-gen max [generation] of turtles
  let current-turtles turtles with [generation = current-gen]

  let avg-depth mean [max-depth] of current-turtles
  let avg-split mean [min-split] of current-turtles
  let avg-leaf mean [min-leaf] of current-turtles

  set-current-plot "Hyperparameters Evolution"

  set-current-plot-pen "avg max-depth"
  plotxy current-gen avg-depth

  set-current-plot-pen "avg min-split"
  plotxy current-gen avg-split

  set-current-plot-pen "avg min-leaf"
  plotxy current-gen avg-leaf
end
to-report best-turtle-info
  let best max-one-of turtles [fitness]
  report (word "id: " [who] of best
               " | leaf: " [min-leaf] of best
               " | split: " [min-split] of best
               " | fitness: " [fitness] of best)
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Export RESULTS;;;;;;;;;;;;;;;;;;;;
to export-generation-results
  if not file-exists? "ga_results.csv" [
    file-open "ga_results.csv"
    ;file-print "max_depth,min_split,min_leaf,role,generation,fitness"
    file-close
  ]
  file-open "ga_results.csv"

  ask turtles [
    file-print (word
      group ","
      generation ","
      n-turtles ","
      parent-ratio ","
      n-generations ","
      p-mutation ","
      max-depth ","
      min-split ","
      min-leaf ","
      role ","
      fitness)
  ]
  file-close
end
to run-experiment
  train-classifiers
  export-generation-results
  repeat n-generations - 1 [
    next-generation
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
253
1
647
208
-1
-1
11.7
1
10
1
1
1
0
1
1
1
-16
16
-8
8
0
0
1
ticks
30.0

SLIDER
13
50
235
83
n-turtles
n-turtles
0
100
10.0
1
1
NIL
HORIZONTAL

BUTTON
12
215
234
248
SETUP
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
11
10
237
43
Load Python-Session
python-session
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
12
254
235
287
TRAIN
train-classifiers
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

OUTPUT
666
10
1089
542
9

BUTTON
12
294
235
327
CREATE NEXT GENERATION
repeat n-generations - 1 [next-generation]\nfinal-test-best\n;next-generation
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
254
219
648
379
Fitness by Generation
Generations
Fitness
0.0
20.0
0.0
1.0
true
true
"" ""
PENS
"avg-fitness" 1.0 0 -13840069 true "" ""
"best-fitness" 1.0 0 -14070903 true "" ""

PLOT
254
389
649
544
Hyperparameters Evolution
NIL
NIL
0.0
10.0
10.0
40.0
true
true
"" ""
PENS
"avg min-split" 1.0 0 -5825686 true "" ""
"avg min-leaf" 1.0 0 -13628663 true "" ""
"avg max-depth" 1.0 0 -7500403 true "" ""

SLIDER
13
89
233
122
parent-ratio
parent-ratio
0.2
0.8
0.2
0.1
1
NIL
HORIZONTAL

SLIDER
14
130
234
163
n-generations
n-generations
0
20
2.0
1
1
NIL
HORIZONTAL

MONITOR
125
394
237
439
Best Fitness
max [fitness] of turtles
17
1
11

MONITOR
14
337
237
382
NIL
best-turtle-info
17
1
11

MONITOR
16
394
121
439
Poblacion
count turtles
17
1
11

SLIDER
14
171
234
204
p-mutation
p-mutation
0.001
1
0.084
0.001
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

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
NetLogo 6.2.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="test" repetitions="1" runMetricsEveryStep="true">
    <setup>python-session
setup</setup>
    <go>run-experiment</go>
    <exitCondition>true</exitCondition>
    <enumeratedValueSet variable="n-turtles">
      <value value="11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-generations">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="parent-ratio">
      <value value="0.6"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
