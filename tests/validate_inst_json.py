#!/usr/bin/env python3
# ==============================================================================
# validate input against eduroam database schema v2
# ==============================================================================
from jsonschema import validate
import json
import sys
# ==============================================================================
def main():
  schema = open("/home/eduroamdb/eduroam-db/web/coverage/config/schema.json", 'r')
  schema = json.load(schema)
  data = json.load(sys.stdin)
  validate(data, schema)

# ==============================================================================
# program is run directly, not included
# ==============================================================================
if __name__ == "__main__":
  main()
