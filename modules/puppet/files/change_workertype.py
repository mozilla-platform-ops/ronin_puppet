#!/usr/bin/env python3

import argparse
import json
from pathlib import Path

RUNNER_CONFIG = Path('/etc/start-worker.yml')
WORKER_CONFIG = Path('/home/cltbld/generic-worker.config')


def default_config():
    # Legacy workers also have generated JSON, so prefer their runner config.
    return RUNNER_CONFIG if RUNNER_CONFIG.exists() else WORKER_CONFIG


def change_workertype(file_path, worker_type):
    # Updating in place preserves the credential-bearing file's owner and mode.
    with open(file_path, 'r+') as config:
        content = config.read()
        is_json = content.lstrip().startswith('{')
        if is_json:
            data = json.loads(content)
            data['workerType'] = worker_type
            output = json.dumps(data, indent=4) + '\n'
        else:
            import yaml

            data = yaml.safe_load(content)
            provisioner_id = data['workerConfig']['provisionerId']
            data['provider']['workerPoolID'] = f'{provisioner_id}/{worker_type}'
            data['workerConfig']['workerType'] = worker_type
            output = yaml.safe_dump(data, default_flow_style=False, indent=4)
        config.seek(0)
        config.write(output)
        config.truncate()


def main():
    parser = argparse.ArgumentParser(description='Override the worker type in a runner YAML or worker JSON config')
    parser.add_argument('-t', '--workerType', required=True, help='New workerType')
    parser.add_argument('-f', '--file', type=Path, help='Config path (default: runner YAML if present, otherwise worker JSON)')
    args = parser.parse_args()
    change_workertype(args.file if args.file is not None else default_config(), args.workerType)


if __name__ == '__main__':
    main()
