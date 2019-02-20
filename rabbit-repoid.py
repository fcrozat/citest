#! /usr/bin/python

from __future__ import print_function

import argparse
import datetime
import json
import logging
import os.path

import osc
from osc.core import http_GET, makeurl

from osclib.core import target_archs
from lxml import etree as ET

from PubSubConsumer import PubSubConsumer


class Listener(PubSubConsumer):
    def __init__(self, apiurl, amqp_prefix, namespaces):
        super(Listener, self).__init__(amqp_prefix, logging.getLogger(__name__))
        self.apiurl = apiurl
        self.amqp_prefix = amqp_prefix
        self.timer_id = None
        self.namespaces = namespaces

    def routing_keys(self):
        return [self.amqp_prefix + '.obs.repo.build_finished']

    def restart_timer(self):
        interval = 120
        if self.timer_id:
            self._connection.remove_timeout(self.timer_id)
        else:
            # check the initial state on first timer hit
            # so be quick about it
            interval = 0
        self.timer_id = self._connection.add_timeout(
            interval, self.still_alive)

    def still_alive(self):
        # output something so gocd doesn't consider it stalled
        print('Still alive: {}'.format(datetime.datetime.now().time()))
        self.restart_timer()

    def check_arch(self, project, repository, architecture):
        url = makeurl(self.apiurl, [
                      'build', project, repository, architecture], {'view': 'status'})
        root = ET.parse(http_GET(url)).getroot()
        if root.get('code') == 'finished':
            return root.find('buildid').text

    def check_all_archs(self, project, repository):
        ids = {}
        archs = target_archs(self.apiurl, project, repository)
        for arch in archs:
            repoid = self.check_arch(project, repository, arch)
            if not repoid:
                print('Arch', arch, 'not yet done')
                return None
            ids[arch] = repoid
        print('All architectures finished')
        return ids

    def start_consuming(self):
        self.restart_timer()
        super(Listener, self).start_consuming()

    def is_part_of_namespaces(self, project):
        for namespace in self.namespaces:
            if project.startswith(namespace):
                return True

    def on_message(self, unused_channel, method, properties, body):
        try:
            body = json.loads(body)
        except ValueError:
            return
        if method.routing_key.endswith('.obs.repo.build_finished'):
            if not self.is_part_of_namespaces(body['project']):
                return
            self.restart_timer()
            print('Repo finished event: {}/{}/{}'.format(body['project'], body['repo'], body['arch']))
            ids = self.check_all_archs(body['project'], body['repo'])
            if not ids:
                return
            pathname = os.path.join('stagings', body['project'] + '-' + body['repo'] + '.yaml')
            with open(pathname, 'w') as f:
                for arch in sorted(ids.keys()):
                    f.write('{}: {}\n'.format(arch, ids[arch]))
            os.system('git add .')
            os.system('git commit -m "Repository finished: {}/{}"'.format(body['project'], body['repo']))
            os.system('git push')
        else:
            self.logger.warning(
                'unknown rabbitmq message {}'.format(method.routing_key))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Bot to sync openQA status to OBS')
    parser.add_argument('--apiurl', '-A', type=str, help='API URL of OBS')
    parser.add_argument('-d', '--debug', action='store_true', default=False,
                        help='enable debug information')
    parser.add_argument('namespaces', nargs='*', help='namespaces to wait for')

    args = parser.parse_args()

    osc.conf.get_config(override_apiurl=args.apiurl)
    osc.conf.config['debug'] = args.debug

    apiurl = osc.conf.config['apiurl']

    if apiurl.endswith('suse.de'):
        amqp_prefix = 'suse'
    else:
        amqp_prefix = 'opensuse'

    logging.basicConfig(level=logging.WARN)

    listener = Listener(apiurl, amqp_prefix, args.namespaces)

    try:
        listener.run()
        listener.check_failures()
    except KeyboardInterrupt:
        listener.stop()
