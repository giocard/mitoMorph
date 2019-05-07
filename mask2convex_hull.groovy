//@ImagePlus imp

// https://gist.github.com/tferr/06137e366b925858db9670f9fb742a9e (24-11-2017)
// Author: Tiago Ferreira
//
// Obtains the 2D Convex Hull ROI from a 2D binary image
// TODO: Use imagej.ops / net.imglib2.roi.geometric.Polygon
import ij.process.ImageProcessor;
import ij.gui.PolygonRoi;


def run(ImageProcessor ip) {

	def x = []
	def y = []

	for (j in 0..ip.getHeight()) {
		for (i in 0..ip.getWidth()) {
			if (ip.getPixel(i,j) != 0) {
				x.add(i)
				y.add(j)
			}
		}
	}

	//cnvx hull
	int n=x.size(), min = 0, ney=0, px, py, h, h2, dx, dy, temp, ax, ay;
	double minangle, th, t, v, zxmi=0;

	temp = x[0]; x[0] = x[min]; x[min] = temp;
	temp = y[0]; y[0] = y[min]; y[min] = temp;
	min = 0;

	for (i=1; i<n; i++) {
		if (y[i] == y[0]) {
			ney ++;
			if (x[i] < x[min]) min = i;
		}
	}
	temp = x[0]; x[0] = x[min]; x[min] = temp;
	temp = y[0]; y[0] = y[min]; y[min] = temp;

	//first point x(0), y(0)
	px = x[0];
	py = y[0];

	min = 0;
	m = -1;
	x[n] = x[min];
	y[n] = y[min];
	if (ney > 0)
		minangle = -1;
	else
		minangle = 0;

	while (min != n+0 ) {
		m = m + 1;
		temp = x[m]; x[m] = x[min]; x[min] = temp;
		temp = y[m]; y[m] = y[min]; y[min] = temp;

		min = n ; //+1
		v = minangle;
		minangle = 360.0;
		h2 = 0;

		for (i = m + 1; i<n+1; i++) {
			dx = x[i] - x[m];
			ax = Math.abs(dx);
			dy = y[i] - y[m];
			ay = Math.abs(dy);

			if (dx == 0 && dy == 0)
				t = 0.0;
			else
				t = (double)dy / (double)(ax + ay);

			if (dx < 0)
				t = 2.0 - t;
			else if (dy < 0)
				t = 4.0 + t;
			th = t * 90.0;

			if (th > v) {
				if (th < minangle) {
					min = i;
					minangle = th;
					h2 = dx * dx + dy * dy;
				} else if (th == minangle) {
					h = dx * dx + dy * dy;
					if (h > h2) {
						min = i;
						h2 = h;
					}
				}
			}
		}

		px = x[min];
		py = y[min];
		zxmi = zxmi + Math.sqrt(h2);
	}
	m++;

	int[] hx = new int[m];// ROI polygon array
	int[] hy = new int[m];

	for (i=0; i<m; i++) {
		hx[i] =  x[i]; // copy to new polygon array
		hy[i] =  y[i];
	}

	imp.setRoi(new PolygonRoi(hx, hy, hx.length, 2)); // roi.POLYGON

}

run(imp.getProcessor());
