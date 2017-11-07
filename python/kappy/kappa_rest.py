"""
Web api client for the kappa programming language
"""

__all__ = ['KappaRest']

import json
from requests import exceptions, request
from os.path import join

from kappy.kappa_common import KappaError, File, FileMetadata, PlotLimit

class KappaRest(object):
    """Client to a Kappa tools driver run as a server.

    Same interface as KappaStd (documented there)
    + a few extra methods to get general information about the server

    endpoint -- The url to the kappa server.
    project_id -- An identifier for this particular project.
    """
    def __init__(self, endpoint, project_id):
        self.url = "{0}/v2".format(endpoint)
        self.project_id = project_id
        if not project_id in self.project_info():
            self._project_create()
        return

    def __del__(self):
        self._project_delete()

    def _dispatch(self, method, sub_url=None, data=None):
        if sub_url is not None:
            url = join(self.url, sub_url)
        if isinstance(data, str):
            data = json.dumps(data)
        try:
            r = request(method, url, data=data)
        except exceptions.HTTPError as e:
            msg = e.read()
            raise KappaError(json.loads(msg, encoding='utf-8'))
        details = r.json(encoding='utf-8')
        if 400 <= r.status_code < 500:
            raise KappaError(details)
        else:
            return details

    def _get(self, sub_url=None, data=None):
        """Thin wrapper around _dispatch function using method GET"""
        return self._dispatch('GET', sub_url, data)

    def _post(self, sub_url=None, data=None):
        """Thin wrapper around _dispatch function using method POST"""
        return self._dispatch("POST", sub_url, data)

    def _delete(self, sub_url=None, data=None):
        """Thin wrapper around _dispatch function using method DELETE"""
        return self._dispatch("DELETE", sub_url, data)

    def _put(self, sub_url=None, data=None):
        """Thin wrapper around _dispatch function using method PUT"""
        return self._dispatch("PUT", sub_url, data)

    def in_project(self, *elements):
        """Method to ease navigating the path structure within a project."""
        return join('projects', self.project_id, *elements)

    def shutdown(self, key):
        """Shut down kappa instance.

        Given a key to a kappa service shutdown a running kappa instance.
        """
        parse_url = "{0}/shutdown".format(self.url)
        try:
            r = request('GET', parse_url)
        except exceptions.HTTPError as e:
            pass
        request = request.Request(parse_url, data=key.encode('utf-8'))
        request.get_method = lambda: method
        try:
            connection = opener.open(request)
        except error.HTTPError as exception:
            connection = exception
        except request.URLError as exception:
            raise KappaError(exception.reason)
        if r.status_code == 200:
            return r.text
        elif r.status_code == 400:
            print(r.text, r.reason)
            raise KappaError(r.text)
        elif r.status_code == 401:
            raise KappaError(r.text)
        else:
            raise KappaError(r.reason)

    def get_info(self):
        """Get a json dict with info about the kappa server."""
        return self._get(self.url)

    def _project_create(self):
        """Create this project with given."""
        return self._post('projects', {"project_id": self.project_id})

    def project_info(self):
        """Get json with info about all the projects."""
        return self._get('projects')

    def _project_delete(self):
        """Delete this project.

        Note that the project can still be recreated with `project_create`
        method. The effect of these two commands would be to clear the project.
        """
        return self._delete(self.in_project())

    def project_parse(self, overwrites=None):
        if overwrites is None:
            overwrites = []
        return self._post(self.in_project('parse'), overwrites)

    def file_create(self, file_object):
        return self._post(self.in_project('files'), file_object.toJSON())

    def file_delete(self, file_id):
        return self._delete(self.in_project('files', file_id))

    def file_get(self, file_id):
        file_json = self._get(self.in_project('files', file_id))
        return File(**file_json)

    def file_info(self):
        info = self._get(self.in_project('files'))
        return FileMetadata.from_metadata_list(info)

    def simulation_delete(self):
        return self._delete(self.in_project('simulation'))

    def simulation_file_line(self, file_line_id):
        sub_url = self.in_project('simulation', 'file_lines', file_line_id)
        return self._get(sub_url)

    def simulation_DIN(self, flux_map_id):
        return self._get(self.in_project('simulation', 'fluxmaps', flux_map_id))

    def simulation_log_messages(self):
        return self._get(self.in_project('simulation', 'logmessages'))

    def simulation_plot(self, limit=None):
        if limit is not None:
            parameter = limit.toURL()
        else:
            parameter = PlotLimit().toURL()
        plot_query = "plot?%s" % parameter
        return self._get(self.in_project('simulation', plot_query))

    def simulation_info(self):
        return self._get(self.in_project('simulation'))

    def simulation_info_file_line(self):
        return self._get(self.in_project('simulation', 'file_lines'))

    def simulation_DINs(self):
        return self._get(self.in_project('simulation', 'fluxmaps'))

    def simulation_snapshots(self):
        return self._get(self.in_project('simulation', 'snapshots'))

    def simulation_snapshot(self,snapshot_id):
        return self._get(self.in_project('simulation', 'snapshots',
                                            snapshot_id))

    def simulation_delete(self):
        return self._delete(self.in_project('simulation'))

    def simulation_pause(self):
        return self._put(self.in_project('simulation', 'pause'),
                         {'action': 'pause'})

    def simulation_perturbation(self, perturbation_code):
        return self._put(self.in_project('simulation', 'perturbation'),
                         {'perturbation_code': perturbation_code})

    def simulation_start(self, simulation_parameter):
        return self._post(self.in_project('simulation'),
                          simulation_parameter.toJSON())

    def simulation_continue(self, pause_condition):
        return self._put(self.in_project('simulation', 'continue'),
                         pause_condition)
