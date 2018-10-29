local module = {}

-- bounding-box collision
function module.checkCollision(x1,y1,w1,h1, x2,y2,w2,h2)
  return x1 < x2+w2 and
         x2 < x1+w1 and
         y1 < y2+h2 and
         y2 < y1+h1
end

function module.pointInsideCircle(px, py, rx, ry, r)
	local dx = px - rx
	local dy = py - ry
	return (dx * dx) + (dy * dy) <= (r * r)
end

function module.circlesIntersect(x1, y1, r1, x2, y2, r2)
	local dx = x1 - x2
	local dy = y1 - y2
	local sr = r1 + r2
	return (dx * dx) + (dy * dy) <= (sr * sr)
end

return module

