-- Mirrors assets/ui/fish-skeleton.svg in a 120 x 72 canvas.
-- Path2D tangents are offsets from each knot, not absolute control points.
-- Stroke-only geometry keeps every interior transparent and needs no asset download.
return {
	width = 120,
	height = 72,
	paths = {
		{
			name = "Tail",
			thickness = 2.6,
			closed = true,
			points = {
				{ x = 24, y = 44, leftx = -4, lefty = 5, rightx = -5, righty = -1 },
				{ x = 7, y = 34, leftx = 6, lefty = 2, rightx = 0, righty = 0 },
				{ x = 11, y = 45, leftx = 0, lefty = 0, rightx = 0, righty = 0 },
				{ x = 7, y = 57, leftx = 0, lefty = 0, rightx = 7, righty = -2 },
			},
		},
		{
			name = "Backbone",
			thickness = 2.6,
			closed = false,
			points = {
				{ x = 24, y = 44, leftx = 0, lefty = 0, rightx = 18, righty = 5 },
				{ x = 88, y = 29, leftx = -30, lefty = -2, rightx = 0, righty = 0 },
			},
		},
		{
			name = "Rib1Upper",
			thickness = 2.3,
			closed = false,
			points = {
				{ x = 32.02, y = 44.6, leftx = 0, lefty = 0, rightx = -2.22, righty = -2.8 },
				{ x = 30.4, y = 34.3, leftx = -1.4, lefty = 3.5, rightx = 0, righty = 0 },
			},
		},
		{
			name = "Rib1Lower",
			thickness = 2.3,
			closed = false,
			points = {
				{ x = 32.02, y = 44.6, leftx = 0, lefty = 0, rightx = 0.48, righty = 4.4 },
				{ x = 39, y = 53.8, leftx = -3.7, lefty = -1.2, rightx = 0, righty = 0 },
			},
		},
		{
			name = "Rib2Upper",
			thickness = 2.3,
			closed = false,
			points = {
				{ x = 41.19, y = 42.18, leftx = 0, lefty = 0, rightx = -3.69, righty = -3.88 },
				{ x = 36, y = 26.8, leftx = -0.9, lefty = 4.9, rightx = 0, righty = 0 },
			},
		},
		{
			name = "Rib2Lower",
			thickness = 2.3,
			closed = false,
			points = {
				{ x = 41.19, y = 42.18, leftx = 0, lefty = 0, rightx = 0.91, righty = 6.02 },
				{ x = 52.6, y = 55.2, leftx = -5.4, lefty = -1.2, rightx = 0, righty = 0 },
			},
		},
		{
			name = "Rib3Upper",
			thickness = 2.3,
			closed = false,
			points = {
				{ x = 50.9, y = 37.9, leftx = 0, lefty = 0, rightx = -4.4, righty = -4.5 },
				{ x = 46.3, y = 20.1, leftx = -1.9, lefty = 5.1, rightx = 0, righty = 0 },
			},
		},
		{
			name = "Rib3Lower",
			thickness = 2.3,
			closed = false,
			points = {
				{ x = 50.9, y = 37.9, leftx = 0, lefty = 0, rightx = 2.2, righty = 6.5 },
				{ x = 66, y = 50.6, leftx = -6, lefty = -0.5, rightx = 0, righty = 0 },
			},
		},
		{
			name = "Rib4Upper",
			thickness = 2.3,
			closed = false,
			points = {
				{ x = 61.63, y = 33.28, leftx = 0, lefty = 0, rightx = -4.83, righty = -4.38 },
				{ x = 57.1, y = 15.8, leftx = -2.6, lefty = 5.3, rightx = 0, righty = 0 },
			},
		},
		{
			name = "Rib4Lower",
			thickness = 2.3,
			closed = false,
			points = {
				{ x = 61.63, y = 33.28, leftx = 0, lefty = 0, rightx = 3.37, righty = 6.42 },
				{ x = 78.2, y = 44.6, leftx = -5.7, lefty = 0.2, rightx = 0, righty = 0 },
			},
		},
		{
			name = "Rib5Upper",
			thickness = 2.3,
			closed = false,
			points = {
				{ x = 72.31, y = 30.11, leftx = 0, lefty = 0, rightx = -4.21, righty = -3.81 },
				{ x = 69.7, y = 16.4, leftx = -3.2, lefty = 3.9, rightx = 0, righty = 0 },
			},
		},
		{
			name = "Rib5Lower",
			thickness = 2.3,
			closed = false,
			points = {
				{ x = 72.31, y = 30.11, leftx = 0, lefty = 0, rightx = 3.09, righty = 5.19 },
				{ x = 87, y = 37.2, leftx = -5.5, lefty = 1.4, rightx = 0, righty = 0 },
			},
		},
		{
			name = "Skull",
			thickness = 2.5,
			closed = true,
			points = {
				{ x = 88, y = 29, leftx = 0, lefty = 2, rightx = 2, righty = -8 },
				{ x = 103, y = 19, leftx = -7, lefty = -2, rightx = 6, righty = 2 },
				{ x = 114, y = 29, leftx = -1, lefty = -4, rightx = 0, righty = 0 },
				{ x = 107, y = 30, leftx = 0, lefty = 0, rightx = 0, righty = 0 },
				{ x = 112, y = 35, leftx = 0, lefty = 0, rightx = -7, righty = 4 },
				{ x = 89, y = 35, leftx = 8, lefty = 5, rightx = -1, righty = -2 },
			},
		},
		{
			name = "Eye",
			thickness = 1.8,
			closed = true,
			points = {
				{ x = 103.5, y = 26, leftx = 0, lefty = -1.38, rightx = 0, righty = 1.38 },
				{ x = 101, y = 28.5, leftx = 1.38, lefty = 0, rightx = -1.38, righty = 0 },
				{ x = 98.5, y = 26, leftx = 0, lefty = 1.38, rightx = 0, righty = -1.38 },
				{ x = 101, y = 23.5, leftx = -1.38, lefty = 0, rightx = 1.38, righty = 0 },
			},
		},
	},
}
