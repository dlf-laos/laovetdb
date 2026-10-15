from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MIG = ROOT / "database" / "migrations"
SEED = ROOT / "database" / "seeds"
MANIFEST = ROOT / "docs" / "01_FINAL_MIGRATION_MANIFEST.md"

errors: list[str] = []
warnings: list[str] = []

manifest = MANIFEST.read_text(encoding="utf-8")
expected = re.findall(r"- (\d{6}_[A-Za-z0-9_]+\.sql)", manifest)
actual_paths = sorted(MIG.glob("*.sql"))
actual = [p.name for p in actual_paths]

missing = [x for x in expected if x not in actual]
extra = [x for x in actual if x not in expected]
if missing:
    errors.append("Missing migrations: " + ", ".join(missing))
if extra:
    errors.append("Unmanifested migrations: " + ", ".join(extra))
if actual != expected:
    errors.append("Migration filesystem order does not exactly match manifest order")

CREATE_TABLE = re.compile(
    r"CREATE\s+(?:UNLOGGED\s+)?TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([A-Za-z_][\w]*\.[A-Za-z_][\w]*)",
    re.I,
)
REF_TABLE = re.compile(r"REFERENCES\s+([A-Za-z_][\w]*\.[A-Za-z_][\w]*)", re.I)
ALTER_TABLE = re.compile(r"ALTER\s+TABLE\s+(?:IF\s+EXISTS\s+)?([A-Za-z_][\w]*\.[A-Za-z_][\w]*)", re.I)
INDEX_TABLE = re.compile(r"CREATE\s+(?:UNIQUE\s+)?INDEX(?:\s+IF\s+NOT\s+EXISTS)?\s+[A-Za-z_][\w]*\s+ON\s+([A-Za-z_][\w]*\.[A-Za-z_][\w]*)", re.I)
INSERT_TABLE = re.compile(r"INSERT\s+INTO\s+([A-Za-z_][\w]*\.[A-Za-z_][\w]*)", re.I)

# Minimal lexical balance checker. It ignores quoted text, SQL comments, and dollar-quoted blocks.
def lexical_balance(text: str, filename: str) -> None:
    i = 0
    paren = 0
    state = "normal"
    dollar_tag = None
    n = len(text)
    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if state == "normal":
            if ch == "-" and nxt == "-":
                state = "line_comment"; i += 2; continue
            if ch == "/" and nxt == "*":
                state = "block_comment"; i += 2; continue
            if ch == "'":
                state = "single"; i += 1; continue
            if ch == '"':
                state = "double"; i += 1; continue
            if ch == "$":
                m = re.match(r"\$[A-Za-z_][A-Za-z0-9_]*\$|\$\$", text[i:])
                if m:
                    dollar_tag = m.group(0); state = "dollar"; i += len(dollar_tag); continue
            if ch == "(": paren += 1
            elif ch == ")":
                paren -= 1
                if paren < 0:
                    errors.append(f"Unmatched ')' in {filename}"); return
            i += 1
        elif state == "line_comment":
            if ch == "\n": state = "normal"
            i += 1
        elif state == "block_comment":
            if ch == "*" and nxt == "/": state = "normal"; i += 2
            else: i += 1
        elif state == "single":
            if ch == "'":
                if nxt == "'": i += 2
                else: state = "normal"; i += 1
            else: i += 1
        elif state == "double":
            if ch == '"':
                if nxt == '"': i += 2
                else: state = "normal"; i += 1
            else: i += 1
        elif state == "dollar":
            assert dollar_tag is not None
            if text.startswith(dollar_tag, i):
                i += len(dollar_tag); state = "normal"; dollar_tag = None
            else: i += 1
    if state in {"single", "double", "block_comment", "dollar"}:
        errors.append(f"Unterminated SQL lexical construct in {filename}: {state}")
    if paren != 0:
        errors.append(f"Unbalanced parentheses in {filename}: balance={paren}")

created_at: dict[str, tuple[int, str]] = {}
for idx, path in enumerate(actual_paths):
    sql = path.read_text(encoding="utf-8")
    if not sql.strip(): errors.append("Empty migration: " + path.name)
    if "\x00" in sql: errors.append("NUL byte: " + path.name)
    lexical_balance(sql, path.name)
    for table in CREATE_TABLE.findall(sql):
        key = table.lower()
        if key in created_at:
            errors.append(f"Duplicate CREATE TABLE {table}: {created_at[key][1]} and {path.name}")
        else:
            created_at[key] = (idx, path.name)

# Physical naming guardrails.
for table, (_idx, filename) in created_at.items():
    base = table.rsplit(".", 1)[-1]
    if base in {"case", "user", "order", "group"}:
        errors.append(f"Forbidden/reserved physical table name '{table}' in {filename}")
    if table.startswith("public."):
        errors.append(f"Business table created in public schema: {table}")

# Dependency-order checks.
allowed_external = {"public.spatial_ref_sys"}
for idx, path in enumerate(actual_paths):
    sql = path.read_text(encoding="utf-8")
    for table in REF_TABLE.findall(sql):
        key = table.lower()
        if key in allowed_external: continue
        if key not in created_at:
            errors.append(f"FK target does not exist in migration set: {path.name} -> {table}")
        elif created_at[key][0] > idx:
            errors.append(f"FK target created later: {path.name} -> {table} ({created_at[key][1]})")
    for table in ALTER_TABLE.findall(sql):
        key = table.lower()
        if key not in created_at:
            errors.append(f"ALTER TABLE target does not exist: {path.name} -> {table}")
        elif created_at[key][0] > idx:
            errors.append(f"ALTER TABLE target created later: {path.name} -> {table}")
    for table in INDEX_TABLE.findall(sql):
        key = table.lower()
        if key not in created_at:
            errors.append(f"INDEX target does not exist: {path.name} -> {table}")
        elif created_at[key][0] > idx:
            errors.append(f"INDEX target created later: {path.name} -> {table}")

# Seed target existence and simple lexical checks.
seed_paths = sorted(SEED.glob("*.sql"))
for path in seed_paths:
    sql = path.read_text(encoding="utf-8")
    if not sql.strip(): errors.append("Empty seed: " + path.name)
    lexical_balance(sql, path.name)
    for table in INSERT_TABLE.findall(sql):
        if table.lower() not in created_at:
            errors.append(f"Seed INSERT target does not exist: {path.name} -> {table}")


# Validate JSON/YAML package artifacts where parser support is available.
import json
for jp in [ROOT / "database" / "schema_inventory.json", ROOT / "package.json", ROOT / "turbo.json"]:
    try:
        json.loads(jp.read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"Invalid JSON {jp.relative_to(ROOT)}: {exc}")
try:
    import yaml
    openapi_path = ROOT / "openapi" / "lvsp-openapi.yaml"
    api = yaml.safe_load(openapi_path.read_text(encoding="utf-8"))
    if api.get("openapi") != "3.1.0" or not isinstance(api.get("paths"), dict) or not api["paths"]:
        errors.append("OpenAPI document is missing required 3.1.0 structure or paths")
except ImportError:
    warnings.append("PyYAML unavailable; OpenAPI YAML parse check skipped")
except Exception as exc:
    errors.append(f"Invalid OpenAPI YAML: {exc}")

# Consolidated schema must exactly reflect current migrations.
full_path = ROOT / "database" / "LVSP_FULL_SCHEMA.sql"
if not full_path.exists():
    errors.append("Missing database/LVSP_FULL_SCHEMA.sql")
else:
    expected_full = "".join(
        f"\n-- ============================================================================\n-- MIGRATION: {p.name}\n-- ============================================================================\n"
        + p.read_text(encoding="utf-8").rstrip() + "\n"
        for p in actual_paths
    )
    if full_path.read_text(encoding="utf-8") != expected_full:
        errors.append("LVSP_FULL_SCHEMA.sql is stale and does not match current migration files")

required_docs = [
    "01_FINAL_MIGRATION_MANIFEST.md", "02_SEED_MANIFEST.md", "03_PERMISSION_MANIFEST.md",
    "04_WORKFLOW_SEED_MANIFEST.md", "05_API_ENDPOINT_MANIFEST.md", "06_FRONTEND_ROUTE_MANIFEST.md",
    "07_ENVIRONMENT_VARIABLES.md", "08_TEST_MATRIX.md", "09_DEPLOYMENT_CHECKLIST.md",
    "10_CLAUDE_CODE_MASTER_INSTRUCTIONS.md", "11_IMPLEMENTATION_MILESTONES.md",
    "12_FINAL_BUILD_HANDOFF.md", "13_CLAUDE_CODE_START_HERE.md",
]
for name in required_docs:
    if not (ROOT / "docs" / name).exists():
        errors.append("Missing required document: docs/" + name)

if errors:
    print("LVSP PACKAGE VALIDATION: FAILED")
    for e in errors: print("ERROR:", e)
    for w in warnings: print("WARN:", w)
    sys.exit(1)

print("LVSP PACKAGE VALIDATION: PASSED")
print(f"- {len(actual)} migrations exactly match manifest")
print(f"- {len(seed_paths)} seed SQL files checked")
print(f"- {len(created_at)} physical tables discovered")
print("- FK / ALTER / INDEX dependency order checks passed")
print("- seed target-table checks passed")
print("- reserved physical table-name guard passed")
print("- SQL lexical balance checks passed")
print("- consolidated schema is current")

for warning in warnings:
    print("WARN:", warning)
