require "bafaltom2D"

class DudeList
    new: =>
        @dudeList = {}
        poorCount, middleCount , richCount = 0, 0, 0
        for i = 1, numberOfDudes
            dudeX, dudeY, dudeM = nil, nil, nil
            randomPercent = math.random 100
            if randomPercent < poorPercent -- poor
                poorCount += 1
                {dudeX, dudeY} = randomPointInSubMapCorners!
                dudeM = math.random 0, moneyMaxPoor
            else
                dudeX = math.random mapMinX, mapMaxX
                dudeY = math.random mapMinY, mapMaxY

                if randomPercent < poorPercent + middlePercent -- middle
                    middleCount += 1
                    dudeM = math.random moneyMaxPoor + 1, moneyMaxMiddle
                else -- rich
                    richCount += 1
                    moneyMin = moneyMaxRich - (moneyMaxRich-moneyMaxMiddle)*0.5
                    moneyMax = moneyMaxRich - (moneyMaxRich-moneyMaxMiddle)*0.25
                    dudeM = math.random(moneyMin, moneyMax)
            @add Dude dudeX, dudeY, dudeM

    add: (dude) =>
        table.insert @dudeList, dude

    find: (id) =>
        if id == 0
            return player

        for _, d in ipairs @dudeList
            if d.id == id
                return d
        return nil

    areAllMiddle: =>
        for _, d in ipairs @dudeList
            if d\class! ~= "middle"
                return false
        return true

    getAllRichPlus: =>
        correspondingDudes = {}
        for _,d in ipairs(@dudeList)
            if d\class! == "rich+"
                table.insert correspondingDudes, d
        return correspondingDudes

class Dude extends Entity
    currentID = 0
    giveNextID = ->
        currentID += 1

    new: (x, y, @money) =>
        super x, y
        @id = Dude.giveNextID!
        if @class! ~= "poor" then
            @x = math.random mapMinX, mapMaxX
            @y = math.random mapMinY, mapMaxY
        else
            -- TODO: generation better distributed in submap
            @x = math.random subMapMinX, subMapMaxX
            if @x < mapMinX or @x > mapMaxX
                @y = math.random subMapMinY, subMapMaxY
            else
                @y = math.random subMapMinY, mapMinY
        @destX = @x
        @destY = @y
        @speedX = 0
        @speedY = 0
        @waitingTime = 0
        @invulnTimer = 0
        @currentPrey = nil -- current target (dude)
        @attacked = -1 -- id of attacked dude (-1 if void)
        @attackedBy = -1 -- id of attacking dude (-1 if void)
        @attackTimer = 0
        @moneyDisplayTimer = 0
        @state = ''
        @dudePic = nil
        @dudeAnim = nil
        @littleDude\findNewDestination!
        @littleDude\setState 'walking'


    draw: =>
        dudeColors = nil
        switch dude\class!
            when "poor"
                dudeColors = poorColor
            when "middle"
                dudeColors = middleColor
            when "rich"
                dudeColors = richColor
            when "rich+"
                dudeColors = richPlusColor
            else
                error "dude class '#{dude\class!}' is not recognized"
        love.graphics.setColor dudeColors

        dudeSize = @dudeSize!
        --- SIMPLE GRAPHICS
        if true or @class! == "rich+"
            fillage = "fill" if @invulnTimer <= 0 else "line"
            love.graphics.rectangle fillage,
                @x - dudeSize / 2, @y - dudeSize / 2, dudeSize, dudeSize

        --- PICTURE GRAPHICS
        if false and @dudeAnim and @dudePic
            directionIsLeft = -1 if @speedX > 0 else 1
            alpha = 100 if @invulnTimer > 0 else 255
            love.graphics.setColor 255, 255, 255, alpha
            @dudeAnim\draw @dudePic,
                @x, @y, 0, directionIsLeft, 1, @dudePic\getWidth! / 2, 32
        if DEBUG
            love.graphics.print @id, @getX! + dudeSize + 5, @getY!
            love.graphics.print @state, @getX! + dudeSize + 5, @getY! + 10
            love.graphics.print 'w: #{@waitingTime}',
                @getX! + dudeSize + 5, @getY! + 30
            if @class! == 'rich'
                love.graphics.print @attackTimer, @getX! + dudeSize + 5, @getY! + 20

        -- draw prey circle
        if @class! == "rich"
            love.graphics.circle "line", @getX!, @getY!, @preyRadius!, 50

        -- draw moneyBar
        if @moneyDisplayTimer > 0
            dudeM = math.ceil @money
            moneyMin, moneyMax = nil, nil
            if dudeM <= moneyMaxPoor
                moneyMin, moneyMax = 0, moneyMaxPoor
            elseif dudeM <= moneyMaxMiddle
                moneyMin, moneyMax = moneyMaxPoor, moneyMaxMiddle
            elseif dudeM <= moneyMaxRich
                moneyMin, moneyMax = moneyMaxMiddle, moneyMaxRich
            if moneyMax ~= nil
                relativeMoney = (dudeM - moneyMin) / (moneyMax - moneyMin)
                colorAlpha = 255
                if @moneyDisplayTimer < dudeMoneyFade
                    colorAlpha = 255 * @moneyDisplayTimer / dudeMoneyFade
                --love.graphics.print "#{moneyMin} < #{dudeM} < #{moneyMax}", @x, @y
                love.graphics.setColor 0, 0, 0, colorAlpha
                love.graphics.rectangle "line",
                    @getX! - 20, @getY! - 40, 40, 10 -- magic numbers!
                love.graphics.setColor 255, 255, 0, colorAlpha
                love.graphics.rectangle "fill",
                    @getX! - 19, @getY! - 39,
                    math.floor relativeMoney * 38, 8 -- magic numbers!

        -- draw lightning
        if @currentPrey ~= nil and not @class! == "rich+"
            attackedDude = @currentPrey
            attackBuildUpFactor = 1 - (@attackTimer / richHitTimer)
            distance = distance2Entities dude, attackedDude
            {endX, endY} = bafaltomVector @getX!, @getY!, attackedDude\getX!,
                attackedDude\getY!, distance * attackBuildUpFactor
            love.graphics.setColor 255, 69, 0, 255 * attackBuildUpFactor
            love.graphics.line @getX!, @getY!, @getX! + endX, @getY! + endY

        -- draw dest Path
        if DEBUG
            love.graphics.setColor dudeColors
            love.graphics.line @getX!, @getY!, @destX, @destY

    class: =>
        if @money <= moneyMaxPoor
            return "poor"
        elseif @money <= moneyMaxMiddle
            return "middle"
        elseif @money < moneyMaxRich
            return "rich"
        else
            return "rich+"

    update: (dt) =>
        @x += @speedX * dt
        @y += @speedY * dt

        -- dude pathfinding
        -- arrived at destination?
        distDest = distance2Points @getX!, @getY!, @destX, @destY
        if distDest <= destAcceptanceRadius
            if @state ~= 'waiting'
                @destX = @getX!
                @destY = @getY!
                @setState 'waiting'
                @waitingTime = math.random dudeNextDestWaitTimeMin,dudeNextDestWaitTimeMax
            elseif @waitingTime > 0
                @waitingTime -= dt
            else
                @findNewDestination!
                @setState 'walking'
        -- attracted by coins
        closestCoin = @findClosestCoin!
        if closestCoin ~= nil and @state ~= 'fleeing' and @class! ~= "rich+"
            @destX = closestCoin.x
            @destY = closestCoin.y
            @setState 'moneyPursuing'
        if closestCoin == nil and @state == 'moneyPursuing'
            -- this dude was attracted to a coin which doesn't exist anymore
            @destX = @x
            @destY = @y

        -- rich+ dudes are attracted to player
        if @class! == "rich+"
            if distance2Entities(dude, player) > richPlusStalkDistance
                @destX = player.x
                @destY = player.y
                @setState 'playerPursuing'

        -- no distraction --> go to destination
        @speedX = @destX - @x
        @speedY = @destY - @y

        @calculateSpeed!

        -- push or be pushed by other players
        closestDude = findClosestOf dudes, dude, @dudeSize! * 2
        if closestDude ~= nil
            @dudePush closestDude

        -- prey on the weak
        if @class! == "rich"
            if @invulnTimer <= 0 and (@state == "walking" or @state == "waiting")
                prey = @findClosestPrey!
                if prey ~= nil
                    if @attackTimer < 0
                        @attackTimer = richHitTimer
                        @attacked = prey.id
                        @attackTimer = richHitTimer
                        stolenMoney = math.min prey.money, moneyStolenByHit
                        prey\isAttacked dude, stolenMoney
                    else
                        @attackTimer -= dt
                else
                    @attackTimer = richHitTimer
                @currentPrey = prey
            else
                @attackTimer = richHitTimer

        -- rich+ shoot Fireballz
        if @class! == "rich+" and not @attackTimer > 0 and distance2Entities(@, player) < superRichHitDistance
            FireBallClass.createFireBall(dude,player.x,player.y)
            @attackTimer = fireBallAttackTimer -- FIXME
            @attacked = 0

        -- flee
        if @attackedBy ~= -1
            attacker = dudes.find(dude.attackedBy)
            destX = @getX! + 2 * (@getX! - attacker\getX!)
            destY = @getY! + 2 * (@getY! - attacker\getY!)
            destX = math.max destX, fleeMinX
            destX = math.min destX, fleeMaxX
            destY = math.max destY, fleeMinY
            destY = math.min destY, fleeMaxY
            @destX, @destY = destX, destY
            @attackedBy = -1
            @setState 'fleeing'

        -- animation
        if @dudeAnim ~= nil
            @dudeAnim\update dt

        -- timers
        dude.invulnTimer -= dt if dude.invulnTimer > 0
        dude.moneyDisplayTimer -= dt if dude.moneyDisplayTimer > 0
        dude.attackTimer -= dt if @class! == "rich+" and @attackTimer > 0

    updateMoney: (amount) => -- negative/positive amount : take/give money
        previousClass = @class!
        @money += amount
        if @class! ~= previousClass
            @changeClass _previousClass
        @moneyDisplayTimer = dudeMoneyTimer

    changeClass: (previousClass) =>
        if previousClass == "rich"
            @currentPrey = nil
        @attackTimer = 0
        @waitingTime = invulnTimeByClassChange
        @setState "waiting"
        @refreshDudeAnimation!

    dudePush: (smallerDude) =>
        if @getX! == smallerDude\getX! and @getY! == smallerDude\getY!
             -- hotfix
             smallerDude.x = smallerDude.x + @size! * 2
        else
            {translationX, translationY} = bafaltomVector @x, @y,
                smallerDude.x, smallerDude.y, @dudeSize! * 2
            smallerDude.destX = smallerDude\getX! + translationX
            smallerDude.destY = smallerDude\getY! + translationY

    preyRadius: =>
        return 0 if @class! ~= "rich" else @money * moneyRadiusFactor

    findClosestPrey: =>
        filteredDudes = {}
        for _, d in ipairs(dudes)
            if d.money < @money and not d.invulnTimer > 0
                table.insert filteredDudes, d
        findClosestOf filteredDudes, @, @preyRadius!

    findClosestCoin: =>
        findClosestOf coins, @, dudeAttractionDistance

    getX: =>
        @x

    getY: =>
        @y

    dudeSize: =>
        math.max 5, @money / 10

    isAttacked: (predator, moneyStolen) =>
        @updateMoney -1 * moneyStolen
        CoinClass.createCoinBatchWithDirection @getX!, @getY!, moneyStolen, 0, 0
        @attackedBy = predator.id
        @invulnTimer = invulnTimeByHit

    findNewDestination: =>
        if @class! == "poor" and not isInSubMap @getX!, @getY!
            -- poor go to the closest suburbs corner
            @destX = subMapMinX if @getX! - subMapMinX < subMapMaxX - @getX! else subMapMaxX
            @destY = subMapMinY if @getY! - subMapMinY < subMapMaxY - @getY! else subMapMaxY
        else
            @destX = math.random @x - dudeNextDestRadius, @x + dudeNextDestRadius
            @destY = math.random @y - dudeNextDestRadius, @y + dudeNextDestRadius

            local limitMinX, limitMaxX, limitMinY, limitMaxY
            if @class! == "poor"
                limitMinX = subMapMinX
                limitMaxX = subMapMaxX
                limitMinY = subMapMinY
                limitMaxY = subMapMaxY
            else
                limitMinX = mapMinX
                limitMaxX = mapMaxX
                limitMinY = mapMinY
                limitMaxY = mapMaxY
            @destX = math.max limitMinX, @destX
            @destX = math.min limitMaxX, @destX
            @destY = math.max limitMinY, @destY
            @destY = math.min limitMaxY, @destY
            @setState 'walking'

    calculateSpeed: =>
        actualSpeed = math.sqrt @speedX^2 + @speedY^2
        if actualSpeed > dudeMaxSpeed
            {@speedX, @speedY} = bafaltomVector 0, 0, @speedX, @speedY, dudeMaxSpeed

    refreshDudeAnimation: =>
        -- update the dudePic and dudeAnim attributes of dude
        -- there's probably a clever way to do it (with less copypaste)
        dudeP, dudeA = nil, nil
        if @class! == "poor"
            switch @state
                when "waiting"
                    dudeP = picPoorIdle
                    dudeA = anim8.newAnimation "loop", dudeGrid('1,1-4'), 0.3
                when "walking"
                    dudeP = picPoorWalking
                    dudeA = anim8.newAnimation "loop", dudeGrid('1,1-4'), 0.2
                when "fleeing"
                    dudeP = picPoorRunning
                    dudeA = anim8.newAnimation "loop", dudeGrid('1,1-4'), 0.15
                when "moneyPursuing"
                    dudeP = picPoorMoney
                    dudeA = anim8.newAnimation "loop", dudeGrid('1,1-4'), 0.15
        elseif @class! == "middle"
            switch @state
                when "waiting"
                    dudeP = picMiddleIdle
                    dudeA = anim8.newAnimation "loop", dudeGrid('1,1-4'), 0.3
                when "walking"
                    dudeP = picMiddleWalking
                    dudeA = anim8.newAnimation "loop", dudeGrid('1,1-4'), 0.2
                when "fleeing"
                    dudeP = picMiddleRunning
                    dudeA = anim8.newAnimation "loop", dudeGrid('1,1-4'), 0.15
                when "moneyPursuing"
                    dudeP = picMiddleMoney
                    dudeA = anim8.newAnimation("loop", dudeGrid('1,1-4'), 0.15)
        elseif @class! == "rich"
            switch @state
                when "waiting"
                    dudeP = picRichIdle
                    dudeA = anim8.newAnimation "loop", dudeGrid('1,1-4'), 0.3
                when "walking"
                    dudeP = picRichWalking
                    dudeA = anim8.newAnimation "loop", dudeGrid('1,1-4'), 0.2
                when "fleeing"
                    dudeP = picRichRunning
                    dudeA = anim8.newAnimation "loop", dudeGrid('1,1-4'), 0.15
                when "moneyPursuing"
                    dudeP = picRichMoney
                    dudeA = anim8.newAnimation "loop", dudeGrid('1,1-4'), 0.15

        @dudePic = dudeP
        @dudeAnim = dudeA

    acceptedStates: {
        'waiting'
        'walking'
        'fleeing'
        'moneyPursuing'
        'playerPursuing'
    }

    setState: (newState) =>
        for _,s in ipairs Dude.acceptedStates
            if newState == s
                @state = newState
                @refreshDudeAnimation!
                return
        error('Dude.setState(newState) : newState = '..newState..' was not in accepted states')
