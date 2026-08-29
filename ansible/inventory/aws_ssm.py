#!/usr/bin/env python3
"""Dynamic inventory: InService ASG guests plus hr-bastion, grouped by role. Connection is SSM."""
from __future__ import annotations

import json
import subprocess
import sys

ASGS = {
    "asg-portal": "portal",
    "asg-rest": "rest",
    "asg-haystack": "haystack",
    "asg-neo4j": "neo4j",
}

GROUPS = (*ASGS.values(), "bastion")


def aws_json(args: list[str]):
    out = subprocess.check_output(["aws", *args], text=True)
    return json.loads(out)


def empty_inventory() -> dict:
    inv: dict = {"_meta": {"hostvars": {}}}
    for group in GROUPS:
        inv[group] = {"hosts": []}
    return inv


def hostvars_for(iid: str, group: str, asg_name: str) -> dict:
    hv = {
        "ansible_host": iid,
        "ansible_connection": "amazon.aws.aws_ssm",
        "ansible_aws_ssm_region": "us-east-1",
        "ansible_user": "ssm-user",
        "asg_name": asg_name,
        "app_role": group,
    }
    if group != "bastion":
        hv["app_secret_id"] = f"heavy-rental/{group}"
    return hv


def add_bastion(inv: dict) -> None:
    try:
        data = aws_json(
            [
                "ec2",
                "describe-instances",
                "--filters",
                "Name=tag:Role,Values=bastion",
                "Name=instance-state-name,Values=running",
            ]
        )
    except subprocess.CalledProcessError:
        return
    for res in data.get("Reservations") or []:
        for inst in res.get("Instances") or []:
            iid = inst.get("InstanceId")
            if not iid:
                continue
            inv["bastion"]["hosts"].append(iid)
            inv["_meta"]["hostvars"][iid] = hostvars_for(iid, "bastion", "hr-bastion")


def build() -> dict:
    inv = empty_inventory()
    for asg, group in ASGS.items():
        try:
            data = aws_json(
                [
                    "autoscaling",
                    "describe-auto-scaling-groups",
                    "--auto-scaling-group-names",
                    asg,
                ]
            )
        except subprocess.CalledProcessError:
            continue
        groups = data.get("AutoScalingGroups") or []
        if not groups:
            continue
        for inst in groups[0].get("Instances") or []:
            if inst.get("LifecycleState") != "InService":
                continue
            iid = inst["InstanceId"]
            inv[group]["hosts"].append(iid)
            inv["_meta"]["hostvars"][iid] = hostvars_for(iid, group, asg)
    add_bastion(inv)
    return inv


def main() -> None:
    if len(sys.argv) == 2 and sys.argv[1] == "--list":
        print(json.dumps(build()))
        return
    if len(sys.argv) == 3 and sys.argv[1] == "--host":
        inv = build()
        print(json.dumps(inv["_meta"]["hostvars"].get(sys.argv[2], {})))
        return
    print(json.dumps(build()))


if __name__ == "__main__":
    main()
