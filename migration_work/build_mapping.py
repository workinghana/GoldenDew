#!/usr/bin/env python3
import csv
from collections import defaultdict

def read_csv(path):
    with open(path, 'r', encoding='utf-8') as f:
        return list(csv.DictReader(f))

prod = read_csv('C:/Users/milvus-0/Goldendew/migration_work/prod_order.csv')
dev = read_csv('C:/Users/milvus-0/Goldendew/migration_work/dev_order.csv')

print(f"Prod: {len(prod)}, Dev: {len(dev)}")

# Match strategy:
# 1. OrderNo__c (SOR...) -> unique, direct join
# 2. SaleNo__c (SAL...) exists only in prod. Dev has neither OrderNo nor SaleNo for these.
#    For these, match by (EffectiveDate, TotalAmount) multiset; if ambiguous, sequence-preserve.

# Build dev index by OrderNo__c
dev_by_orderno = {d['OrderNo__c']: d for d in dev if d['OrderNo__c']}

# Pool dev deposit orders (no OrderNo) by (EffectiveDate, TotalAmount)
dev_pool = defaultdict(list)  # (date, amount) -> [dev rows in file order]
for d in dev:
    if not d['OrderNo__c']:
        key = (d['EffectiveDate'], d['TotalAmount'])
        dev_pool[key].append(d)

# Build mapping
mapping = {}  # prod Id -> dev Id
unmatched_prod = []

# Separate pools for prod deposit orders too, to consume in same order
prod_deposits_by_key = defaultdict(list)
for p in prod:
    if p['OrderNo__c']:
        # Direct match by OrderNo__c
        dev_row = dev_by_orderno.get(p['OrderNo__c'])
        if dev_row:
            mapping[p['Id']] = dev_row['Id']
        else:
            unmatched_prod.append(p)
    else:
        prod_deposits_by_key[(p['EffectiveDate'], p['TotalAmount'])].append(p)

# Consume deposit pool in file order (FIFO)
for key, prod_list in prod_deposits_by_key.items():
    dev_list = dev_pool.get(key, [])
    for i, p in enumerate(prod_list):
        if i < len(dev_list):
            mapping[p['Id']] = dev_list[i]['Id']
        else:
            unmatched_prod.append(p)

# Check unmatched dev
matched_dev = set(mapping.values())
unmatched_dev = [d for d in dev if d['Id'] not in matched_dev]

print(f"Matched: {len(mapping)}")
print(f"Unmatched prod: {len(unmatched_prod)}")
print(f"Unmatched dev: {len(unmatched_dev)}")

if unmatched_prod:
    print("\n--- Unmatched Prod ---")
    for p in unmatched_prod:
        print(f"  {p['Id']} | OrderNo={p['OrderNo__c']} | SaleNo={p['SaleNo__c']} | {p['EffectiveDate']} | {p['TotalAmount']}")

if unmatched_dev:
    print("\n--- Unmatched Dev ---")
    for d in unmatched_dev:
        print(f"  {d['Id']} | OrderNo={d['OrderNo__c']} | {d['EffectiveDate']} | {d['TotalAmount']}")

# Write mapping CSV
with open('C:/Users/milvus-0/Goldendew/migration_work/order_mapping.csv', 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f)
    w.writerow(['prod_id', 'dev_id'])
    for k, v in mapping.items():
        w.writerow([k, v])

print(f"\nMapping written: order_mapping.csv ({len(mapping)} rows)")
