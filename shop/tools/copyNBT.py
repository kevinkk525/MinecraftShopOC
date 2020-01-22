# import pyperclip
import collections
import json

# source = input("craftables.json path:")
source = "all_items.json"
with open(source, "r") as f:
    items = json.loads(f.read())
server = input("Server:")
target = ("../items_{!s}.json".format(server))
with open(target, "r") as f:
    items_target = json.loads(f.read())

amounts = input("Amounts separated by ,:")
if amounts:
    amounts = amounts.split(",")
    amounts = [int(x) for x in amounts]
    amounts.sort()
else:
    amounts = [1, 16, 32, 64, 256, 1024, 2016, 4032]
print("Got amounts:", amounts)
categories = input("Categories separated by ,:")
print("Got categories:", categories)
if categories:
    categories = categories.split(",")
use_price_func = input("Use price func?")
default_stock = input("Default stock multiplier of max amount:")
if default_stock:
    default_stock = float(default_stock)

ask_frn = input("Ask friendly name?")
ask_cat = input("Ask category?")
is_craftable = input("Should items be crafted if unavailable?")


def myround(x, base=5):
    return base * round(x / base)


if server != "dirtcraft":  # linear prices for dirtcraft
    def price_func(price, x):
        return myround(x * price / 64.0 * 0.9864 ** (x / 64.0))
else:
    def price_func(price, x):
        res = x / 64 * price
        if res < 1:
            res = 1
        return res

while True:
    print("")
    label = input("Label of the item:")
    found = []
    for item in items:
        # print(item["name"], name)
        if item["label"] == label:
            found.append(item)
    if len(found) > 1:
        name = input("Found " + str(len(found)) + " items, name:")
        for item in found:
            if item["name"] == name:
                found = item
                break
    elif len(found) == 1:
        found = found[0]
    if found:
        item = found
        print("Found", item["label"], item["name"], item["damage"])
        if "batch_size" in item:
            del item["batch_size"]
        if "amount" in item:
            del item["amount"]
        item["amounts"] = collections.OrderedDict()
        if use_price_func:
            price = input("Price per 64:")
            price = int(price)
            for amount in amounts:
                item["amounts"][str(amount)] = int(price_func(price, amount))
        else:
            for amount in amounts:
                price = input("Price amount " + str(amount))
                if price:
                    item["amounts"][str(amount)] = int(price)
        item["categories"] = []
        if categories:
            item["categories"] = categories
        if ask_cat:
            cats = input("Categories:")
            if cats:
                cats = cats.split(",")
                item["categories"] += cats
        if not item["categories"]:
            del item["categories"]  # no empty entries
        if default_stock:
            item["stock"] = int(amounts[-1] * default_stock)
        else:
            item["stock"] = int(input("Stock:"))
        if not is_craftable:
            item["craftable"] = False
        if ask_frn:
            frn = input("Friendly_name")
            if frn:
                item["label_friendly"] = frn
        found_target = False
        for i, it in enumerate(items_target):
            if it["label"] == item["label"] and it["name"] == item["name"]:
                items_target[i] = item
                found_target = True
                break
        if not found_target:
            items_target.append(item)
        output = json.dumps(items_target, indent=4, ensure_ascii=False)
        with open(target, "w") as f:
            f.write(output)
        # output = json.dumps(item, indent=4,ensure_ascii=False)
        # pyperclip.copy(output)
        # print("copied")
    else:
        print("not found")
