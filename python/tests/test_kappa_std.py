"""Tests for kappa_std module of kappy.

These tests make use of the nosetests package. These can be run two ways. You
can call this file directly as a python script:

$ python test_kappa_std.py

Or you can use the nosetests module:

$ nosetests test_kappa_std.py

For more details on using the nosetests tool, see the nosetests documentation.

All arguements are passed to nosetests.
"""

from kappy import File, KappaStd, SimulationParameter
from util import run_example_case, run_nose


def test_example_case():
    """Run a simple example case using kappa_std."""
    client = KappaStd()
    results = run_example_case(client)
    assert len(results), "Simulation didn't do anything."


if __name__ == '__main__':
    #This code will run the test in this file.'
    run_nose(__file__)