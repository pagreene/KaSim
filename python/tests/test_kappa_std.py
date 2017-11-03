"""Tests for kappa_std module of kappy.

These tests make use of the nosetests package. These can be run two ways. You
can call this file directly as a python script:

$ python test_kappa_std.py

Or you can use the nosetests module:

$ nosetests test_kappa_std.py

For more details on using the nosetests tool, see the nosetests documentation.

All arguements are passed to nosetests.
"""

import kappy

TEST_MODEL = ("%agent: A(x)\n A(x), A(x) <-> A(x!1), A(x!1) @ 1e-2, 1\n "
              "%init: 100 A()\n %plot: |A(x)|")

def test_example_case():
    """Run a simple example case using kappa_std."""
    client = kappy.KappaStd()
    model = kappy.File.from_string(TEST_MODEL)
    client.file_create(model)
    client.project_parse()
    param = kappy.SimulationParameter(0.1, '[T]>100')
    client.simulation_start(param)
    results = client.simulation_plot()
    assert len(results), "Simulation didn't do anything."

if __name__ == '__main__':
    #This code will run the test in this file.'
    import nose

    module_name = sys.modules[__name__].__file__
    print("Running nose for package: %s" % module_name)

    result = nose.run(argv=[sys.argv[0], module_name] + sys.argv[1:])