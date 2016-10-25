globals [
  ; model globals
  transaction-receipts  ; receipts are a way to visualize who is transacting how much with who
  gdp                   ; representation of the gross domestic product of the economy
  radius                ; the radius in which people will transact. Useful to set to 20 if you are investigating a small number of people in economy
  productivity-growth   ; a default to represent the growth in productivity over time, people get smarter and find better ways to do things
  productivity          ; the productivity at a given moment in time
  max-goods-production  ; the maximum goods a person will produce, production is only valuable if that production can actually be sold
  total-cash            ; the total cash of all people, used to calculate the relative wealth of a person
  min-consumable-goods-tolerable ; the level of consumable goods at which a person will want or attempt to get a loan
  loan-length           ; how long a loan will be outstanding before it must be settled
  transaction-volume    ; a measure of how many transactions take place in each time step
  initial-lender-cash   ; the amount of cash each lender has to begin with
  goods-degrade-factor  ; how quickly consumable goods degrade. If a person has few consumable-goods they attempt to take out a loan.

  ; optimize plot
  plot-cash
  plot-credit
  plot-debt
  plot-defaults
  plot-produced-goods
  plot-consumable-goods
  ; for unit tests
  unit-test-results
]

breed [people person]
breed [lenders lender]

people-own
[
  cash
  credit
  debt
  defaults
  produced-goods
  consumable-goods
  hustle
  production
]

lenders-own
[
  cash
]

; links are loans
links-own
[
  with-person
  loan-amount
  loan-amount-with-interest
  loan-maturity-tick
]

to setup
  clear-all
  initialize-variables
  create-people number-of-people [setup-people]
  create-lenders num-lenders [
    set cash initial-lender-cash
    set shape "house"
    setxy random-xcor random-ycor
  ]
  reset-ticks
end

; variables that typically we don't need to play with but can be manipulated via
; the repl to explore the model
to initialize-variables
  set goods-degrade-factor 0.7
  set radius 5
  set productivity 0.01
  set productivity-growth 0.001
  set max-goods-production 10
  set min-consumable-goods-tolerable 10
  set loan-length 10
  set print-transaction-recepts? false
  set initial-lender-cash 100
end

to setup-people
    set cash 10
    set credit 0
    set debt 0
    set defaults 0
    set produced-goods 10
    set consumable-goods 0
    set hustle ((random 10) / 10 ) + 1
    set production hustle
    set shape "person"
    setxy random-xcor random-ycor
    set-wealth-color
end

to go
  set transaction-receipts ""
  set transaction-volume 0
  set gdp 0
  set total-cash max [cash] of people

  set productivity productivity + productivity-growth

  ask lenders
  [
    settle-loans self ticks
  ]

  ask people
  [
    set heading heading + random-float 360
    forward 1
    set-wealth-color

    let others-count (count people-on patches in-radius radius) - 1
    if (others-count > 0)
    [
      let amount-to-transact-per-person ((total-cash-credit self) / others-count)
      ask people-on patches in-radius radius
      [
        transact myself self amount-to-transact-per-person ticks
      ]
    ]

    if (allow-lending?) [
      let lenders-count (count lenders-on patches in-radius radius)
      if (lenders-count > 0) [
        let amount-to-sell-to-lender (produced-goods / lenders-count)
        ask lenders-on patches in-radius radius
        [
          borrow myself self interest-rate ticks
          ; Lenders must also participate in economy or all the cash in the system will be removed by the lenders.
          lender-transact self myself amount-to-sell-to-lender
        ]
      ]
    ]

    set production productivity + (random-normal hustle (0.1 * hustle))
    set produced-goods (produced-goods + production)
    ; stop producing goods if person cannot sell them
    if (produced-goods > max-goods-production)
    [
      set produced-goods max-goods-production
    ]
    set max-goods-production max-goods-production + productivity-growth
    set consumable-goods (consumable-goods * goods-degrade-factor)
    if (consumable-goods < 0.1 )
    [
      set consumable-goods 0
    ]
    set gdp gdp + produced-goods
  ]

  if (transaction-receipts != "" and print-transaction-recepts? )
  [
    print transaction-receipts
  ]

  tick

end

to settle-loans [lender thetick]
  ask ([my-links] of lender) with [loan-maturity-tick <= thetick]
  [
    let loan self
    ask lender [ set cash cash + [loan-amount-with-interest] of loan ]
    ask person with-person
    [
      set cash cash - [loan-amount-with-interest] of loan
      set debt debt - [loan-amount] of loan
      if (debt < 0)
      [
        set credit credit + debt
        set debt 0
      ]
    ]
    die
  ]
end


; Lender Transactions are a way to get cash back into the hands of the people
; This is a short cut to creating a government that prints money to purchase goods-produced
to lender-transact [lender otherperson amount-to-transact]
  if ([cash] of lender > initial-lender-cash)
  [
    ask otherperson [ set cash ([cash] of otherperson + amount-to-transact) ]
    ask lender [ set cash ([cash] of lender - amount-to-transact) ]
    ask otherperson [ set produced-goods (produced-goods - amount-to-transact) ]
    let transaction-receipt (word " TL-" [who] of lender "->" [who] of otherperson ":" amount-to-transact)
    set transaction-receipts word transaction-receipts transaction-receipt
    set transaction-volume transaction-volume + amount-to-transact
  ]
end

to transact [me otherperson amount-to-transact thetick]
  let other-person-is-not-me ([who] of me != [who] of otherperson)
  if (([produced-goods] of otherperson) < amount-to-transact)
  [
    set amount-to-transact [produced-goods] of otherperson
  ]

  if other-person-is-not-me and (amount-to-transact > 0)
  [
    let amount-of-cash-to-spend amount-to-transact
    let amount-of-cash-left [cash] of me - amount-to-transact
    let amount-of-credit-to-spend 0
    if amount-of-cash-left < 0 [
      set amount-of-cash-to-spend [cash] of me
      set amount-of-credit-to-spend amount-to-transact - amount-of-cash-to-spend
    ]

    ask otherperson [ set cash ([cash] of otherperson + amount-to-transact) ]
    ask me [ set cash ([cash] of me - amount-of-cash-to-spend) ]
    ask me [ set credit ([credit] of me - amount-of-credit-to-spend) ]
    ask me [ set debt ([debt] of me + amount-of-credit-to-spend) ]

    let amount-of-goods-to-buy amount-to-transact

    let transaction-receipt (word " T@" thetick "-" [who] of me "->" [who] of otherperson ":" amount-of-goods-to-buy " cash:" amount-of-cash-to-spend " credit:" amount-of-credit-to-spend)

    ask otherperson [ set produced-goods (produced-goods - amount-of-goods-to-buy) ]
    ask me [ set consumable-goods (consumable-goods + amount-of-goods-to-buy) ]
    set transaction-receipts word transaction-receipts transaction-receipt
    set transaction-volume transaction-volume + amount-of-goods-to-buy
  ]
end

to borrow [me lender rate thetick]
  let possible-production ((([production] of me) * loan-length) + [produced-goods] of me - [debt] of me)
  let possible-amount-to-borrow possible-production / 10
  ; If the person could possibly borrow
  if  (possible-production > rate * loan-length)
  ;  ; and the person wants to buy more stuff
    and ([consumable-goods] of me) < min-consumable-goods-tolerable
    and ([cash] of lender > possible-amount-to-borrow)
    and ((link [who] of lender [who] of me) = nobody)
    and ([cash] of me > 0)
  [
    if (print-transaction-recepts? )
    [
      print (word "B@" thetick "-" [who] of me "->" [who] of lender ":" possible-amount-to-borrow ":" (rate * loan-length) ":" [consumable-goods] of me)
    ]
    ask me [ set credit ([credit] of me + possible-amount-to-borrow) ]
    ask lender
    [
      set cash (cash - possible-amount-to-borrow)
      create-link-with me
      let debt-link link who [who] of me
      ask debt-link
      [
        ;set hidden? true
        set with-person [who] of me
        set loan-amount possible-amount-to-borrow
        set loan-amount-with-interest possible-amount-to-borrow + (interest-rate * loan-length)
        set loan-maturity-tick thetick + loan-length
      ]
    ]
  ]
end


to-report total-cash-credit [me]
 report [cash] of me + [credit] of me
end

to-report netWorth [me]
 report [produced-goods] of me + [cash] of me - [debt] of me
end

to set-wealth-color
  ifelse (cash <= total-cash / 3)
  [
    set color red
  ] [
    ifelse (cash <= (total-cash * 2 / 3))
    [
      set color yellow
    ] [
      set color blue
    ]
  ]
end


; Unit Tests
to ut
  run-unit-tests
end

to run-unit-tests
  clear-all
  reset-ticks

  print "Executing Unit Tests"
  let results ""
  let test-count 0

  if ("" != (test-transact-goods)) [ set results (word results (test-transact-goods)) ]
  set test-count test-count + 1
  ask people [ die]
  ask lenders [ die]

  if ("" != (test-borrow)) [ set results (word results (test-borrow)) ]
  set test-count test-count + 1
  ask people [ die]
  ask lenders [ die]

  print (word test-count " run - " results)
end

to-report test-transact-goods
  clear-all

  let results ""
  create-people 1 [
    set cash 10
    set credit 0
    set debt 0
    set produced-goods 0
    set consumable-goods 10
  ]
  create-people 1 [
    set cash 10
    set credit 0
    set debt 0
    set produced-goods 10
    set consumable-goods 0
  ]
  let me (person 0)
  let otherperson (person 1)
  transact me otherperson 3 1
  if ([cash] of me != 7) [ set results (word results " Expected my cash to decrease from 10 to 7 but was " [cash] of me)  ]
  if ([consumable-goods] of me != 13) [ set results (word results " Expected my consumable-goods to increase from 10 to 13 but was " [consumable-goods] of me)  ]
  if ([cash] of otherperson != 13) [ set results (word results " Expected others cash to increase from 10 to 13 but was " [cash] of otherperson)  ]
  if ([produced-goods] of otherperson != 7) [ set results (word results " Expected others produced-goods to decrease from 10 to 7 but was " [produced-goods] of otherperson ) ]

  ifelse (results != "" ) [ set results (word "FAIL test-transact-goods " results) ] [set results "PASS test-transact-goods "]
  report results
end


to-report test-borrow
  clear-all

  let results ""
  create-people 1
  [
    set cash 10
    set credit 0
    set debt 0
    set produced-goods 4
    set production 2
    set consumable-goods 10
  ]
  create-lenders 1
  [
    set cash 8
  ]
  let me (person 0)
  let alender (lender 1)

  set loan-length 3
  set initial-lender-cash 5
  set min-consumable-goods-tolerable 20
  borrow me alender 0.1 1

  if ([cash] of me != 10) [ set results (word results " Expected my cash to remain at 10 but was " [cash] of me)  ]
  if ([cash] of alender != 7) [ set results (word results " Expected lenders cash to reduced from 8 to 7 but was " [cash] of alender)  ]
  if ([credit] of me != 1) [ set results (word results " Expected my credit to increase from 0 to 1 but was " [credit] of me)  ]

  let loan one-of links
  if (count links != 1) [ set results (word results " Expected there to be one link that is a loan but was " count links)  ]
  if ([loan-amount] of loan != 1) [ set results (word results " Expected my loan-amount of loan to be 1 but was " [loan-amount] of loan)  ]
  if ([loan-maturity-tick] of loan != 4) [ set results (word results " Expected my loan-maturity-tick of loan to be 4 but was " [loan-maturity-tick] of loan)  ]

  settle-loans alender 4
  let loan-completed one-of links
  if (count links != 0) [ set results (word results " Expected loan to be fufuilled but was " count links)  ]

  if ([credit] of me != 0) [ set results (word results " Expected my credit to decrease from 1 to 0 but was " [credit] of me)  ]


  ifelse (results != "" ) [ set results (word "FAIL test-borrow " results) ] [set results "PASS test-borrow "]
  report results
end
@#$#@#$#@
GRAPHICS-WINDOW
198
10
482
315
16
16
8.303030303030303
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
-16
16
0
0
1
ticks
30.0

BUTTON
132
81
188
114
Go
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

BUTTON
5
81
72
115
Setup
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
75
81
130
114
Go
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
8
194
188
314
Person Example
tick
value
0.0
10.0
0.0
20.0
true
true
"" "if (ticks > 20) [\nset-plot-x-range (ticks - 20) ticks \n]\nif (nobody != person person-example) [\nset plot-cash ([cash] of person person-example)\nset plot-credit ([credit] of person person-example)\nset plot-debt ([debt] of person person-example)\nset plot-produced-goods ([produced-goods] of person person-example)\nset plot-consumable-goods ([consumable-goods] of person person-example)\n]"
PENS
" Cash" 1.0 0 -13840069 true "" "plot plot-cash"
" Credit" 1.0 0 -13791810 true "" "plot plot-credit"
"Debt" 1.0 0 -7500403 true "" "plot plot-debt"
"Consumable" 1.0 0 -6459832 true "" "plot plot-consumable-goods"
"Produced" 1.0 0 -2674135 true "" "plot plot-produced-goods"

INPUTBOX
7
118
72
189
person-example
0
1
0
Number

SLIDER
4
10
188
43
number-of-people
number-of-people
0
100
6
1
1
NIL
HORIZONTAL

PLOT
9
322
200
451
GDP per Tick
Ticks
GDP
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot gdp"

SLIDER
74
155
188
188
interest-rate
interest-rate
0
10
10
0.1
1
NIL
HORIZONTAL

SLIDER
4
45
188
78
num-lenders
num-lenders
0
10
1
1
1
NIL
HORIZONTAL

PLOT
215
323
401
452
Transaction Volume
Ticks
Vol
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot transaction-volume"

PLOT
414
323
629
452
Total Cash
Ticks
Cash
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"People" 1.0 0 -13840069 true "" "plot sum [cash] of people"
"Lenders" 1.0 0 -14835848 true "" "plot sum [cash] of lenders"

SWITCH
495
12
633
45
print-transaction-recepts?
print-transaction-recepts?
1
1
-1000

SWITCH
496
49
634
82
allow-lending?
allow-lending?
1
1
-1000

TEXTBOX
497
91
647
315
People are producing goods\nselling those goods to each\nother. \nPeople are RED if they are in the bottom third of cash reserves.\nPeople are YELLOW if they are in the middle third of cash reserves.\nPeople are BLUE if they are in the top third of cash reserves\n\nHouses are lenders. Lenders \nwill lend people money if they think they can pay it back.\n\n
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

An attempt to understand the interaction of credit in an economy where people are producing goods and selling to eachother. The scope is the minimal amount to be able to see that increasing available credit by lowering interest rates causes an increase in the production of goods while an economy is transacting.

The original idea stemed from watching Ray Dalio's lecture on how the economy works.
https://www.youtube.com/watch?v=PHe0bXAIuk0&feature=youtu.be

## HOW IT WORKS

There are three types of agents in this model, People and Lenders and Loans. People are represented as a breed with attributes cash, credit, debt, defaults, produced-goods, consumable-goods, hustle, production. Lenders are represented by a breed with a single attribute of cash. Loans are represented as links between People and Lenders with attributes of with-person, loan-amount, loan-amount-with-interest, loan-maturity-tick.

For each time step there are four general steps.
1. Lenders force People to pay back loans that are due
2. People transact with eachother attempting to sell the goods they have produced and buy goods if they do not have enough consumable goods.
3. People attempt to get a loan if they need more money to purchase goods.
4. People produce more goods to sell on the next time step.

Note that the interest rate controls just how many loans are issued. Low interest means more loans are issued and high interest means less loans are issued.

The environment is just spatial and is used as a way to have random interactions.

There is really just one input that is offered on the GUI to play with, the interest rate. There are several more inputs that can be varied to investigate the model further and can be seen in the initialize-variables method.

The most interesting output is the gdp per tick. This is the measure of production that we want to influence with the interest rate.


## HOW TO USE IT

Try using the default settings and while the model is running drag the interest slider down to zero and back up to 10. You will notice that loans, represented by the link lines, start to happen and the gdp goes up then stabilizes again. This is essentially demonstrating that credit seems to not actually create more production but allows people to draw the existing pool of produced goods more quickly.


## THINGS TO NOTICE

Liquidity Matters: Comment out the line where the lenders-transact and run the model with a low interest rate. When the lenders are just collecting cash but not participating in the economy they hoard all the cash in the system, no one else can transact. Hoarders of cash cause there to be less transactions in a economy.


## THINGS TO TRY

Try playing with the interest rate slider while the model is running.

## EXTENDING THE MODEL

It would be great to identify if a person uses their credit to do something that makes them more productive that credit could be a positive influence rather than just drawing down on current produced goods.

## RELATED MODELS

Wealth Distribution model and the Bank Reserves model are both very similar but without the credit concept.

## CREDITS AND REFERENCES

Made by Jim McDonald (mcdonji)
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
