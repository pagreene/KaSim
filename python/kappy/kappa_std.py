"""
Client for the kappa programming language through standard channel api
"""

__all__ = ['KappaStd']

import subprocess
import threading
import json
from os.path import join
import abc
from pkg_resources import resource_filename

from kappy.kappa_common import KappaError, PlotLimit, FileMetadata, File


class KappaStd(object):
    """Kappa tools driver run locally.

    path -- where to find kappa executables
        (None means use the binaries bundled in the package)
    delimiter -- What to use to delimit messages (must not appears in
        message body default '\\x1e')
    args -- arguments to pass to kappa executables
    """
    def __init__(self, path=None, delimiter='\x1e', args=None):
        self.delimiter = delimiter
        self.project_ast = None
        self.analyses_to_init = True
        if not path:
            path = resource_filename(__name__,"bin")
        sim_args = [join(path,"KaSimAgent"),
                    "--delimiter",
                    "\\x{:02x}".format(ord(self.delimiter)),
                    "--log",
                    "-", ]
        if args:
            sim_args = sim_args + args
        self.lock = threading.Lock()
        self.message_id = 0
        self.sim_agent = subprocess.Popen(sim_args,
                                          stdin=subprocess.PIPE,
                                          stdout=subprocess.PIPE,
                                          stderr=subprocess.STDOUT)
        sa_args = [join(path,"KaSaAgent"),
                    "--delimiter",
                    "\\x{:02x}".format(ord(self.delimiter)), ]
        if args:
            sa_args = sa_args + args
        self.sa_agent = subprocess.Popen(sa_args,
                                         stdin=subprocess.PIPE,
                                         stdout=subprocess.PIPE,
                                         stderr=subprocess.STDOUT)
        return

    def __del__(self):
        self.shutdown()

    def _get_message_id(self):
        self.message_id += 1
        return self.message_id

    def _dispatch(self, method, args=None):
        if args is not None:
            data = [method, args]
        else:
            data = method

        try:
            self.lock.acquire()
            message_id = self._get_message_id()
            message = {'id': message_id,'data': data}
            message = "{0}{1}".format(json.dumps(message), self.delimiter)
            self.sim_agent.stdin.write(message.encode('utf-8'))
            self.sim_agent.stdin.flush()
            buffer = bytearray()
            c = self.sim_agent.stdout.read(1)
            while c != self.delimiter.encode('utf-8') and c:
                buffer.extend(c)
                c = self.sim_agent.stdout.read(1)
            response = json.loads(buffer.decode('utf-8'))
            if response["id"] != message_id:
                raise KappaError(
                        "expect id {0} got {1}".format(response["id"],
                                                       message_id)
                        )
            else:
                return self.projection(response)

        finally:
            self.lock.release()

    def _dispatch_sa(self, method, args=None):
        if args is not None:
            data = [method, args]
        else:
            data = method

        try:
            self.lock.acquire()
            message_id = self._get_message_id()
            message = {'id': message_id,'data': data}
            message = "{0}{1}".format(json.dumps(message), self.delimiter)
            self.sa_agent.stdin.write(message.encode('utf-8'))
            self.sa_agent.stdin.flush()
            buffer = bytearray()
            c = self.sa_agent.stdout.read(1)
            while c != self.delimiter.encode('utf-8') and c:
                buffer.extend(c)
                c = self.sa_agent.stdout.read(1)
            response = json.loads(buffer.decode('utf-8'))
            if response['code'] == "SUCCESS":
                return response['data']
            else:
                raise KappaError(response['data'])

        finally:
            self.lock.release()

    @abc.abstractmethod
    def projection(self, response):
        pass

    def shutdown(self):
        if hasattr(self, 'sim_agent'):
            self.sim_agent.stdin.close()
            self.sim_agent.stdout.close()
            self.sim_agent.kill()
        if hasattr(self, 'sa_agent'):
            self.sa_agent.stdin.close()
            self.sa_agent.stdout.close()
            self.sa_agent.kill()

    def projection(self, response):
        result_data = response["data"]["result_data"]
        data = result_data[1]
        if result_data[0] == "Ok":
            return data[1]
        else:
            raise KappaError(data)

    def project_parse(self, overwrites=None):
        """
        Parses the project

        overwrites -- list of algebraic variables to overwrite
        Each element has the form {var : "variable_name", val : 42 }
        """
        if overwrites is None:
            overwrites = []
        reply = self._dispatch("ProjectParse", overwrites)
        self.project_ast = json.loads(reply['boxed_ast'])
        return reply

    def file_create(self,file_object):
        """
        Add a file to the project

        file_object -- a Kappa_common.File
        """
        file_data = file_object.toJSON()
        self.project_ast = None
        self.analyses_to_init = True
        return self._dispatch("FileCreate", file_data)

    def file_delete(self,file_id):
        """
        Remove a file from the project
        """
        self.project_ast = None
        self.analyses_to_init = True
        return self._dispatch("FileDelete", file_id)

    def file_get(self,file_id):
        """
        Returns file file_id stored in the project
        """
        f = self._dispatch("FileGet", file_id)
        return File(**f)

    def file_info(self):
        """
        Lists the files of the project (returns a FileMetadata array)
        """
        info = self._dispatch("FileCatalog")
        return FileMetadata.from_metadata_list(info)

    def simulation_delete(self):
        """
        Deletes running/paused simulation
        """
        return self._dispatch("SimulationDelete")

    def simulation_file_line(self, file_line_id):
        """
        Returns the file file_line_id generated by $PRINT perturbations
        """
        return self._dispatch("SimulationDetailFileLine", file_line_id)

    def simulation_DIN(self,DIN_id):
        """
        Returns a given generated DIN
        """
        return self._dispatch("SimulationDetailFluxMap", flux_map_id)

    def simulation_log_messages(self):
        """
        Returns simulation log
        """
        return self._dispatch("SimulationDetailLogMessage")

    def simulation_plot(self, limit=None):
        """
        Returns the plot data of the simulation

        Note: No actual plot is produced as a result of this function call.

        Inputs
        ------
        limit -- optionnal boundaries to only get a subplot
        format: { offset : 100, nb_points : 500 }
        returns the last points if offset is Null

        Returns
        -------
        simulation_results -- a json containing the data from the simulation.
        """
        if limit is not None:
            parameter = limit.toJSON()
        else:
            parameter = PlotLimit().toJSON()
        return self._dispatch("SimulationDetailPlot", parameter)

    def simulation_snapshot(self, snapshot_id):
        """
        Returns a given generated snapshot
        """
        return self._dispatch("SimulationDetailSnapshot", snapshot_id)

    def simulation_info(self):
        """
        Returns state and progress of the simulation
        """
        return self._dispatch("SimulationInfo")

    def simulation_info_file_line(self):
        """
        Lists files generated by $PRINT during the simulation
        """
        return self._dispatch("SimulationCatalogFileLine")

    def simulation_DINs(self):
        """
        Lists DIN generated during the simulation
        """
        return self._dispatch("SimulationCatalogFluxMap")

    def simulation_snapshots(self):
        """
        Lists snapshots generated during the simulation
        """
        return self._dispatch("SimulationCatalogSnapshot")

    def simulation_pause(self):
        """
        Pauses a simulation
        """
        return self._dispatch("SimulationPause")

    def simulation_perturbation(self,perturbation_code):
        """
        Fires a perturbation in a paused simulation
        """
        return self._dispatch("SimulationPerturbation",
                              { "perturbation_code" : perturbation_code })

    def simulation_start(self,simulation_parameter):
        """Start the simulation from the last parsed model.

        Inputs
        ------
        simulation_parameter -- is described in kappa_common.SimulationParameter
        """
        if self.project_ast is None:
            raise KappaError("Project not parsed since last modification")
        return self._dispatch("SimulationStart",
                              simulation_parameter.toJSON())

    def simulation_continue(self,pause_condition):
        """
        Restarts a paused simulation
        """
        return self._dispatch("SimulationContinue",pause_condition)

    def _analyses_init(self):
        """
        Initialize the static analyser thanks to the result of project_parse
        """
        if self.project_ast is None:
            raise KappaError("Project not parsed since last modification")
        result = self._dispatch_sa("INIT",self.project_ast)
        self.analyses_to_init = False
        return result

    def analyses_dead_rules(self):
        """
        Returns the dead rules of the last parsed model
        """
        if self.analyses_to_init:
            self._analyses_init()
        return self._dispatch_sa("DEAD_RULES")

    def analyses_constraints_list(self):
        """
        Returns a bunch of invarients on the last parsed model
        """
        if self.analyses_to_init:
            self._analyses_init()
        return self._dispatch_sa("CONSTRAINTS")

    def analyses_contact_map(self,accuracy=None):
        """
        Returns the contact of the last parsed model

        Input
        -----
        accuracy -- \"high\" means take reachability from initial state
           into account. \"low\" means don't.
        """
        if self.analyses_to_init:
            self._analyses_init()
        return self._dispatch_sa("CONTACT_MAP",accuraccy)
