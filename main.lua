-- Air Hockey

system.activate( "multitouch" )

local gameUI = require("gameUI")
local physics = require( "physics" )

physics.start()
-- physics.setDrawMode ( "hybrid" )	 -- Uncomment if you want to see all the physics bodies
physics.setGravity(0,0) -- We set the gravity to (0,0) in order to simulate an air hockey table

-- Audio
local puckHitPaddle = audio.loadSound("puckHitPaddle.wav")
local puckHitWall = audio.loadSound("puckHitWall.wav")
local buzzer = audio.loadSound("buzzer.wav")
local winner = audio.loadSound("winner.wav")
local goalScore = audio.loadSound("goalScore.wav")

-- Display settings (determine the bounding box of the visible playing screen)
local topLeft = {
	x = (display.contentWidth - display.viewableContentWidth) / 2, 
	y = (display.contentHeight - display.viewableContentHeight) / 2}
	
local bottomRight = {
	x = topLeft.x + display.viewableContentWidth, 
	y = topLeft.y + display.viewableContentHeight}

-- Game Settings
local goalWidthPercent = 50 / 100 

-- Wall settings (these walls should only interact with the puck and not the paddles)
local wallColor = {r=0, g=0, b=0, a=0}
local wallThickness = 35;
local wallCollisionFilter = { categoryBits = 1, maskBits = 4 } 
local wallPhysicsProp = {density=1, friction=.5, bounce=0.3, filter=wallCollisionFilter}

-- Paddle wall settings 
-- extra walls so the paddles do not go into the goals or across the middle of the table)
-- these walls also prevent the paddles from bouncing off the wall, because they have a bounce of 0 (change bounce to greater then 0 to see the effect)
local paddleWallColor = {r=255, g=255, b=0, a=0}
local paddleWallThickness = wallThickness;
local paddleWallCollisionFilter = { categoryBits = 2, maskBits = 8} 
local paddleWallPhysicsProp = {density=wallPhysicsProp.density, friction=wallPhysicsProp.friction, 
		bounce=0, filter=paddleWallCollisionFilter}

-- Puck settings
local puck
local puckRadius = 45
local puckAvalLocation = {bottom="bottom", middle="middle", top="top"}
local puckDamping = {angular = 1, linear = .3} -- Linear damping determines how fast the puck slows down 
local puckInitialCoords = {x = topLeft.x + (display.viewableContentWidth / 2), y = topLeft.y + (display.viewableContentHeight / 2) }
local puckCollisionFilter = { categoryBits = 4, maskBits = 9 } 
local puckPhysicsProp = {density=1, friction=.2, bounce=1, radius=puckRadius, filter=puckCollisionFilter}

-- Paddle settings
local paddleRadius = 55
local puckColor = {r=255, g=0, b=0, a=255}
local paddleDamping = {angular = 5, linear = 5} -- Set a high linear damping for the paddles so they are not greatly affected by the puck
local paddleDragProp = {maxForce=100000, frequency=10000, dampingRatio=1, center=true}
local paddleCollisionFilter = { categoryBits = 8, maskBits = 6 } 
local paddlePhysicsProp = {density=1, friction=.3, bounce=0, radius=paddleRadius, filter=paddleCollisionFilter}

-- Paddle one settings
local p1Paddle
local p1PaddleInitialCoords = {x = topLeft.x + (display.viewableContentWidth / 2), y = topLeft.y + ((display.viewableContentHeight / 5) * 4)}
local p1PaddleColor = {r=0, g=255, b=0, a=255}

-- Paddle two settings
local p2Paddle
local p2PaddleInitialCoords = {x = topLeft.x + (display.viewableContentWidth / 2), y = topLeft.y + ((display.viewableContentHeight / 5) * 1)}
local p2PaddleColor = {r=0, g=0, b=255, a=255}

-- General score text settings
local scoreTextSize = 90
local pointsToWin = 5

-- Scoreboard textfields
local p1ScoreText
local p2ScoreText

local lastForce -- Used to calculate the volume of a the collision sound effects
local titleScreenGroup

function main()
	display.setStatusBar( display.HiddenStatusBar )
	
	setUpTable()

	setUpTitleScreen()	
end

function setUpTable()
	setUpGroundGraphics()
	setUpPaddleWalls()
	setUpPuckWalls()
	setUpScoreText();
	
end

function setUpTitleScreen()
	
	titleScreenGroup = display.newGroup()
	
	local graphic = display.newRect( 0, 0, display.contentWidth, display.contentHeight )
	graphic:setFillColor(0, 0, 0, 50)
	titleScreenGroup:insert(graphic)
	
 	graphic = display.newImageRect( "titleSplash.png", 530, 196 )
	graphic.x = display.contentWidth / 2
	graphic.y = display.contentHeight / 4
	titleScreenGroup:insert(graphic)
	
	graphic = display.newImageRect( "playButton.png", 568, 224 )
	graphic.x = display.contentWidth / 2
	graphic.y = display.contentHeight - display.contentHeight / 4
	titleScreenGroup:insert(graphic)
	
	display.getCurrentStage():insert(titleScreenGroup)
	
	graphic:addEventListener("touch", startGame)

end

function startGame(event)
	
	titleScreenGroup:removeSelf()

	resetScore() -- in the case that this is a rematch
	placePlayerOnePaddle()
	placePlayerTwoPaddle()
	placePuck(puckAvalLocation.center) 	
	Runtime:addEventListener( "postCollision", onPostCollision )
	Runtime:addEventListener( "collision", onCollision )
end

function resetScore()
	
	p1ScoreText.text = "0"
	p2ScoreText.text = "0"
end

function setUpGroundGraphics()
	
	local graphic = display.newImageRect( "bg.png", 768, 1024 )
	graphic.x = display.contentWidth / 2
	graphic.y = display.contentHeight / 2
	
	local graphic = display.newImageRect( "score.png", 122, 144 )
	graphic.x = topLeft.x + 90
	graphic.y = display.contentHeight / 2
		
	graphic = display.newImageRect( "centerLine.png", 768, 9 )
	graphic.x = display.contentWidth / 2
	graphic.y = display.contentHeight / 2
	
	graphic = display.newImageRect( "centerCircle.png", 198, 198 )
	graphic.x = display.contentWidth / 2
	graphic.y = display.contentHeight / 2
	
	-- top goal line
	graphic = display.newImageRect( "goalLine.png", 497, 203 )
	graphic.x = display.contentWidth / 2
	graphic.y = topLeft.y + wallThickness * 2 + 70
	
	-- bottom goal line
	graphic = display.newImageRect( "goalLine.png", 497, 203 )
	graphic.x = display.contentWidth / 2
	graphic.y = bottomRight.y - wallThickness * 2 -70
	graphic.rotation = 180
	
end


function onPostCollision(event)
	
	-- Grab the most recent force in order to determine how loud to play the collision sound effects
	if(event.force ~= 0) then
		lastForce = event.force
	end
	
	-- Check if the puck collided with a goal body
	if  (event.object1.name == "player1Goal" or event.object1.name =="puck") 
		and (event.object1.name == "puck" or event.object1.name =="player1Goal")  then 
		-- Player one scored
		puck:removeSelf()
		audio.setVolume(1)
		audio.play(goalScore)
		audio.play(buzzer)
		addPointToPlayer(1)

	elseif (event.object1.name == "player2Goal" or event.object1.name =="puck") 
		and (event.object1.name == "puck" or event.object1.name =="player2Goal") then 
		-- Player two scored
		puck:removeSelf()
		audio.setVolume(1)
		audio.play(goalScore)
		audio.play(buzzer)
		addPointToPlayer(2)
		
	end
end

function onCollision(event)
	
	-- Check to see if the  puck and a paddle collided or if a puck and wall collided
	-- Will play sound effect depending on how hard the collision was
	if (event.object1.name == "paddle" or event.object1.name =="puck") 
		and (event.object1.name == "puck" or event.object1.name =="paddle") and event.phase == "ended"  then 
		audio.setVolume( lastForce / 1000 )
		audio.play(puckHitPaddle)
	elseif (event.object1.name == "wall" or event.object1.name =="puck") 
		and (event.object1.name == "puck" or event.object1.name =="wall") and event.phase == "ended"  then 
		audio.setVolume( lastForce / 1000 )
		audio.play(puckHitWall)	
	end
	
end


function placePuck(location)
	
	puck = display.newImageRect( "puck.png", 112, 112 )
	puck.x = puckInitialCoords.x
	puck.y = puckInitialCoords.y
	physics.addBody(puck, "dynamic", puckPhysicsProp)
	puck.name = "puck"
	
	puck.linearDamping = puckDamping.linear
	puck.angularDamping = puckDamping.angular
	
	if location == puckAvalLocation.top then
		puck.y = topLeft.y + ((display.viewableContentHeight / 5) * 2)
	elseif location == puckAvalLocation.bottom then
		puck.y = topLeft.y + ((display.viewableContentHeight / 5) * 3)
	end

	-- Prevents puck from passing through paddles at high speeds
	puck.isBullet = true 
	
end


function placePlayerOnePaddle()
	
	p1Paddle = display.newImageRect( "paddle.png", 165, 165)
	p1Paddle.x = p1PaddleInitialCoords.x
	p1Paddle.y = p1PaddleInitialCoords.y
	p1Paddle.name = "paddle"
	physics.addBody(p1Paddle, "dynamic", paddlePhysicsProp)
		
	p1Paddle.angularDamping = paddleDamping.angular
	p1Paddle.linearDamping = paddleDamping.linear
	
	p1Paddle:addEventListener( "touch", onPaddleTouch )
	
end

function placePlayerTwoPaddle()
	p2Paddle = display.newImageRect( "paddle.png", 165, 165)
	p2Paddle.x = p2PaddleInitialCoords.x
	p2Paddle.y = p2PaddleInitialCoords.y
	p2Paddle.name = "paddle"
	physics.addBody(p2Paddle, "dynamic", paddlePhysicsProp)
	
	p2Paddle.angularDamping = paddleDamping.angular
	p2Paddle.linearDamping = paddleDamping.linear
	
	p2Paddle:addEventListener( "touch", onPaddleTouch )
end

function onPaddleTouch(event)
	gameUI.dragBody( event, paddleDragProp)
end

-- Note: For the images we will be passing in a custom shape so the shadow of the image doesn't make the physics body too wide
function setUpPuckWalls()

	local wall
	local goal
	local goalWidth = display.viewableContentWidth * goalWidthPercent

	-- Left wall
	wall = display.newRect( topLeft.x, 0, wallThickness, display.viewableContentHeight )
	wall:setFillColor(wallColor.r, wallColor.g, wallColor.b, wallColor.a)
	wallBody = physics.addBody( wall,"static", wallPhysicsProp)
	wall.name = "wall"
	
	-- Right wall
	wall = display.newRect( bottomRight.x - wallThickness, 0, wallThickness, display.viewableContentHeight )
	wall:setFillColor(wallColor.r, wallColor.g, wallColor.b, wallColor.a)
	physics.addBody( wall, "static", wallPhysicsProp )
	wall.name = "wall"

	wallThickness = 43 -- The wall thickness for the bottom and top walls have to be slightly bigger in order to account for the height of the graphics

	-- Bottom wall
	wall = display.newRect( topLeft.x, bottomRight.y - wallThickness, (display.viewableContentWidth / 2)- (goalWidth / 2), wallThickness)
	wall:setFillColor(wallColor.r, wallColor.g, wallColor.b, wallColor.a)
	physics.addBody( wall, "static", wallPhysicsProp )
	wall.name = "wall"
	
	-- Goal graphics 
	goal = display.newImageRect( "goal.png", goalWidth, 45 )
	goal.x = display.contentWidth / 2
	goal.y = bottomRight.y - goal.height / 2 - 3
	
	wall = display.newRect( topLeft.x + display.viewableContentWidth - wall.width , display.viewableContentHeight - wallThickness, (display.viewableContentWidth / 2)- (goalWidth / 2), wallThickness)
	wall:setFillColor(wallColor.r, wallColor.g, wallColor.b, wallColor.a)
	physics.addBody( wall, "static", wallPhysicsProp )
	wall.name = "wall"
	
	wallThickness = 40 -- Slightly modifying the thickness for the top wall
	
	-- Top wall
	wall = display.newRect( topLeft.x, 0, (display.viewableContentWidth / 2)- (goalWidth / 2), wallThickness)
	wall:setFillColor(wallColor.r, wallColor.g, wallColor.b, wallColor.a)
	physics.addBody( wall, "static", wallPhysicsProp )
	wall.name = "wall"
	
	-- Goal graphics
	goal = display.newImageRect( "goal.png", goalWidth, 45 )
	goal.x = display.contentWidth / 2
	goal.y = topLeft.y + goal.height / 2 
	
	wall = display.newRect(topLeft.x + display.viewableContentWidth - wall.width , 0, (display.viewableContentWidth / 2)- (goalWidth / 2), wallThickness)
	wall:setFillColor(wallColor.r, wallColor.g, wallColor.b, wallColor.a)
	physics.addBody( wall, "static", wallPhysicsProp )
	wall.name = "wall"
	
	-- Place a couple bodies behind the goal line to detect when a goal is scored
	local goalBodies = display.newRect( 0, 0, display.contentWidth, 50 )
	goalBodies.y = topLeft.y - goalBodies.height / 2 - 100
	physics.addBody(goalBodies, "static", {bounce=0})
	goalBodies.name = "player1Goal"
	
	goalBodies = display.newRect( 0, 0, display.contentWidth, 50 )
	goalBodies.y = bottomRight.y + goalBodies.height / 2 + 100
	physics.addBody(goalBodies, "static", {bounce=0})
	goalBodies.name = "player2Goal"
	
end

function addPointToPlayer(playerNumber)

	if playerNumber == 1 then
		p1ScoreText.text = tonumber(p1ScoreText.text) + 1
	else
		p2ScoreText.text = tonumber(p2ScoreText.text) + 1
	end
	
	if tonumber(p1ScoreText.text) == pointsToWin then 
		displayWinnerScreen("redPlayerWins.png")
	elseif tonumber(p2ScoreText.text) == pointsToWin then
		displayWinnerScreen("bluePlayerWins.png")
	else
		-- Need to use a timer since we are not allowed to add physics bodies during the collision event	
		if playerNumber == 1 then
			timer.performWithDelay(10, function(event) placePuck(puckAvalLocation.top) end)	
		else
			timer.performWithDelay(10, function(event) placePuck(puckAvalLocation.bottom) end)	
		end
	end

	
end

function displayWinnerScreen(winningPlayerImg)
	-- Remove the paddles, puck, and event listeners
	Runtime:removeEventListener( "postCollision", onPostCollision )
	Runtime:removeEventListener( "collision", onCollision )
	p1Paddle:removeEventListener( "touch", onPaddleTouch )
	p2Paddle:removeEventListener( "touch", onPaddleTouch )
	
	p1Paddle:removeSelf()
	p2Paddle:removeSelf()
	
	titleScreenGroup = display.newGroup()
	
	local graphic = display.newRect( 0, 0, display.contentWidth, display.contentHeight )
	graphic:setFillColor(0, 0, 0, 50)
	titleScreenGroup:insert(graphic)
	
 	graphic = display.newImageRect( winningPlayerImg, 509, 291 )
	graphic.x = display.contentWidth / 2
	graphic.y = display.contentHeight / 4
	titleScreenGroup:insert(graphic)
	
	graphic = display.newImageRect( "rematchButton.png", 564, 216 )
	graphic.x = display.contentWidth / 2
	graphic.y = display.contentHeight - display.contentHeight / 4
	titleScreenGroup:insert(graphic)
	
	display.getCurrentStage():insert(titleScreenGroup)
	graphic:addEventListener("touch", startGame)
	
	audio.play(winner)
	
end

function setUpScoreText()

	p1ScoreText = display.newText( "0",0, 0, "Helvetica-Bold", scoreTextSize )
	p1ScoreText.x = topLeft.x + 100
	p1ScoreText.y = display.contentHeight / 2 + p1ScoreText.height / 3 
	p1ScoreText.rotation = -90
	p1ScoreText:setTextColor(255, 0, 0)
	
	p2ScoreText = display.newText( "0",0, 0, "Helvetica-Bold", scoreTextSize )
	p2ScoreText.x = topLeft.x + 100
	p2ScoreText.y = display.contentHeight / 2 - p2ScoreText.height / 3 
	p2ScoreText.rotation = -90
	p2ScoreText:setTextColor(0, 0, 255)
end

function setUpPaddleWalls()
	
	local paddleWall
		
	-- Top paddle wall
	paddleWall = display.newImageRect( "blueBar.png", 768, 51 )
	paddleWall.x = topLeft.x + paddleWall.width / 2
	paddleWall.y = topLeft.y + paddleWall.height / 2
	shapeHeight = paddleWall.height - 20 -- The actual physics body has to have a smaller height in order to account for the image's shadow
	paddleWallPhysicsProp.shape = {-paddleWall.width / 2, -shapeHeight / 2, paddleWall.width / 2, -shapeHeight / 2, paddleWall.width / 2, shapeHeight / 2, -paddleWall.width / 2, shapeHeight / 2 }
	physics.addBody( paddleWall,"static", paddleWallPhysicsProp)
	paddleWallPhysicsProp.shape = nil
	
	-- Bottom paddle wall
	paddleWall = display.newImageRect( "redBar.png", 768, 53 )
	paddleWall.x = bottomRight.x - paddleWall.width / 2
	paddleWall.y = bottomRight.y - paddleWall.height / 2
	shapeHeight = paddleWall.height - 20 -- The actual physics body has to have a smaller height in order to account for the image's shadow
	paddleWallPhysicsProp.shape = {-paddleWall.width / 2, -shapeHeight / 2, paddleWall.width / 2, -shapeHeight / 2, paddleWall.width / 2, shapeHeight / 2, -paddleWall.width / 2, shapeHeight / 2 }
	physics.addBody( paddleWall,"static", paddleWallPhysicsProp)
	paddleWallPhysicsProp.shape = nil
		
	-- Center paddle divider
	paddleWall = display.newRect( topLeft.x, (display.viewableContentHeight / 2) - (paddleWallThickness / 2), display.viewableContentWidth, paddleWallThickness)
	paddleWall:setFillColor(paddleWallColor.r, paddleWallColor.g, paddleWallColor.b, 0) -- We want the user to see the center divider
	physics.addBody( paddleWall,"static", paddleWallPhysicsProp)
	
	-- Left paddle wall
	paddleWall = display.newImageRect( "leftRightWall.png", 45, 1024 )
	paddleWall.x = topLeft.x + paddleWall.width / 2
	paddleWall.y = topLeft.y + paddleWall.height / 2
	shapeWidth = paddleWall.width - 20 -- The actual physics body has to have a smaller width in order to account for the image's shadow
	paddleWallPhysicsProp.shape = {-shapeWidth / 2, -paddleWall.height / 2, shapeWidth / 2, -paddleWall.height / 2, shapeWidth / 2, paddleWall.height / 2, -shapeWidth / 2, paddleWall.height / 2 }
	physics.addBody( paddleWall,"static", paddleWallPhysicsProp)
	paddleWallPhysicsProp.shape = nil
	
	-- Right paddle wall
	paddleWall = display.newImageRect( "leftRightWall.png", 45, 1024 )
	paddleWall.x = bottomRight.x - paddleWall.width / 2
	paddleWall.y = topLeft.y + paddleWall.height / 2
	paddleWall.rotation = 180 -- Flip it 180 degrees so the shadow is in the inside of the table
	shapeWidth = paddleWall.width - 20 -- The actual physics body has to have a smaller width in order to account for the image's shadow
	paddleWallPhysicsProp.shape = {-shapeWidth / 2, -paddleWall.height / 2, shapeWidth / 2, -paddleWall.height / 2, shapeWidth / 2, paddleWall.height / 2, -shapeWidth / 2, paddleWall.height / 2 }
	physics.addBody( paddleWall,"static", paddleWallPhysicsProp)
	paddleWallPhysicsProp.shape = nil
	
end

main()