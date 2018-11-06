-- Untitled Squid Game
-- by Ash Brent-Carpenter
-- Requires Love2D >=11.0

local inspect = require('lib/inspect')
local util = require('./util')
local states = require('./states')

-- determines whether a squid is in their team's ink
function isSquidInInk(x, y, color)
	local surroundings = state.inkCanvas:newImageData(nil, 1, x-4, y-4, 8, 8)
	local goodCount = 0
	local badCount = 0
	surroundings:mapPixel(function(x2, y2, r, g, b, a)
		if a > 0 then
			if r == color[1]
				and g == color[2]
				and b == color[3]
			then
				goodCount = goodCount + 1
			else
				badCount = badCount + 1
			end
		end
		return r, g, b, a
	end)
	return goodCount > badCount
end

function newProjectile(o)
	o = o or {}
	local splatFreq = 0.1
	return {
		position = o.position or {x=0, y=0},
		direction = o.direction or {x=0, y=1},
		speed = o.speed or 2,
		size = o.size or 4,
		lifetime = o.lifetime or 1,
		color = o.color or {0, 1, 0, 1},
		age = 0,
		splatFreq = splatFreq,
		splatTime = love.math.random(0, splatFreq) -- could just be 0...
	}
end

function newActor(o)
	o = o or {}
	return {
		position = o.position or {x=0, y=0},
		color = o.color or {1, 0, 0, 0.7},
		radius = o.radius or 4
	}
end

-- adds ink to the canvas
function splat(x, y, size, color)
	-- table.insert(state.splats, {position = {x = x, y = y}, radius = size, color = color})
	love.graphics.setCanvas(state.inkCanvas)
		love.graphics.setColor(color)
		love.graphics.circle('fill', x, y, size)
	love.graphics.setCanvas()
end

function trycall(f, ...)
	if f then f(...) end
end

state = {}
function loadState(name)
	local s = states[name]
	state = s
	trycall(s.load)
end

function love.load()
	loadState('menu')
end

-- state passthroughs
function love.update(dt)
	trycall(state.update, dt)
end

function love.draw()
	trycall(state.draw)
end

function love.keypressed(key, scancode, isrepeat)
	trycall(state.keypressed, key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
	if key == 'escape' then
		love.event.quit()
	else
		trycall(state.keyreleased, key, scancode)
	end
end

function love.gamepadpressed(joystick, button)
	trycall(state.gamepadpressed, joystick, button)
end
