#!/usr/bin/env python
from pprint import pprint
import sys
import os
import logging
from logging import critical, error, info, warning, debug
import subprocess

CWORKING = '\033[34;1m'
# The 'color' we use to reset the colors
CRESET = '\033[0m'
# CRESET=$(tput sgr0 -T "${TERM}")
# bold, duh
CBOLD = '\033[1;96m'
# color we use for informational messages
CINFO = '\033[1;33m'
# color we use for warnings
CWARN = '\033[1;31m'
logging.basicConfig(format='%(message)s', level=logging.DEBUG, stream=sys.stdout)
logging.addLevelName(logging.WARNING, "%s%s%s" % (CWARN, logging.getLevelName(logging.WARNING), CRESET))
logging.addLevelName(logging.ERROR, "%s%s%s" % (CWARN, logging.getLevelName(logging.ERROR), CRESET))


def outputError(cmd, output):
	logging.warning("{}{}{}{} command failed!".format(CBOLD, cmd, CRESET, CWARN))
	logging.info("See the following output:")
	logging.info(output)
	# @todo exit seems... dirty?
	#sys.exit("See previous error above")
	return False

def main():
	"""

	:return:
	"""
	updaters = {
		'composer.json': {'command': 'composer update', 'lock': 'composer.lock'},
		'Pipfile': {'command': 'pipenv update', 'lock': 'Pipfile.lock'},
		'Gemfile': {'command': 'bundle update', 'lock': 'Gemfile.lock'},
		'go.mod': {'command': 'go get -u all', 'lock': 'go.sum'},
		'package-lock.json': {'command': 'npm update', 'lock': 'package-lock.json'},
		'yarn.lock': {'command': 'yarn upgrade', 'lock': ''}
	}

	# pprint(updaters)
	# get the app to our app
	appPath = os.getenv('PLATFORM_APP_DIR')
	# grab the list of files in the app root
	# @todo for now this only supports single apps. we'll need to build in multiapp support
	appfiles = [file for file in os.listdir(appPath) if os.path.isfile(file)]

	updateFiles = [value for value in updaters if value in appfiles]

	actions = []
	doCommit = False
	for file in updateFiles:
		action = updaters[file]
		# @todo later this needs to be updated to the *relative* directory location where we find the file
		action['path'] = './'
		actions += [action]

	logging.info("Beginning update process...")

	for action in actions:
		logging.info("Running {}".format(action['command']))
		# run the update process
		procUpdate = subprocess.Popen(action['command'], shell=True, cwd=action['path'], stdout=subprocess.PIPE,
									  stderr=subprocess.PIPE)
		output, error = procUpdate.communicate()
		if 0 != procUpdate.returncode:
			outputError(action['command'],error)
		# now let's see if we have updates
		output = error = None
		procStatus = subprocess.Popen('git status --porcelain=1', shell=True, cwd=appPath, stdout=subprocess.PIPE,
									  stderr=subprocess.PIPE)
		output, error = procStatus.communicate()
		if 0 != procStatus.returncode:
			return outputError('git status', error)
		elif "" == output:
			# no updates so nothing to add
			return;

		# one more, just need to add the file
		output = error = None
		procAdd = subprocess.Popen('git add {}{}'.format(action['path'], action['lock']), shell=True, cwd=appPath,
								   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		output, error = procAdd.communitcate()
		if 0 != procAdd.returncode:
			return outputError('git add', error)
		else:
			output = error = None
			doCommit=True

	if doCommit:
		# @todo should this message be configurable?
		message="Auto dependency updates via source operation"
		cmd='composer commit -m "{}"'.format(message)
		procCommit=subprocess.Popen(cmd, shell=True, cwd=appPath, stdout=subprocess.PIPE,
									  stderr=subprocess.PIPE)
		output, error = procCommit.communicate()

		if 0 != procCommit.returncode:
			return outputError('git commit', error)
		else:
			return true

if __name__ == '__main__':
	main()
