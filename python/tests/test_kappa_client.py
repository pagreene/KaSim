"""Integration test for kappa clients"""
import json
import unittest
import random
import string
import time
import uuid

from os.path import dirname, join, normpath, pardir, basename, abspath
from subprocess import Popen

import kappy
from util import run_nose

KASIM_DIR = normpath(join(dirname(abspath(__file__)), *([pardir]*2)))
assert basename(KASIM_DIR) == 'KaSim', "%s is not KaSim directory." % KASIM_DIR
MODEL_DIR = join(KASIM_DIR, 'models')


def _get_test_file(fname):
    return join(MODEL_DIR, "test_suite", "compiler", "file_order", fname)


def _get_id(name):
    return "%s-%s" % (name, uuid.uuid1())


def _create_runtime_file(runtime, file_name, data):
    file_id = _get_id(file_name)
    file_obj = kappy.File(dict(id=file_id, position=0), data)
    runtime.file_create(file_obj)
    return file_id, file_obj


class _KappaClientTest(unittest.TestCase):

    def test_file_crud(self):
        print("Getting the runtime object...")
        runtime = self.getRuntime(project_id=_get_id('test_proj'))

        print("Creating the file...")
        empty_content = ""
        file_id, _ = _create_runtime_file(runtime, _get_id('test_file'),
                                          empty_content)

        print("Getting the file names")
        file_names = [entry.id for entry in runtime.file_info()]

        print("Running checks...")
        self.assertIn(file_id, file_names)
        self.assertEqual(runtime.file_get(file_id).get_content(), empty_content)
        runtime.file_delete(file_id)
        try:
            runtime.file_delete(file_id)
            self.fail()
        except kappy.KappaError:
            pass

    def test_parse_multiple_files(self):
        runtime = self.getRuntime(project_id=_get_id('test_proj'))
        with open(_get_test_file('file2.ka'), 'r') as f2:
            f2_str = f2.read()
        with open(_get_test_file('file1.ka'), 'r') as f1:
            f1_str = f1.read()

        file_1_id, _ = _create_runtime_file(runtime, 'test_file_1', f1_str)
        file_2_id, file_2_obj = _create_runtime_file(runtime, 'test_file_2',
                                                     f2_str)

        runtime.project_parse()
        with self.assertRaises(kappy.KappaError):
            runtime.file_create(file_2_obj)
        file_names = [entry.id for entry in runtime.file_info()]
        self.assertIn(file_1_id,file_names)
        self.assertIn(file_2_id,file_names)
        return

    def test_run_simulation(self):
        project_id = str(uuid.uuid1())
        runtime = self.getRuntime(project_id)
        file_id = str(uuid.uuid1())
        with open("../models/abc-pert.ka") as kappa_file:
            data = kappa_file.read()
            file_content = str(data)
            file_metadata = kappy.FileMetadata(file_id,0)
            file_object = kappy.File(file_metadata,file_content)
            runtime.file_create(file_object)
            runtime.project_parse()
            pause_condition = "[T] > 10.0"
            simulation_parameter = kappy.SimulationParameter(0.1,pause_condition)
            runtime.simulation_start(simulation_parameter)

            simulation_info = runtime.simulation_info()

            while simulation_info["simulation_info_progress"]["simulation_progress_is_running"] :
                time.sleep(1)
                simulation_info = runtime.simulation_info()

            # test that no limit returns all entries
            last_status = runtime.simulation_plot()
            test_count = 101
            self.assertEqual(test_count, len(last_status['series']))

            print(simulation_info)
            plot_limit_offset = 100
            test_time = 10.0
            test_count = 1
            limit = kappy.PlotLimit(plot_limit_offset)
            last_status = runtime.simulation_plot(limit)
            self.assertEqual(test_count, len(last_status['series']))
            self.assertEqual(test_time, last_status['series'][0][0])

            plot_limit_offset = 10
            plot_limit_points = 1
            test_time = 1.0
            test_count = 1
            limit = kappy.PlotLimit(plot_limit_offset,plot_limit_points)
            last_status = runtime.simulation_plot(limit)
            self.assertEqual(test_count, len(last_status['series']))
            self.assertEqual(test_time, last_status['series'][0][0])

            plot_limit_offset = 50
            test_time = 10.0
            test_count = 51
            limit = kappy.PlotLimit(plot_limit_offset)
            last_status = runtime.simulation_plot(limit)
            self.assertEqual(test_count, len(last_status['series']))
            self.assertEqual(test_time, last_status['series'][0][0])

            runtime.simulation_continue("[T] > 35")

            simulation_info = runtime.simulation_info()

            while simulation_info["simulation_info_progress"]["simulation_progress_is_running"] :
                time.sleep(1)
                simulation_info = runtime.simulation_info()

            # test that no limit returns all entries
            last_status = runtime.simulation_plot()
            self.assertEqual(351, len(last_status['series']))


class RestClientTest(_KappaClientTest):
    """ Integration test for kappa client"""

    def __init__(self, *args, **kwargs):
        """ initalize test by launching kappa server """
        self.websim = join(KASIM_DIR, "bin", "WebSim")
        self.key = self.generate_key()
        self.port = 6666
        self.endpoint = "http://127.0.0.1:%s" % self.port
        super(RestClientTest, self).__init__(*args, **kwargs)

    def setUp(self):
        """ set up unit test by launching client"""
        print("Starting server...")
        Popen([
            self.websim,
            '--shutdown-key', self.key,
            '--port', str(self.port),
            '--level', 'fatal'
            ])
        time.sleep(1)
        print("Started...")
        return

    def getRuntime(self, project_id):
        return kappy.KappaRest(self.endpoint, project_id)

    def tearDown(self):
        """ tear down test by shutting down"""
        runtime = self.getRuntime("__foo")
        print("Closing server...")
        resp = runtime.shutdown(self.key)
        print("Closed", resp)
        time.sleep(1)

    @classmethod
    def generate_key(cls):
        """ generate random key for kappa server. """
        return ''.join(random.
                       SystemRandom().
                       choice(string.ascii_uppercase + string.digits)
                       for _ in range(100))

    def test_info(self):
        """Check if the server can return information about the service."""
        project_id = str(uuid.uuid1())
        runtime = self.getRuntime(project_id)
        info = runtime.get_info()
        self.assertIsNotNone('environment_projects' in info)
        self.assertIsNotNone('environment_build' in info)


class StdClientTest(_KappaClientTest):
    """ Integration test for kappa client"""

    def getRuntime(self, project_id):
        return kappy.KappaStd()

    def tearDown(self):
        """ tear down test by shutting down"""
        runtime = self.getRuntime("__foo")
        resp = runtime.shutdown()
        print(resp)
        return


if __name__ == '__main__':
    run_nose(__file__)
