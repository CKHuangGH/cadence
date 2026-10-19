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
roles, networks = provider.init()
roles = en.sync_info(roles, networks)

subnet = networks["my_subnet"]

cp = 1
w1 = config["vm"]["worker"]["number"]

for i in range(1):
    start = i * (cp + w1)
    virt_conf = (
        en.VMonG5kConf.from_settings(image = config["vm"]["image"])
        .add_machine(
            roles=["cp"],
            number=cp,
            undercloud=roles["role0"],
            flavour_desc={"core": config["vm"]["control_plane"]["cpu"], "mem": config["vm"]["control_plane"]["memory"]},
            macs=list(subnet[0].free_macs)[start:start+cp],
        )
        .add_machine(
            roles=["member"],
            number=w1,
            undercloud=roles["role0"],
            flavour_desc={"core": config["vm"]["worker"]["cpu"], "mem": config["vm"]["worker"]["memory"]},
            macs=list(subnet[0].free_macs)[start+cp:start+cp+w1],
        ).finalize()
    )

    vmroles = en.start_virtualmachines(virt_conf,force_deploy=True)

    tempname = job_name + str(i)

    inventory_file = "kubefed_inventory_cluster"+ str(tempname) +".ini" 

    inventory = generate_inventory(vmroles, networks, inventory_file)

    cp_nodes.append(vmroles["cp"][0].address)

    all_vm_nodes.append(vmroles["cp"][0].address)

    for vm in vmroles["member"]:
        all_vm_nodes.append(vm.address)

    time.sleep(config["deployment"]["wait_before_ansible"])

    run_ansible([config["deployment"]["ansible_playbook"]],inventory_path=inventory_file)

with open("cp_node_list", "a") as f:
    for ip in cp_nodes:
        f.write(ip + "\n")

with open("all_node_list", "a") as f:
    for ip in all_vm_nodes:
        f.write(ip + "\n")