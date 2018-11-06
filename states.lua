local util = require('util')

states = {
	menu = {
		load = function()
			-- temp
			loadState('interim')
		end,
		update = function(dt) end,
		draw = function()
			love.graphics.print('Paint Game', 10, 10)
			love.graphics.print('Press Any Button', 10, 20)
		end,
		gamepadpressed = function(joystick, button)
			if button == 'start' or true then
				loadState('interim')
			end
		end
	},
	interim = {
		load = function()
			state.age = 0
			state.icon = love.graphics.newImage('pad.png')
		end,
		update = function(dt)
			state.age = state.age + dt
			if state.age > 1 then loadState('game') end
		end,
		draw = function()
			love.graphics.draw(state.icon, 0, 0)
		end
	},
	game = {
		load = function()
			local gamera = require('lib/gamera')
			state.cam = gamera.new(0, 0, 2048, 2048)
			love.graphics.setDefaultFilter('nearest', 'nearest')
			state.cam:setScale(3)
			state.cam:setPosition(256, 512)

			state.age = 0

			state.player = { x = 256, y = 512, aimx = 0, aimy = 0}
			state.player.color = {0, 1, 0, 1}
			state.player.isSquid = false
			state.player.size = 8

			state.player.shootTimer = 0
			state.player.shootMax = 0.1 -- seconds

			state.sprites = {}
			state.sprites.reticle = love.graphics.newImage('reticle.png')
			state.sprites.level = love.graphics.newImage('level.png')
			state.projectiles = {}
			state.actors = {}
			state.inkCanvas = love.graphics.newCanvas(2048, 2048)

			-- make some NPCs
			local squid1 = newActor()
			squid1.position = {
				x = state.player.x + 32,
				y = state.player.y
			}
			table.insert(state.actors, squid1)
			for i = 0, 64, 1 do
				local a = newActor()
				a.position = {
					x = love.math.random(0, 2048),
					y = love.math.random(0, 2048)
				}
				table.insert(state.actors, a)
			end

			love.joystick.loadGamepadMappings('lib/gamepad.mappings')
			deadzone = 0.1
			speed = 2

			state.music = love.audio.newSource('music1.1.wav', 'stream')
			love.audio.play(state.music)
		end,
		update = function(dt)
			state.age = state.age + dt
			for i, j in ipairs(love.joystick.getJoysticks()) do
				local dx, dy, l2, aimx, aimy, r2 = j:getAxes()

				state.player.isSquid = (l2 > 0)

				-- movement
				if -deadzone < dx and dx < deadzone then
					dx = 0
				end
				if -deadzone < dy and dy < deadzone then
					dy = 0
				end
				-- normalise
				local mag = math.sqrt((dx * dx) + (dy * dy))
				if mag ~= 0 then
					dx = dx / mag
					dy = dy / mag
				end
				local squidSpeed = state.player.isSquid
					and (
						isSquidInInk(state.player.x,
						state.player.y, state.player.color)
						and 2
						or 0.5
					)
					or 1
				dx = dx * speed * squidSpeed
				dy = dy * speed * squidSpeed
				local newx = state.player.x + dx
				local newy = state.player.y + dy

				local canMove = true
				for i, v in ipairs(state.actors) do
					if util.circlesIntersect(
						newx, newy,
						state.player.size,
						v.position.x, v.position.y,
						v.radius
					) then canMove = false end
				end
				if canMove then
					if newx ~= state.player.x or newy ~= state.player.y then
						state.cam:setPosition(newx, newy)
					end
					state.player.x = newx
					state.player.y = newy
				end

				if -deadzone < aimx and aimx < deadzone then
					aimx = 0
				end
				if -deadzone < aimy and aimy < deadzone then
					aimy = 0
				end
				-- create a unit vector in aim direction
				mag = math.sqrt((aimx * aimx) + (aimy * aimy))
				if mag > 0 then
					state.player.aimx = aimx / mag
					state.player.aimy = aimy / mag
				end
				-- shooting
				state.player.shootTimer = state.player.shootTimer + dt
				if (not state.player.isSquid) and r2 > 0 and state.player.shootTimer > state.player.shootMax then
					state.player.shootTimer = 0
					local proj = newProjectile({
						position = {
							x = state.player.x + state.player.aimx*16,
							y = state.player.y + state.player.aimy*16
						},
						direction = {x=state.player.aimx, y=state.player.aimy},
					})
					table.insert(state.projectiles, proj)
				end
			end

			-- move and age projectiles
			local projectilesToKill = {}
			for i, v in ipairs(state.projectiles) do
				v.age = v.age + dt
				v.splatTime = v.splatTime + dt
				if v.splatFreq <= v.splatTime then
					splat(v.position.x, v.position.y, v.size, v.color)
					v.splatTime = 0
				end
				if v.lifetime <= v.age then
					-- mark for removal
					table.insert(projectilesToKill, i)
				else
					v.position.x = v.position.x + (v.direction.x * v.speed)
					v.position.y = v.position.y + (v.direction.y * v.speed)
				end
			end
			-- handle collisions
			local actorsToKill = {}
			for i, proj in ipairs(state.projectiles) do
				for j, actor in ipairs(state.actors) do
					if util.pointInsideCircle(
						proj.position.x, proj.position.y,
						actor.position.x, actor.position.y,
						actor.radius
					) then
						-- hit detected...
						-- for now just kill
						splat(
							actor.position.x, actor.position.y,
							6, proj.color
						)
						table.insert(actorsToKill, j)
					end
				end
			end
			-- remove stuff
			-- we can't do this inside earlier loops
			-- note that "v" here is actually the object's index
			for i, v in ipairs(projectilesToKill) do
				table.remove(state.projectiles, v)
			end
			for i, v in ipairs(actorsToKill) do
				table.remove(state.actors, v)
			end
		end,
		draw = function()
			state.cam:draw(function(left, top, width, height)
				-- level
				love.graphics.setColor(1, 1, 1, 1)
				love.graphics.draw(state.sprites.level, 0, 0)

				love.graphics.draw(state.inkCanvas, 0, 0)

				-- player
				love.graphics.setColor(state.player.color)
				love.graphics.circle(
					'fill',
					state.player.x,
					state.player.y,
					state.player.size
				)

				-- outline circle in white
				if not state.player.isSquid then
					love.graphics.setColor(1, 1, 1, 1)
					love.graphics.circle(
						'line',
						state.player.x,
						state.player.y,
						state.player.size
					)
				end

				-- mobs
				for i, v in ipairs(state.actors) do
					love.graphics.setColor(v.color)
					love.graphics.circle(
						'fill',
						v.position.x,
						v.position.y,
						v.radius
					)
				end

				-- reticle
				love.graphics.setColor(1,1,1,1)
				love.graphics.draw(
					state.sprites.reticle,
					state.player.x - 4 + (state.player.aimx * 16),
					state.player.y - 4 + (state.player.aimy * 16)
				)

				-- projectiles
				for i, v in ipairs(state.projectiles) do
					love.graphics.setColor(v.color)
					love.graphics.circle('fill', v.position.x, v.position.y, v.size)
				end
			end)
		end,
		gamepadpressed = function(joystick, button)
			print(isSquidInInk(state.player.x, state.player.y, state.player.color))
		end
	}
}

return states
