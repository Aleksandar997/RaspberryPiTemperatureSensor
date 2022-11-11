import json 

def dump_json(obj: object) -> str:
    return json.dumps(obj, indent=4, default=lambda x: x.__dict__)

def load_json(obj: str) -> dict:
    return json.loads(obj)
