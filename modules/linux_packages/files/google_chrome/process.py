import json


def extract_nodes(node, src, results):
    # Function definitions
    if node.get("Type") == "FuncDecl":
        start, end = node["Pos"]["Offset"], node["End"]["Offset"]
        results.append(src[start:end].decode())
    # Assignments at the top level or inside commands
    elif node.get("Type") == "CallExpr" and "Assigns" in node:
        for assign in node["Assigns"]:
            start, end = assign["Pos"]["Offset"], assign["End"]["Offset"]
            results.append(src[start:end].decode())
    # Recurse into possible child lists
    for key in ("Stmts", "Then", "Else", "Do", "Body"):
        child = node.get(key)
        if isinstance(child, dict):
            extract_nodes(child, src, results)
        elif isinstance(child, list):
            for item in child:
                if isinstance(item, dict):
                    extract_nodes(item, src, results)
    # For function bodies, look inside the "Body"->"Cmd"
    if node.get("Type") == "FuncDecl" and "Body" in node and "Cmd" in node["Body"]:
        extract_nodes(node["Body"]["Cmd"], src, results)
    # For if/for/case/etc, look inside "Cmd"
    if "Cmd" in node and isinstance(node["Cmd"], dict):
        extract_nodes(node["Cmd"], src, results)


# main
if __name__ == '__main__':
    with open('postinst', 'rb') as f:
        src = f.read()

    with open('ast.json') as f:
        ast = json.load(f)

    results = []
    # Start from the 'List' field of the root node
    for node in ast.get('Stmts', []):
        extract_nodes(node, src, results)

    with open('postinst_filtered', 'w') as f:
        for line in results:
            f.write(line)
            f.write('\n')
