#!/usr/bin/env python3

import yaml
import argparse

# Set up argument parsing
parser = argparse.ArgumentParser(description='Modify YAML file')
parser.add_argument('-t', '--workerType', required=True, help='New workerType')
parser.add_argument('-f', '--file', default='/etc/start-worker.yml', help='Path to the YAML file')
args = parser.parse_args()

file_path = args.file

# Load the YAML file
with open(file_path, 'r') as file:
    data = yaml.safe_load(file)

# Build the new workerPoolID
provisioner_id = data['workerConfig']['provisionerId']
worker_pool_id = f"{provisioner_id}/{args.workerType}"

# Modify the values
data['provider']['workerPoolID'] = worker_pool_id
data['workerConfig']['workerType'] = args.workerType

# Write the changes back to the file with 4-space indentation
with open(file_path, 'w') as file:
    yaml.safe_dump(data, file, default_flow_style=False, indent=4)
