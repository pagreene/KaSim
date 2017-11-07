"""Tests for kappa_rest module of kappy.

These tests make use of the nosetests package. All methods that begin with
'test_' will automatically be found and run by the nosetests module. 

These can be run two ways. You
can call this file directly as a python script:

$ python test_kappa_rest.py

Or you can use the nosetests module:

$ nosetests test_kappa_rest.py

For more details on using the nosetests tool, see the nosetests documentation.
All commandline arguements are passed to nosetests.
"""

from kappy import File, KappaRest, SimulationParameter
from util import run_example_case, run_nose


def test_example_case():
    """Run a simple example case using kappa_rest."""
    client = KappaRest("http://127.0.0.1:8080", '__test')
    results = run_example_case(client)
    assert len(results), "Simulation didn't do anything."


if __name__ == '__main__':
    #This code will run the test in this file.'
    run_nose(__file__)