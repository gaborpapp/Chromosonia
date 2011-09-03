#!/usr/bin/env monkeyrunner

from com.android.monkeyrunner import MonkeyRunner, MonkeyDevice, MonkeyImage	
import os, time

def shazam(snap_path):
	sleep_seconds = 24
	print "Using shazam on android by monkeyrunner."
	print "Path for the screenshot:", snap_path
	print "Waiting for device to connect for 5 seconds..."
	dev = MonkeyRunner.waitForConnection(5)
	print "pressing back button..", dev
	dev.press("KEYCODE_BACK","DOWN_AND_UP","dummy-param")
	pack_act = 'com.shazam.android/com.shazam.android.Tagging'
	print "Starting package/activity:", pack_act 
	dev.startActivity(component=pack_act)
	print "sleeping %s seconds" % sleep_seconds
	MonkeyRunner.sleep(sleep_seconds)
	print "Taking screenshot.."
	img = dev.takeSnapshot()
	print "Writing image to ", snap_path 
	img.writeToFile(snap_path)
	print "pressing back button.."
	dev.press("KEYCODE_BACK","DOWN_AND_UP","dummy-param")
	print "finished"
	
def ocr(snap_filename):
	basename = snap_filename[:snap_filename.rfind('.')]
	tif_filename = basename + '.tif'
	ocr_filename = basename + '.txt'
	os.system('convert %s -crop 320x60+0+55 %s' % (snap_filename, tif_filename))
	os.system('tesseract %s %s' % (tif_filename, basename))
	f = open(ocr_filename)
	lines = f.readlines()
	artist = ''
	song = ''
	for l in lines:
		l = l.strip()
		if not l:
			continue;
		if l in ['Sending', 'Matching', '-1115']:
			artist = ''
			song == ''
			break
		if not song:
			song = l
		else:
			artist = l
	print 'Artist:', artist
	print 'Title:', song

if __name__ == '__main__':
	snap_filename = 'snaps/snap-' + time.strftime('%y%m%d%H%M%S') + '.png'
	try:
		shazam(snap_filename)
	except:
		pass
	try:
		ocr(snap_filename)
	except:
		pass

