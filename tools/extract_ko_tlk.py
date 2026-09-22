#!/usr/bin/env python3
"""Extract NSM53-style Korean Ultima IV .TLK and compare with locale talk JSON.

DOS Korean TLK (Johab) mixes:
  - normal Johab syllables
  - high-byte josa markers (e.g. 0xC2 → 는) + next syllable lead XOR 0x95
  - trail-XOR 0x81 when trail byte is ASCII, then next pair byte-swapped (시인 etc.)
  - ASCII A–Z josa selectors (G=을/를, J=이다/다, …) resolved by batchim

Field boundaries inside each NPC are still packed; dos_ko.body is the merged
look..no blob. Names/gender and English topic stems are reliable anchors.

Usage:
  python3 tools/extract_ko_tlk.py
  python3 tools/extract_ko_tlk.py --kor /path/to/game --out tools/ko_tlk_extract
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

FIELDS = [
    "name",
    "pronoun",
    "look",
    "job",
    "health",
    "response1",
    "response2",
    "question",
    "yes",
    "no",
    "topic1",
    "topic2",
]

JOSA_BYTE = {
    0xC2: "는",
}

ASCII_JOSA = {
    "A": ("아", "야"),
    "B": ("은", "는"),
    "C": ("은", "는"),
    "D": ("이", "가"),
    "E": ("이", "가"),
    "F": ("을", "를"),
    "G": ("을", "를"),
    "H": ("과", "와"),
    "I": ("과", "와"),
    "J": ("이다", "다"),
    "K": ("입니다", "입니다"),
    "L": ("으로", "로"),
    "M": ("이여", "여"),
    "N": ("은", "는"),
    "O": ("으로", "로"),
    "P": ("이", "가"),
    "Q": ("을", "를"),
    "R": ("를", "을"),
    "S": ("이", "가"),
    "T": ("을", "를"),
    "U": ("은", "는"),
    "V": ("와", "과"),
    "W": ("을", "를"),
    "Y": ("이여", "여"),
    "Z": ("이다", "다"),
}


def has_batchim(ch: str) -> bool:
    return len(ch) == 1 and "\uac00" <= ch <= "\ud7a3" and (ord(ch) - 0xAC00) % 28 != 0


def is_han(a: int, b: int) -> tuple[bool, str]:
    try:
        ch = bytes([a, b]).decode("johab")
        if "\uac00" <= ch <= "\ud7a3":
            return True, ch
    except Exception:
        pass
    return False, ""


def last_han_char(out: list[str]) -> str:
    for item in reversed(out):
        for c in reversed(item):
            if "\uac00" <= c <= "\ud7a3":
                return c
    return ""


def decode_ko(buf: bytes) -> str:
    out: list[str] = []
    i = 0
    swap_next = False
    while i < len(buf):
        b = buf[i]
        if b == 0:
            break
        if b in (10, 13):
            out.append("\n")
            i += 1
            continue
        if b in JOSA_BYTE:
            out.append(JOSA_BYTE[b])
            i += 1
            if i + 1 < len(buf):
                ok, ch = is_han(buf[i] ^ 0x95, buf[i + 1])
                if ok:
                    out.append(ch)
                    i += 2
            continue
        if 65 <= b <= 90:
            ch = chr(b)
            prev = last_han_char(out)
            if ch in ASCII_JOSA and prev:
                w, wo = ASCII_JOSA[ch]
                out.append(w if has_batchim(prev) else wo)
            i += 1
            continue
        if 32 <= b < 127:
            if chr(b) in ".?!,\"'-:; ":
                out.append(chr(b))
            i += 1
            continue
        if b < 0x20:
            i += 1
            continue
        if i + 1 >= len(buf):
            break
        a, c = buf[i], buf[i + 1]
        if swap_next:
            ok, ch = is_han(c, a)
            swap_next = False
            if ok:
                out.append(ch)
                i += 2
                continue
        ok, ch = is_han(a, c)
        if ok:
            out.append(ch)
            i += 2
            continue
        # Compressed syllable: trail XOR 0x81 when trail is a non-letter ASCII cover
        # byte (e.g. space). Do NOT treat A–Z josa selectors as XOR covers.
        if a >= 0x80 and c < 0x80 and not (65 <= c <= 90) and not (97 <= c <= 122):
            ok2, ch2 = is_han(a, c ^ 0x81)
            if ok2:
                out.append(ch2)
                i += 2
                swap_next = True
                continue
        # Unknown high byte — skip (format / colour / unmapped josa).
        i += 1
    s = "".join(out)
    # Soft word breaks after expanded josa endings before the next clause.
    s = re.sub(r"(이다|다|입니다|을|를|은|는|이|가|과|와|으로|로)(?=[\uac00-\ud7a3])", r"\1 ", s)
    s = re.sub(r"[ \t]+", " ", s)
    s = re.sub(r" *\n *", "\n", s)
    return s.strip()


def parse_eng_city(data: bytes) -> list[dict]:
    npcs: list[dict] = []
    for n in range(16):
        rec = data[n * 288 : (n + 1) * 288]
        if len(rec) < 288:
            break
        e: dict = {
            "ask_after": int(rec[0]),
            "humility": int(rec[1]),
            "turn_away": int(rec[2]),
        }
        i = 3
        for f in FIELDS:
            j = rec.find(0, i)
            if j < 0:
                j = len(rec)
            e[f] = rec[i:j].decode("ascii", "replace")
            i = j + 1
        if not str(e["name"]).strip():
            break
        npcs.append(e)
    return npcs


def find_gender(chunk: bytes) -> tuple[int, str]:
    male = chunk.find("남성".encode("johab"))
    female = chunk.find("여성".encode("johab"))
    if male >= 0 and (female < 0 or male < female):
        return male, "남성"
    if female >= 0:
        return female, "여성"
    return -1, ""


def extract_city(city: str, eng_dir: Path, kor_dir: Path, pack_dir: Path) -> dict:
    eng_path = eng_dir / f"{city.upper()}.TLK"
    kor_path = kor_dir / f"{city.upper()}.TLK"
    if not eng_path.exists() or not kor_path.exists():
        return {"city": city, "error": "missing tlk", "npcs": []}

    eng = parse_eng_city(eng_path.read_bytes())
    kor = kor_path.read_bytes()
    pack_by: dict = {}
    pack_path = pack_dir / f"{city}.json"
    if pack_path.exists():
        pack = json.loads(pack_path.read_text(encoding="utf-8"))
        pack_by = {n.get("name"): n.get("ko", {}) for n in pack.get("npcs", [])}

    pos = 0
    out: list[dict] = []
    for en in eng:
        t1, t2 = en["topic1"].encode(), en["topic2"].encode()
        use_t1 = t1 not in (b"", b"A")
        use_t2 = t2 not in (b"", b"A")
        i1 = kor.find(t1, pos) if use_t1 else -1
        i2 = kor.find(t2, i1 + len(t1) if i1 >= 0 else pos) if use_t2 else -1

        # Window: previous pos → a bit past topic2 (includes name/gender/body).
        end = len(kor)
        if i2 >= 0:
            end = min(end, i2 + len(t2) + 80)
        elif i1 >= 0:
            end = min(end, i1 + 160)
        else:
            end = min(end, pos + 400)
        chunk = kor[pos:end]

        gpos, gender = find_gender(chunk)
        name_line = ""
        if gpos > 0:
            before = chunk[:gpos]
            while before.endswith(b"\x00"):
                before = before[:-1]
            ln = before.rfind(0)
            raw = before[ln + 1 :] if ln >= 0 else before
            name_line = decode_ko(raw)
            name_line = re.sub(r"^[^가-힣A-Za-z]+", "", name_line)

        # Also drop the leftover garbage syllable sometimes left before 사람들 (e.g. 럚).
        # Unknown marker bytes before ASCII josa J(=이다) are skipped in decode_ko.

        body_off = (gpos + len(gender.encode("johab")) + 1) if gpos >= 0 else 0
        body = chunk[body_off:]
        pre, tail = body, b""
        if i1 >= 0:
            rel = i1 - pos - body_off
            if 0 <= rel < len(body):
                pre, tail = body[:rel], body[rel:]

        jk = pack_by.get(en["name"], {})
        out.append(
            {
                "name": en["name"],
                "pronoun": en["pronoun"],
                "look": en["look"],
                "job": en["job"],
                "health": en["health"],
                "response1": en["response1"],
                "response2": en["response2"],
                "question": en["question"],
                "yes": en["yes"],
                "no": en["no"],
                "topic1": en["topic1"],
                "topic2": en["topic2"],
                "ask_after": en["ask_after"],
                "dos_ko": {
                    "name_line": name_line,
                    "gender": gender,
                    "body": decode_ko(pre),
                    "after_topics": decode_ko(tail),
                },
                "json_ko": {
                    k: jk.get(k, "")
                    for k in (
                        "name",
                        "pronoun",
                        "look",
                        "job",
                        "health",
                        "response1",
                        "response2",
                        "question",
                        "yes",
                        "no",
                        "topic1",
                        "topic2",
                    )
                },
            }
        )
        if i2 >= 0:
            pos = i2 + len(t2)
        elif i1 >= 0:
            pos = i1 + len(t1)
        else:
            pos = end

    return {
        "_meta": {
            "city": city,
            "source_kor": str(kor_path),
            "source_eng": str(eng_path),
            "note": (
                "dos_ko.body merges look..no (field split not exact). "
                "Johab + partial josa/XOR decode; unknown high bytes skipped."
            ),
        },
        "npcs": out,
    }


def write_britain_md(data: dict, path: Path) -> None:
    lines = [
        f"# {data['_meta']['city']} — DOS Korean TLK vs locale JSON\n",
        f"Source: `{data['_meta']['source_kor']}`\n",
    ]
    for n in data["npcs"]:
        lines.append(f"## {n['name']} (`{n['topic1']}` / `{n['topic2']}`)\n")
        lines.append(
            f"- DOS: **{n['dos_ko']['name_line']}** ({n['dos_ko']['gender']})"
        )
        lines.append(
            f"- JSON: **{n['json_ko'].get('name')}** / {n['json_ko'].get('pronoun')}"
        )
        lines.append(f"- JSON look: {n['json_ko'].get('look')}")
        lines.append(f"- DOS body:\n```\n{n['dos_ko']['body']}\n```")
        lines.append("- JSON lines:\n```")
        for k in ("job", "health", "response1", "response2", "question", "yes", "no", "topic1", "topic2"):
            lines.append(f"[{k}] {n['json_ko'].get(k)}")
        lines.append("```\n")
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--kor",
        type=Path,
        default=Path("/Volumes/Whitby/Game/Ultima IV™.app/Contents/Resources/game"),
    )
    ap.add_argument(
        "--eng",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "data" / "u4",
    )
    ap.add_argument(
        "--pack",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "assets" / "locale" / "talk",
    )
    ap.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "tools" / "ko_tlk_extract",
    )
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    cities = [p.stem.lower() for p in sorted(args.eng.glob("*.TLK"))]
    print(f"Iolo smoke: {decode_ko((args.kor / 'BRITAIN.TLK').read_bytes()[61:248])}")
    for city in cities:
        data = extract_city(city, args.eng, args.kor, args.pack)
        outp = args.out / f"{city}.compare.json"
        outp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        named = sum(1 for n in data["npcs"] if n["dos_ko"]["name_line"])
        print(f"{outp.name}: npcs={len(data['npcs'])} named={named}")
        if city == "britain":
            write_britain_md(data, args.out / "britain.compare.md")
    print(f"done → {args.out}")


if __name__ == "__main__":
    main()
