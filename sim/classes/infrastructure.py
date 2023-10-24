from os import makedirs
from os.path import dirname, exists, join
from typing import Any

import config as c
import matplotlib.pyplot as plt
import networkx as nx
import numpy as np
import click


# nx graph obtained as a barabasi albert graph
class Infrastructure(nx.DiGraph):
	def __init__(self, n: int = 2, m: int = 1, seed: Any = None):
		super().__init__(directed=True)
		self.n = n
		self.m = m

		self.build(n, m, seed)
		self.degrees = self.out_degree()
		self._size = len(self.nodes)
		self.file = c.INFRA_FILE_PATH.format(size=self._size)

	# @c.timeit
	def build(self, n, m, seed):
		g = nx.barabasi_albert_graph(n, m, seed=seed)
		#g = nx.random_internet_as_graph(n, seed=seed)
		self.init_nodes(g.nodes)
		self.init_links(g.edges)
		self.to_directed()

	def init_nodes(self, nodes):
		for n in nodes:
			latency_budget = np.random.randint(c.NODE_LAT_MIN, c.NODE_LAT_MAX)
			self.add_node(n, latency_budget=latency_budget)

	def init_links(self, links):
		for s,d in links:
			lat = np.random.randint(c.LINK_LAT_MIN, c.LINK_LAT_MAX)
			bw = np.random.randint(c.LINK_BW_MIN, c.LINK_BW_MAX)
			self.add_edge(s, d, lat=lat, bw=bw)
			self.add_edge(d, s, lat=lat, bw=bw)

	def str_min_max_latency(self):
		min_latency = min([a["lat"] for _, _, a in self.edges(data=True)])
		max_latency = max([a["lat"] for _, _, a in self.edges(data=True)])
		min_latency = c.MIN_LATENCY.format(min_latency=min_latency)
		max_latency = c.MAX_LATENCY.format(max_latency=max_latency)

		return min_latency + "\n" + max_latency
	
	def str_min_max_bw(self):
		min_bw = min([a["bw"] for _, _, a in self.edges(data=True)])
		max_bw = max([a["bw"] for _, _, a in self.edges(data=True)])
		min_bw = c.MIN_BW.format(min_bw=min_bw)
		max_bw = c.MAX_BW.format(max_bw=max_bw)

		return min_bw + "\n" + max_bw

	def str_min_max_degrees(self):
		min_degree = min([d for n, d in self.degrees])
		max_degree = max([d for n, d in self.degrees])
		min_degree = c.MIN_DEGREE.format(min_degree=min_degree)
		max_degree = c.MAX_DEGREE.format(max_degree=max_degree)

		return min_degree + "\n" + max_degree

	def str_nodes(self):
		return "\n".join([c.NODE.format(nid=str(n), latency_budget=a["latency_budget"]) for n, a in self.nodes(data=True)])

	def str_links(self):
		return "\n".join([c.LINK.format(source=str(s), dest=str(d), lat=a["lat"], bw=a["bw"]) for s, d, a in self.edges(data=True)])
	
	def str_degrees(self):
		return "\n".join([c.DEGREE.format(nid=str(n), degree=str(d)) for n, d in self.degrees])
	
	def __str__(self):
		res = self.str_nodes() + "\n\n"
		res += self.str_links() + "\n\n"
		res += self.str_degrees() + "\n\n"
		res += self.str_min_max_degrees() + "\n\n"
		res += self.str_min_max_latency() + "\n\n"
		res += self.str_min_max_bw() + "\n\n"
		return res
	
	def __repr__(self):
		return self.__str__()
	
	def upload(self, file=None):
		file = self.file if not file else file
		makedirs(dirname(file)) if not exists(dirname(file)) else None		
		with open(file, "w+") as f:
			f.write(str(self))
	
	def save_graph(self):
		nx.draw_networkx(self, arrows=True, with_labels=True, **c.FIG_OPTIONS)
		name = f"infrastructure_{self._size}." + c.PLOT_FORMAT
		plt.savefig(join(c.PLOTS_DIR, name), dpi=c.PLOT_DPI, format=c.PLOT_FORMAT)

@click.command()
@click.argument('nodes', type=int)
@click.option('--seed', '-s', type=int, default=None, help="Seed for the random number generator.")
def main(nodes, seed):
	infrastructure = Infrastructure(n=nodes, m=int(np.log2(nodes)), seed=seed)
	infrastructure.upload()

if __name__ == '__main__':
	main()