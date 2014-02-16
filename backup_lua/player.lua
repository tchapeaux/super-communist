player = {}
setmetatable(player, DudeClass)

player.items = {}

player.initialize = function()
	player.id = 0
	player.x = (mapMinX + mapMaxX)/2
	player.y = (mapMinY + mapMaxY)/2
	player.money = 0
	player.corrupted = false
	player.corruptLeakTimer = 0
	player.speedX = 0
	player.speedY = 0
	player.invulnTimer =  0
	player.life = playerLives

	player.weaponRadius = 0
end

player.draw = function ()
	love.graphics.setColor(0,255,255)
	if (player.invulnTimer <= 0) then
		fillage = "fill"
	else
		fillage = "line"
	end

	local sizeCorruptionFactor
	if (player.corrupted) then
		sizeCorruptionFactor = 2
	else
		sizeCorruptionFactor = 1
	end

	love.graphics.rectangle(fillage, player.x - sizeCorruptionFactor*playerSize/2 , player.y - sizeCorruptionFactor*playerSize/2, sizeCorruptionFactor*playerSize, sizeCorruptionFactor*playerSize)

	if (player.weaponRadius > 0) then
		love.graphics.circle("line", player.x, player.y, player.weaponRadius, player.weaponRadius)
	end
end

player.update = function(dt)
	player.x = player.x + player.speedX*dt
	player.y = player.y + player.speedY*dt

	-- speed update
	local speedFactor = 1
	if (player.corrupted) then
		speedFactor = speedFactor*playerCorruptionSpeedFactor
	end

	-- key Presses
	if (love.keyboard.isDown("z") or love.keyboard.isDown("w")) then
		player.speedY = player.speedY - speedFactor*playerSpeedKeyDownIncrease*dt
	elseif (player.speedY < 0) then
		player.speedY = math.min(0,player.speedY + playerSpeedKeyUpDecrease*dt)
	end

	if (love.keyboard.isDown("s")) then
		player.speedY = player.speedY + speedFactor*playerSpeedKeyDownIncrease*dt
	elseif (player.speedY > 0) then
		player.speedY = math.max(0,player.speedY - playerSpeedKeyUpDecrease*dt)
	end

	if (love.keyboard.isDown("a") or love.keyboard.isDown("q")) then
		player.speedX = player.speedX - speedFactor*playerSpeedKeyDownIncrease*dt
	elseif (player.speedX < 0) then
		player.speedX = math.min(0,player.speedX + playerSpeedKeyUpDecrease*dt)
	end

	if (love.keyboard.isDown("d")) then
		player.speedX = player.speedX + speedFactor*playerSpeedKeyDownIncrease*dt
	elseif (player.speedX > 0) then
		player.speedX = math.max(0,player.speedX - playerSpeedKeyUpDecrease*dt)
	end

	-- attack
	if (love.keyboard.isDown(" ") and player.invulnTimer <= 0) then
		if (not player.corrupted) then
			player.weaponRadius = math.min(player.weaponRadius + playerWeaponRadiusSpeed*dt, playerWeaponRadiusMax)
		end
	elseif (player.weaponRadius > 0) then
		player.attack(player.weaponRadius)
		player.weaponRadius = 0
	end

	-- corruption
	if (player.corrupted) then
		if (player.money < 3*playerMaxMoney/4) then
			player.corrupted = false
		end
		if (player.corruptLeakTimer <= 0) then
			player.corruptLeakTimer = playerCorruptionLeakTimer
			player:updateMoney(-playerCorruptionLeakValue)
			local _dirX, _dirY = math.random(-100,100)/100, math.random(-100,100)/100
			CoinClass.createCoinBatchWithDirection(player.x, player.y, playerCorruptionLeakValue, _dirX, _dirY)
		end
	end

	-- timer
	if (player.invulnTimer > 0) then player.invulnTimer = player.invulnTimer - dt end
	if (player.corruptLeakTimer > 0) then player.corruptLeakTimer = player.corruptLeakTimer - dt end
end

player.attack = function(weaponRadius)
	for _, prey in ipairs(dudes) do
		if (prey.invulnTimer <= 0 and distance2Entities(player, prey) < weaponRadius) then
			moneyStolen = prey.money/2
			prey:isAttacked(player, moneyStolen)
		end
	end
end

player.isAttacked = function()
	player.money = math.max(0,player.money - moneyStolenByHit)
	CoinClass.createCoinBatch(player.x, player.y, moneyStolenByHit)
	player.invulnTimer = playerInvulnTimeByHit
	player.life = player.life - 1
end

player.dudeSize = function() return playerSize end
player.class = function() return "player" end
player.getX = function() return player.x end
player.getY = function() return player.y end

player.updateMoney = function(player, amount)
	-- negative/positive amount : take/give money
	assert(player.money + amount >= 0, "player.updateMoney: player.money is "..player.money.." and amount is "..amount)

	player.money = player.money + amount

	if (player.money > playerMaxMoney) then
		player.life = player.life - 1
		player.corrupted = true
		player.moneyDrop(player.money - playerMaxMoney)
	end
end

player.moneyDrop = function(amount)
	droppedAmount = math.min(player.money, amount)
	CoinClass.createCoinBatch(player.x, player.y, droppedAmount)
	player.money = player.money - droppedAmount
end

player.getItem = function(item)
	table.insert(player.items, item)
	if (item.name == "YOU LOOSE") then
		player.life = 0
	elseif (item.name == "YOU WIN") then
		print("cheater!")
		player.life = 0
	elseif (item.name == "Useless") then
		assert(true == true, "42")
	end
end

player.keypressed = function(player, k)
	if (k == "lshift") then
		player.moneyDrop(playerMegaDropAmount)
	elseif (k == "e") then
		player.moneyDrop(playerMiniDropAmount)
	end
end

player.initialize()