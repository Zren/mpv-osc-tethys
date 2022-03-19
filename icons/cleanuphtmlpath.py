import re
import subprocess
import os

moveToPattern = re.compile(r'\tctx.moveTo\((-?\d+\.\d+), (-?\d+\.\d+)\);')
lineToPattern = re.compile(r'\tctx.lineTo\((-?\d+\.\d+), (-?\d+\.\d+)\);')
curveToPattern = re.compile(r'\tctx.bezierCurveTo\((-?\d+\.\d+), (-?\d+\.\d+), (-?\d+\.\d+), (-?\d+\.\d+), (-?\d+\.\d+), (-?\d+\.\d+)\);')

def convertToCanvas(svgFilepath):
	svgDirpath, svgFilename = os.path.split(svgFilepath)
	htmlDirpath = os.path.join(svgDirpath, 'html')
	htmlFilepath = os.path.join(htmlDirpath, svgFilename.replace('.svg', '.html'))
	os.makedirs(htmlDirpath, exist_ok=True)
	subprocess.run([
		'inkscape',
		svgFilepath,
		'-o',
		htmlFilepath,
	])
	return htmlFilepath



def cleanNum(numstr):
	outstr = str(float(numstr))
	if outstr.endswith('.0'):
		outstr = outstr[:-2]
	return outstr

def generatePath(filepath):
	path = []
	with open(filepath, 'r') as fin:
		for line in fin.readlines():
			line = line.rstrip()
			# print(line)
			m = moveToPattern.match(line)
			if m:
				x = cleanNum(m.group(1))
				y = cleanNum(m.group(2))
				cmd = 'm {} {}'.format(x, y)
				# print('moveTo', cmd)
				path.append(cmd)
				continue
			m = lineToPattern.match(line)
			if m:
				x = cleanNum(m.group(1))
				y = cleanNum(m.group(2))
				cmd = 'l {} {}'.format(x, y)
				# print('lineTo', cmd)
				path.append(cmd)
				continue
			m = curveToPattern.match(line)
			if m:
				x1 = cleanNum(m.group(1))
				y1 = cleanNum(m.group(2))
				x2 = cleanNum(m.group(3))
				y2 = cleanNum(m.group(4))
				x = cleanNum(m.group(5))
				y = cleanNum(m.group(6))
				cmd = 'b {} {} {} {} {} {}'.format(x1, y1, x2, y2, x, y)
				# print('curveTo', cmd)
				path.append(cmd)
				continue
	return '   '.join(path)


def printIcon(name, htmlFilename):
	path = generatePath(htmlFilename)
	print(r'local ' + name + r' = "{\\c&HC0C0C0&\\p1}' + path + r'{\\p0}"')

def genIconPath(name, svgFilepath):
	htmlFilepath = convertToCanvas(svgFilepath)
	printIcon(name, htmlFilepath)

print('-- 44x44')
genIconPath('tethys_icon_play', 'tethys_play.svg')
genIconPath('tethys_icon_pause', 'tethys_pause.svg')
print()
print('-- 28x28')
genIconPath('tethys_icon_skipback', 'tethys_skipback.svg')
genIconPath('tethys_icon_skipfrwd', 'tethys_skipfrwd.svg')
genIconPath('tethys_ch_prev', 'tethys_ch_prev.svg')
genIconPath('tethys_ch_next', 'tethys_ch_next.svg')
genIconPath('tethys_pl_prev', 'tethys_pl_prev.svg')
genIconPath('tethys_pl_next', 'tethys_pl_next.svg')
