"""Useful tools for running tests.
"""

import sys
import os

TEST_MODEL = ("%agent: A(x)\n A(x), A(x) <-> A(x!1), A(x!1) @ 1e-2, 1\n "
              "%init: 100 A()\n %plot: |A(x)|")


def run_example_case(client):
    """Run a simple example case using the given client."""
    model = File.from_string(TEST_MODEL)
    client.file_create(model)
    client.project_parse()
    param = SimulationParameter(0.1, '[T]>100')
    client.simulation_start(param)
    return client.simulation_plot()


def run_nose(fname):
    import nose
    fpath = os.path.abspath(fname)
    print("Running nose for package: %s" % fname)
    return nose.run(argv=[sys.argv[0], fpath] + sys.argv[1:])