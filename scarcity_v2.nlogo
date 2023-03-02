extensions [table csv]

patches-own [resources]
turtles-own [


  labour age utility predationRes predationGoods protection production dict stratsum transfer technology experience resources-agent wealth goods calendar attackz risk-taking strategy-list strategy-utility-dict strategy-counter-dict strategy-success-dict current-strategy-success max-age]

globals [alpha beta lambda csv-list condition first-resource-shock first-resource-shock-end second-resource-shock second-resource-shock-end third-resource-shock third-resource-shock-end]


to setup

  clear-all

  ;random-seed 5

  ;resize-world 0 environment-size 0 environment-size

  ;; The below are factors used for the production equation
  set alpha random-normal 0.03 0.005
  set beta random-normal 0.03 0.005
  set lambda random-normal 0.03 0.005

  ;; The below are times when the resource shocks are inflicted on the environment, and when they end

  ;let t random-normal 2500 500
  set first-resource-shock 2500
  ;was round random-normal 2500 500
  set first-resource-shock-end first-resource-shock + 1000
  ; was first-resource-shock + round random-normal resource-shock-duration 100

  ;let j random-normal 5000 500
  set second-resource-shock 5000
  set second-resource-shock-end second-resource-shock + 1000

  ;let r random-normal 7500 500
  set third-resource-shock 7500
  set third-resource-shock-end third-resource-shock + 1000


  set csv-list []

  ifelse model-version = "scarcity" [set condition "scarcity"][set condition "control"]

  ;; create agends based on a slider (slider allows you to pick how many agents)
  ;crt num-agents [
    ;setxy random-xcor random-ycor

    ;set color white
    ;set shape "person"

  ;]

  ask patches [
    sprout 1 ]


  ask turtles [
    create-links-with turtles-on neighbors4
  ]
;    if any? other turtles in-radius num-connections [
;      repeat num-connections [ create-link-with one-of other turtles in-radius connections-radius ]]

  ask turtles [


    ;; Turtles owning stuff
    set age 0
    ;; set risk-tolerance
    set utility 0
    set labour effort-per-tick
    set predationRes 0
    set predationGoods 0
    set production 0
    set risk-taking random-normal 12 3
    set protection 0
    set max-age random-normal 2500 500
    ;; This has to be changed according to risk sensing or whatever
    set transfer 0
    set technology 1
    set experience 0
    set goods 0
    set attackz 0
    set resources-agent 0
    ; Attackz is a variable used to measure how many times the
    ; turtles have been attacked recently.
    set wealth 1
    ;; Yeah so I dunno abt wealth - they don;t really specify it in the paper.
    ;; So I'll just leave it at 1 I guess?


    ; Everything strategy

    set current-strategy-success 0

    ;; First we make a list with 3 bits, where each bit either activates or doesnt active
    ;; A particular gene - predation of goods, predation of resources or production

    set strategy-list (list random 2 random 2 random 2)

    ;; Then we make a strategy-utility-dictionary
    ;; This thing allows us to record how much utility an agent has produced with his current
    ;; strategy, giving us the possibility to see what is the best strategy so far for the agent
    set strategy-utility-dict table:make
    table:put strategy-utility-dict strategy-list 0


    ; Then we make a strategy-counter
    ; This will allow us to calculate the best strategy - as it will be calculated via
    ; Best strategy = total utility generated / how many ticks the strategy has been in use

    set strategy-counter-dict table:make
    table:put strategy-counter-dict strategy-list 0


    ; And then we combine the two above to calculate the current success of the strategy
    ; In a new dictionary

    set strategy-success-dict table:make
    table:put strategy-success-dict strategy-list 0

    set calendar table:make
    table:put calendar age 0
  ]



  ;; Let's give patches resources.
  ask patches [
    set resources resources-per-patch
    set pcolor green
    ;;Uniform accross all patches - that's how they do it in the paper right?
  ]

  reset-ticks

end


to go

  ;; So, as per paper, they first check their age and if they're too old they
  ;; die.
  ask turtles [
   reset-stats
   ;death
    set protection calculate-protection
    ;; after an agent has decided how much effort to put into protection,
    ;; we subtract that amount from their total labor this tick
    set labour labour - protection



   effort-allocation
   produce
   set resources-agent 0
   gather-resources
   interact-with-neighbor
   ;set experience experience + 0.001
   set age age + 1
   table:put calendar age 0
   set utility utility + goods
   increment-utility
   increment-counter
   calculate-strategy-success
   strategy-change
   best-strategy-adaptation
  ]
  tick
  resource-shock
  ; Enable below functions to produce CSV files for different simulation runs.
  ;prep-csv
  ;write-csv
end


;This is kinda done.
to interact-with-neighbor
  ; Select a random neighbour and interact with it
  let neighbor one-of link-neighbors
  if neighbor != nobody [

    ; First checks if the predation of resources "gene" is active
    ; If so - proceeds to predates resources
    if predationRes != 0 [
      ; Below is the conflict function from the paper (Eq. 3)
      let transferino (predationRes / (predationRes + ([protection] of neighbor + predationRes)))
      set transfer transferino
      ; The outcome of the conflict is added to the resources
      set resources-agent resources-agent + transfer
      ask neighbor [
        ; The outcome of the conflict is substracted from neighbours resources
        set resources-agent resources-agent - transfer
        ; Make a note in his calendar that he was attacked
        table:put calendar age 1

            ]
        ]

    ; The below is the same but for Goods instead of Resources.
    if predationGoods != 0 [
      let transferino (predationGoods / (predationGoods + ([protection] of neighbor + predationGoods)))
      set transfer transferino
      set goods goods + transfer
      ask neighbor [
        set goods goods - transfer
        table:put calendar age 1
      ]
    ]

    ;; Lastly we give an opportunity to change the strategy list according to neighbors current strategy success.
    if current-strategy-success > [current-strategy-success] of neighbor [
        let i random 100
        let j strategy-list
      if i < 0.4 [
      ask neighbor [
        set strategy-list j
        if table:has-key? strategy-utility-dict strategy-list = FALSE [table:put strategy-utility-dict strategy-list 0]
        if table:has-key? strategy-counter-dict strategy-list = FALSE [table:put strategy-counter-dict strategy-list 0]
        if table:has-key? strategy-success-dict strategy-list = FALSE [table:put strategy-success-dict strategy-list 0]]
      ]
    ]
  ]
end

; This numbers of this needs to be checked. Like whether the resulting numbers are too low
; Or too high.
to produce
  ; Checks if production "gene" is active"
  if item 2 strategy-list = 1 [
    ; Below is Cobb-Douglas production function from the paper (Eq. 2)
  set goods production ^ alpha * (technology * (1 + experience) * sqrt wealth) ^ beta * ((1 + resources-agent) ^ lambda)
  set experience experience + production / 10000
  ]

end




; Every tick, the agents gather resources of the patch they are standing on
to gather-resources
  if resources > 0 [
    set resources-agent resources
  ]
end



to death
  if age = max-age [

    let i strategy-list

    hatch number-of-offspring [

    if any? other turtles in-radius 10 [
      repeat 10 [ create-link-with one-of other turtles in-radius 10 ]

    set age 0
    set utility 0
    set labour 100
    set predationRes 0
    set predationGoods 0
    set production 0
    set risk-taking random-normal 12 3
    set protection 0
    set max-age random-normal 2500 500
    set transfer 0
    set technology 1
    set experience 0
    set goods 0
    set attackz 0
    set wealth 1

    set strategy-list i

    set current-strategy-success 0

    set strategy-utility-dict table:make
    table:put strategy-utility-dict strategy-list 0

    set strategy-counter-dict table:make
    table:put strategy-counter-dict strategy-list 0

    set strategy-success-dict table:make
    table:put strategy-success-dict strategy-list 0


    set calendar table:make
    table:put calendar age 0


    ]
    ]

    die ]
end

; A function that allocates labour (which is can be thought of as 8 hours per day, here - 100 units)
; Labour is distributed equally to genes that are active - predation of resouces, goods or production
; Before this distribution, part of labour is firstly allocated to protection (see above)
to effort-allocation
  ;code here

  if sum strategy-list = 0 [
    if item 0 strategy-list = 1 [set predationRes labour / 1]
    if item 1 strategy-list = 1 [set predationGoods labour / 1]
    if item 2 strategy-list = 1 [set production labour / 1]
  ]

  if sum strategy-list = 1 [
    if item 0 strategy-list = 1 [set predationRes labour / 1]
    if item 1 strategy-list = 1 [set predationGoods labour / 1]
    if item 2 strategy-list = 1 [set production labour / 1]
  ]

  if sum strategy-list = 2 [
    if item 0 strategy-list = 1 [set predationRes labour / 2]
    if item 1 strategy-list = 1 [set predationGoods labour / 2]
    if item 2 strategy-list = 1 [set production labour / 2]
  ]

  if sum strategy-list = 3 [
    if item 0 strategy-list = 1 [set predationRes labour / 3]
    if item 1 strategy-list = 1 [set predationGoods labour / 3]
    if item 2 strategy-list = 1 [set production labour / 3]
  ]

end

; At the end of each tick, some turtle parameters are reset.
to reset-stats
   set goods 0
   set predationRes 0
   set predationGoods 0
   set production 0
   set protection 0
   set labour effort-per-tick
   set transfer 0
   set attackz 0
end

; Function for protection allocation based on danger (as measured by
; how many times the turtle has been attacked in the last 10 iterations)
; and risk-taking level which is assigned at birth (mean 12 + sd 3).

to protection-allocation2


end


to-report calculate-protection

  ;; The reason we brach based on ticks is that turtles should not learn from the first 10 ticks because otherwise we get too
  ;; strong learning effects from just one or a few experiences.

  ifelse ticks <= 10 [
    report risk-taking
  ]
  [
    let agez age
    repeat 10 [
        set agez agez - 1
        set attackz attackz + table:get calendar agez
      ]
    if attackz != 0 [
        report risk-taking * sqrt attackz
    ]
    if attackz = 0 [
        report risk-taking * 1
    ]
  ]

end

to best-strategy-adaptation

  let j random 100

  if j <= 0.4 [

  let i max table:values strategy-success-dict

  foreach (table:keys strategy-success-dict) [ x -> if table:get strategy-success-dict x = i [ set strategy-list x ]
    ]
  ]

end

to strategy-change

  let j random 100

  if j <= 0.4 [

    set strategy-list (list random 2 random 2 random 2)
    if table:has-key? strategy-utility-dict strategy-list = FALSE [table:put strategy-utility-dict strategy-list 0]
    if table:has-key? strategy-counter-dict strategy-list = FALSE [table:put strategy-counter-dict strategy-list 0]
    if table:has-key? strategy-success-dict strategy-list = FALSE [table:put strategy-success-dict strategy-list 0]

  ]

end

to increment-utility

  let i table:get strategy-utility-dict strategy-list
  table:put strategy-utility-dict strategy-list i + goods

end

to increment-counter
  let i table:get strategy-counter-dict strategy-list
  table:put strategy-counter-dict strategy-list i + 1

end

to calculate-strategy-success

  let i table:get strategy-utility-dict strategy-list
  let j table:get strategy-counter-dict strategy-list
  table:put strategy-success-dict strategy-list i / j
  set current-strategy-success table:get strategy-success-dict strategy-list


end

; procedure to write some turtle properties to a file
;to write-turtles-to-csv
  ; we use the `of` primitive to make a list of lists and then
  ; use the csv extension to write that list of lists to a file.
  ;csv:to-file "turtles.csv" [ (list xcor ycor size color heading) ] of turtles
;end


; So we have a list of lists that we convert to a CSV file. I guess what we need is a list of lists?
; So I guess the list stack to make columns.
; Then I need a list of 1) number of ticks and 2) sum [protection] of turtles 3) sum

to prep-csv
  if ticks >= 1500 [
    let i (list ticks sum [protection] of turtles sum [predationRes] of turtles sum [predationGoods] of turtles sum [production] of turtles condition)
    set csv-list lput i csv-list
  ]
end

to resource-shock

  if model-version = "scarcity" [

    if ticks = first-resource-shock [

      if shock-type = "line" [

        ask patches with [ pycor < min-pycor + shock-row-number ] [
          set resources resource-shock-intensity
          set pcolor brown ]

      if shock-type = "random" [

          ask n-of resource-shock-area patches [
            set resources resource-shock-intensity
            set pcolor brown
          ]

    ]]]

  if ticks = first-resource-shock-end [

    ask patches [
        set resources 100
        set pcolor green
      ]

  ]

  if ticks = second-resource-shock [

      if shock-type = "line" [

        ask patches with [ pycor < min-pycor + shock-row-number ] [
          set resources resource-shock-intensity
          set pcolor brown ]]

      if shock-type = "random" [

          ask n-of resource-shock-area patches [
            set resources resource-shock-intensity
            set pcolor brown
      ]]


  ]

  if ticks = second-resource-shock-end [

    ask patches [
      set resources 100
      set pcolor green
      ]

  ]

  if ticks = third-resource-shock [

      if shock-type = "line" [

        ask patches with [ pycor < min-pycor + shock-row-number ] [
          set resources resource-shock-intensity
          set pcolor brown ]
          ]

      if shock-type = "random" [

          ask n-of resource-shock-area patches [
            set resources resource-shock-intensity
            set pcolor brown
          ]
    ]
  ]

  if ticks = third-resource-shock-end [
    ask patches [
      set resources 100
      set pcolor green
    ]
  ]
  ]

end

to write-csv

  if ticks = 10000 [

    csv:to-file "export_control_test.csv" csv-list

  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
268
19
592
344
-1
-1
19.8
1
10
1
1
1
0
0
0
1
0
15
0
15
0
0
1
ticks
30.0

BUTTON
199
19
265
52
NIL
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

SLIDER
0
109
173
142
num-agents
num-agents
0
100
22.0
1
1
NIL
HORIZONTAL

BUTTON
200
76
264
110
go
go
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
686
63
1118
347
Effort allocation plot
Time (ticks)
Effort allocated
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"prot" 1.0 0 -13840069 true "" "plot sum [protection] of turtles"
"predRes" 1.0 0 -5298144 true "" "plot sum [predationRes] of turtles"
"predGoods" 1.0 0 -955883 true "" "plot sum [predationGoods] of turtles"
"produce" 1.0 0 -13791810 true "" "plot sum [production] of turtles"

BUTTON
200
113
263
146
NIL
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
0
151
172
184
num-connections
num-connections
0
100
6.0
1
1
NIL
HORIZONTAL

SLIDER
0
194
175
227
connections-radius
connections-radius
0
20
1.0
1
1
NIL
HORIZONTAL

SLIDER
0
237
185
270
resources-per-patch
resources-per-patch
0
1000
100.0
50
1
NIL
HORIZONTAL

SLIDER
0
283
172
316
effort-per-tick
effort-per-tick
0
1000
100.0
10
1
NIL
HORIZONTAL

SLIDER
0
329
172
362
environment-size
environment-size
0
100
15.0
1
1
NIL
HORIZONTAL

SLIDER
0
374
178
407
number-of-offspring
number-of-offspring
0
20
1.0
1
1
NIL
HORIZONTAL

CHOOSER
0
20
138
65
model-version
model-version
"normal" "scarcity"
1

SLIDER
318
408
596
441
resource-shock-intensity
resource-shock-intensity
0
100
50.0
1
1
resources
HORIZONTAL

SLIDER
336
454
582
487
resource-shock-area
resource-shock-area
0
275
2.0
5
1
patches
HORIZONTAL

SLIDER
346
501
566
534
resource-shock-duration
resource-shock-duration
0
5000
1000.0
100
1
NIL
HORIZONTAL

CHOOSER
384
352
522
397
shock-type
shock-type
"random" "line"
1

SLIDER
602
453
774
486
shock-row-number
shock-row-number
0
15
2.0
1
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
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="base-1" repetitions="4" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>mean [protection] of turtles</metric>
    <metric>mean [predationRes] of turtles</metric>
    <metric>mean [predationGoods] of turtles</metric>
    <metric>mean [production] of turtles</metric>
    <metric>standard-deviation [protection] of turtles</metric>
    <metric>standard-deviation [predationRes] of turtles</metric>
    <metric>standard-deviation [predationGoods] of turtles</metric>
    <metric>standard-deviation [production] of turtles</metric>
    <enumeratedValueSet variable="model-version">
      <value value="&quot;scarcity&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="base-2-random-patch" repetitions="10" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="7000"/>
    <metric>mean [protection] of turtles</metric>
    <metric>mean [predationRes] of turtles</metric>
    <metric>mean [predationGoods] of turtles</metric>
    <metric>mean [production] of turtles</metric>
    <metric>standard-deviation [protection] of turtles</metric>
    <metric>standard-deviation [predationRes] of turtles</metric>
    <metric>standard-deviation [predationGoods] of turtles</metric>
    <metric>standard-deviation [production] of turtles</metric>
    <enumeratedValueSet variable="resource-shock-area">
      <value value="15"/>
      <value value="30"/>
      <value value="45"/>
      <value value="60"/>
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="model-version">
      <value value="&quot;scarcity&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shock-type">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="base-2-line-patch" repetitions="10" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="7000"/>
    <metric>mean [protection] of turtles</metric>
    <metric>mean [predationRes] of turtles</metric>
    <metric>mean [predationGoods] of turtles</metric>
    <metric>mean [production] of turtles</metric>
    <metric>standard-deviation [protection] of turtles</metric>
    <metric>standard-deviation [predationRes] of turtles</metric>
    <metric>standard-deviation [predationGoods] of turtles</metric>
    <metric>standard-deviation [production] of turtles</metric>
    <enumeratedValueSet variable="shock-row-number">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="model-version">
      <value value="&quot;scarcity&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shock-type">
      <value value="&quot;line&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="base-2-normal" repetitions="10" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="7000"/>
    <metric>mean [protection] of turtles</metric>
    <metric>mean [predationRes] of turtles</metric>
    <metric>mean [predationGoods] of turtles</metric>
    <metric>mean [production] of turtles</metric>
    <metric>standard-deviation [protection] of turtles</metric>
    <metric>standard-deviation [predationRes] of turtles</metric>
    <metric>standard-deviation [predationGoods] of turtles</metric>
    <metric>standard-deviation [production] of turtles</metric>
    <enumeratedValueSet variable="model-version">
      <value value="&quot;normal&quot;"/>
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
