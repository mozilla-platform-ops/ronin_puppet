#!/usr/bin/env python3

import yaml
import argparse

# Set up argument parsing
parser = argparse.ArgumentParser(description='Modify YAML file')
parser.add_argument('-p', '--workerPoolID', required=True, help='New workerPoolID')
parser.add_argument('-t', '--workerType', required=True, help='New workerType')
args = parser.parse_args()

file_path = '/etc/start-worker.yml'
# TESTING
file_path='/tmp/start-worker.yml'

# Load the YAML file
with open(file_path, 'r') as file:
    data = yaml.safe_load(file)

# Modify the values
data['provider']['workerPoolID'] = args.workerPoolID
data['workerConfig']['workerType'] = args.workerType

# Write the changes back to the file with 4-space indentation
with open(file_path, 'w') as file:
    yaml.safe_dump(data, file, default_flow_style=False, indent=4)
