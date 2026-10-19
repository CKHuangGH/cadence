import getpass
from enoslib.api import generate_inventory, run_ansible
import enoslib as en
import time
import tomllib
import sys

username = getpass.getuser()
en.set_config(ansible_forks=100)
with open("00-config.toml", "rb") as f:
    config = tomllib.load(f)

cp_nodes = []
all_vm_nodes = []

cluster = config["g5k"]["cluster"]
site = config["g5k"]["site"]
duration = config["g5k"]["duration"]
number_servers = config["g5k"]["number_servers"]
suffix = sys.argv[1]

job_name = f"{site}-{cluster}-{username}-{suffix}"

prod_network = en.G5kNetworkConf(type="prod", roles=["my_network"], site=site)

conf = (
    en.G5kConf.from_settings(job_type=[], job_name=job_name, walltime=duration)
    .add_network_conf(prod_network)
    .add_network(
        id="not_linked_to_any_machine", type="slash_22", roles=["my_subnet"], site=site
    )
    .add_machine(
    roles=["role0"], cluster=cluster, nodes=number_servers, primary_network=prod_network
    ).finalize()
)

provider = en.G5k(conf)
provider.destroy()