extensions [py]
globals [data-test output-test results-table]
turtles-own [
  speed
  angle-direction
  data-train
  output
  history
  accuracy-tr
  accuracy-ts
]

to setup
  ca
  function-xy
  crt n[
    let p one-of patches with [pcolor != white]
    move-to p

    set size 1
    set shape "person"
    set color 95
    set data-train []
    set output []
    set history (patch-set patch-here)
    set speed 0.1 + random-float 1
    set angle-direction random-float 1
    pd
  ]
  ask one-of turtles [pd]

  ;;ask turtle 0 [set pen-mode "down"]
  reset-ticks
end

to go
  move
  save-data
  if all? turtles [length data-train >= n-data] [
    stop
  ]
  tick
end

to function-xy
  ask patches [
    ;; diagonal
    ifelse (pxcor + pycor) >= 0
      [ set pcolor 131 ]
      [ set pcolor 6 ]

    ;; introducir patches negros aleatorios
    if random-float 1 < 0.1 [
      set pcolor white
    ]
  ]
end

to save-data
  ask turtles[
    let pos (list int pxcor int pycor)

    if not member? pos data-train [
      set data-train fput pos data-train
    ]

    ;; limitar tamaño a n (mantiene los más recientes)
    if length data-train > n-data [
      set data-train sublist data-train 0 n-data
    ]

    set history (patch-set history patch-here)
  ]
end

to set-output-train
  ask turtles[
    foreach data-train[
      coords -> set output lput (sum coords) (output)
    ]
    set output map [i -> ifelse-value(i >= 0)[1][0]] output
  ]
end

to set-data-ouput-test
  set data-test []
  set output-test []
  let target-size floor (0.2 * n-data)
  let selected-patches n-of target-size patches with [pcolor = white]

   ask selected-patches [
    set data-test lput (list pxcor pycor) data-test
  ]

  foreach data-test [
    coords -> set output-test lput (sum coords) output-test
  ]
  set output-test map [i -> ifelse-value(i >= 0)[1][0]] output-test
end

to-report stop-condition
  let aux-list [length data-train] of turtles
  report mean aux-list
  ;;show mean aux-list
end

to move
  ask turtles [
    let intentos 0
    let target patch-ahead speed

    ;; buscar dirección válida
    while [ (target = nobody or [pcolor] of target = white) and intentos < 10 ] [
      rt  46
      set target patch-ahead speed
      set intentos intentos + 1
    ]

    ;; solo avanza si encontró un patch válido
    if target != nobody and [pcolor] of target != black [
      fd speed
    ]
  ]
end

;;Python Process

to setup-py
  py:setup py:python
  (py:run
    "from sklearn import tree"
    "from sklearn.ensemble import RandomForestClassifier"
    "from sklearn.neighbors import KNeighborsClassifier"
    "import time"
    "from sklearn import metrics"
    "import numpy as np"
  )
end

;;create classsifiers
to train
  set-output-train
  py:set "n" n
  (py:run
    "clfs = np.zeros(n)"
    "clfs = clfs.tolist()"
  )
  ask turtles[
    py:set "X" data-train
    py:set "y" output
    py:set "pos" who
    (py:run
      "#clf =  tree.DecisionTreeClassifier(max_depth=2, min_samples_split=4, min_samples_leaf=5)"
      "clf = RandomForestClassifier( max_depth=2,min_samples_split=4, min_samples_leaf=5)"
      "#clf = KNeighborsClassifier(weights='uniform', metric='euclidean')"
      "clf = clf.fit(X, y)"
      "clfs[pos] = clf"
    )
  ]
end

to calculate-accuracy
  ;function-xy
; calculate accuracy depends on turtle classfiers

  set-data-ouput-test
  ask turtles[
    py:set "pos" who
    ;py:set "accuracy" accuracy
    py:set "X_test" data-test
    py:set "y_test" output-test
    py:set "X_train" data-train
    py:set "y_train" output
    (py:run
      "y_pred = clfs[pos].predict(X_test)"
      "accuracy_ts = metrics.accuracy_score(y_test, y_pred)"
      "y_pred_train = clfs[pos].predict(X_train)"
      "accuracy_tr = metrics.accuracy_score(y_train, y_pred_train)"

    )
    set accuracy-tr (py:runresult "round(accuracy_tr, 4)")
    set accuracy-ts (py:runresult "round(accuracy_ts, 4)")
    set label-color red
    set label accuracy-ts
  ]
  build-results-table
  print-results
end

to set-test
  ask turtle observe-turtle[
    setxy max-pxcor min-pxcor
    set heading 0
    set shape "car"
  ]
end
to predict
  let aux 0
  let res 0
  ask turtle observe-turtle[
    py:set "pos" who
    fd 1
    set aux ycor
    py:set "x" pxcor
    py:set "y" pycor
    set res py:runresult "clfs[pos].predict([[x,y]])"
    show res
    if-else item 0 res = 1 [set pcolor 131][set pcolor yellow]

    ;show py:runresult "pos"

  ]
  if aux >= max-pxcor [stop]
  tick
end



to build-results-table
  set results-table []

  ask turtles [
    set results-table lput
      (list who accuracy-tr accuracy-ts )
      results-table
  ]
end

to print-results
  clear-output
  sort-results
  output-print "id | acc-train | acc-test "

  foreach results-table [ row ->
    output-print (word item 0 row " | " item 1 row " | " item 2 row  )
  ]
end
to sort-results
  set results-table sort-by [[a b] -> item 0 a < item 0 b] results-table
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;Export RESULTS;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to export-turtle-results
  file-open "results_turtles_ndata_rfc.csv"

  ;file-print "id,acc-train,acc-test"

  ask turtles [
    file-print (word n-data "," accuracy-tr "," accuracy-ts)
  ]

  file-close
end
@#$#@#$#@
GRAPHICS-WINDOW
327
15
905
594
-1
-1
10.0
1
10
1
1
1
0
0
0
1
-28
28
-28
28
1
1
1
ticks
30.0

BUTTON
14
132
160
165
SETUP
setup\n
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
166
133
302
166
GO
go
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
166
89
301
122
n-data
n-data
5
500
38.0
1
1
objects
HORIZONTAL

BUTTON
14
174
160
207
TRAIN-CLASSIFIERS
train
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
1176
351
1311
384
NIL
predict\n
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
17
89
161
122
n
n
5
15
15.0
1
1
turtles
HORIZONTAL

BUTTON
166
174
302
207
EVALUATE
calculate-accuracy
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
1176
310
1311
343
NIL
set-test
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
16
43
302
76
PYTHON-SESSION
setup-py
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
1175
248
1311
308
observe-turtle
2.0
1
0
Number

OUTPUT
19
257
293
473
10

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
  <experiment name="experiment-ndata" repetitions="30" runMetricsEveryStep="false">
    <setup>setup
setup-py</setup>
    <go>go</go>
    <final>train
calculate-accuracy
export-turtle-results</final>
    <enumeratedValueSet variable="n-data">
      <value value="5"/>
      <value value="30"/>
      <value value="70"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-ndata-rfc" repetitions="30" runMetricsEveryStep="false">
    <setup>setup
setup-py</setup>
    <go>go</go>
    <final>train
calculate-accuracy
export-turtle-results</final>
    <enumeratedValueSet variable="n-data">
      <value value="5"/>
      <value value="30"/>
      <value value="70"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-ndata-rfc" repetitions="30" runMetricsEveryStep="false">
    <setup>setup
setup-py</setup>
    <go>go</go>
    <final>train
calculate-accuracy
export-turtle-results</final>
    <enumeratedValueSet variable="n-data">
      <value value="5"/>
      <value value="30"/>
      <value value="70"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-ndata-rf" repetitions="30" runMetricsEveryStep="false">
    <setup>setup
setup-py</setup>
    <go>go</go>
    <final>train
calculate-accuracy
export-turtle-results</final>
    <enumeratedValueSet variable="n-data">
      <value value="5"/>
      <value value="30"/>
      <value value="70"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n">
      <value value="10"/>
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
