"""Prepare allowlisted, public Flutter build values without printing credentials."""

import base64
import json
import os
from pathlib import Path
import re


def public_key(value):
    if value.startswith("sb_publishable_"):
        return True
    try:
        payload = value.split(".")[1]
        claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
        return claims.get("role") == "anon"
    except (IndexError, ValueError, UnicodeError):
        return False


def main():
    source = os.environ.get("DATA_SOURCE", "local")
    if source not in ("local", "supabase"):
        raise ValueError("A release deve usar local ou supabase.")
    version = re.search(r"^version:\s*([^+\s]+)", Path("pubspec.yaml").read_text(encoding="utf-8"), re.M)[1]
    tag = f"v{version}" + ("-supabase" if source == "supabase" else "")
    if os.environ.get("GITHUB_REF_TYPE") == "tag" and os.environ.get("GITHUB_REF_NAME") != tag:
        raise ValueError(f"A tag deve corresponder à versão e à fonte de dados: {tag}")
    config = {"DATA_SOURCE": source, "APP_VERSION": f"{version}-{source}"}
    if source == "supabase":
        url = os.environ.get("SUPABASE_URL", "").rstrip("/")
        key = os.environ.get("SUPABASE_PUBLISHABLE_KEY", "")
        if not url.startswith("https://") or not public_key(key):
            raise ValueError("Configure SUPABASE_URL HTTPS e SUPABASE_PUBLISHABLE_KEY pública; chaves secretas são recusadas.")
        config.update(SUPABASE_URL=url, SUPABASE_PUBLISHABLE_KEY=key)
        config["API_BASE_URL"] = os.environ.get("API_BASE_URL", "") or "https://bcc-ufape.vercel.app"
    Path(".env.release.json").write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    if os.environ.get("GITHUB_ENV"):
        with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as output:
            output.write(f"RELEASE_TAG={tag}\n")
    Path("dist").mkdir(exist_ok=True)
    print(f"Configuração de release preparada: {tag}, DATA_SOURCE={source}")


if __name__ == "__main__":
    main()
