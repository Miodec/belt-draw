#!/usr/bin/env python3
"""Summarise a Factorio .cpuprofile (from script-output/) for one mod.

Usage: tools/cpuprofile.py PROFILE [--mod belt-draw] [--event on_player_change_selected_area] [--top 25]

Prints the cost per call of the event (median, p90, p99, max) and the mod's functions by total time.
The time an event handler's own frame shows is mostly idle time before the event, not work: the profile
credits the gap since the previous sample to the next one. Only time inside the mod's functions counts.
"""
import argparse
import collections
import json
import statistics


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("profile")
    parser.add_argument("--mod", default="belt-draw")
    parser.add_argument("--event", default="on_player_change_selected_area")
    parser.add_argument("--top", type=int, default=25)
    args = parser.parse_args()

    with open(args.profile) as f:
        profile = json.load(f)
    nodes = {n["id"]: n for n in profile["nodes"]}
    parent = {child: n["id"] for n in profile["nodes"] for child in n.get("children", [])}

    def top_level(node_id):
        while parent.get(node_id, 0) != 0:
            node_id = parent[node_id]
        return node_id

    def label(node):
        frame = node["callFrame"]
        url = frame["url"]
        short = url[url.find(args.mod):] if args.mod in url else url[-40:]
        return f"{frame['functionName'][:40]} {short}:{frame['lineNumber']}"

    # cost per event call: consecutive samples inside a function under the event's frame.
    # The first sample of a run is the idle gap before it, so it's skipped
    calls, current = [], None
    for sample, delta in zip(profile["samples"], profile["timeDeltas"]):
        top = top_level(sample) if sample in nodes and sample != 0 else 0
        in_event = top and sample != top and nodes[top]["callFrame"]["functionName"].startswith(args.event)
        if in_event:
            if current is None:
                current = 0.0
                calls.append(current)
            else:
                calls[-1] += delta
        else:
            current = None

    if calls:
        ordered = sorted(calls)
        def at(fraction):
            return ordered[min(len(ordered) - 1, int(len(ordered) * fraction))] / 1000
        print(f"{args.event}: {len(calls)} calls, {sum(calls) / 1000:.1f} ms total, "
              f"median {statistics.median(calls) / 1000:.2f} ms, p90 {at(0.9):.2f} ms, "
              f"p99 {at(0.99):.2f} ms, max {ordered[-1] / 1000:.2f} ms")
    else:
        print(f"{args.event}: no calls in this profile")

    # time per function: self, and total including what it calls (recursion counted once)
    self_time = collections.Counter()
    for sample, delta in zip(profile["samples"], profile["timeDeltas"]):
        self_time[sample] += delta
    total = collections.Counter(self_time)
    def depth(node_id):
        d = 0
        while node_id in parent:
            node_id, d = parent[node_id], d + 1
        return d
    for node_id in sorted(nodes, key=depth, reverse=True):
        if node_id in parent:
            total[parent[node_id]] += total[node_id]

    by_self, by_total = collections.Counter(), collections.Counter()
    for node_id, node in nodes.items():
        name = label(node)
        if args.mod not in node["callFrame"]["url"]:
            continue
        by_self[name] += self_time[node_id]
        ancestor, recursive = parent.get(node_id), False
        while ancestor is not None:
            if label(nodes[ancestor]) == name:
                recursive = True
                break
            ancestor = parent.get(ancestor)
        if not recursive:
            by_total[name] += total[node_id]

    print(f"\n{'total ms':>10} {'self ms':>9}  function")
    for name, value in by_total.most_common(args.top):
        print(f"{value / 1000:10.1f} {by_self[name] / 1000:9.1f}  {name}")


if __name__ == "__main__":
    main()
