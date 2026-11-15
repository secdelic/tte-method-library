"""Read author revisions and make clean copies without changing source documents.

This bounded OOXML adapter accepts supported text/format revisions. Complex
row/cell/custom-XML changes or nonempty deleted paragraph marks require native
Word review on a copy. Comments must be explicitly reviewed before removal.
"""
from __future__ import annotations

from collections import Counter
from copy import deepcopy
from hashlib import sha256
from pathlib import Path
import posixpath
from zipfile import ZipFile, ZIP_DEFLATED

from lxml import etree as E


W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
NS = {"w": W}
FORMAT = {"rPrChange", "pPrChange", "sectPrChange", "tblPrChange", "tblPrExChange",
          "trPrChange", "tcPrChange", "tblGridChange"}
WRAPPERS = {"ins", "del", "moveFrom", "moveTo"}
RANGES = {"moveFromRangeStart", "moveFromRangeEnd", "moveToRangeStart", "moveToRangeEnd"}
COMMENTS = {"commentRangeStart", "commentRangeEnd", "commentReference"}
PARSER = E.XMLParser(resolve_entities=False, no_network=True)


def _local(node):
    return E.QName(node).localname


def _xml(data):
    return E.fromstring(data, PARSER)


def _bytes(root):
    return E.tostring(root, encoding="UTF-8", xml_declaration=True, standalone=True)


def _accept(root):
    """Mutate an XML tree; refuse revision semantics outside the tested subset."""
    for node in root.iter():
        if not isinstance(node.tag, str) or E.QName(node).namespace != W:
            continue
        name = _local(node)
        if ((name.endswith("Change") and name not in FORMAT)
                or name.startswith("customXml") and "Range" in name
                or name in {"cellIns", "cellDel", "cellMerge", "numberingChange"}):
            raise ValueError(f"Unsupported revision {name}; use native Word on a copy")
        if (name in WRAPPERS and node.getparent() is not None
                and _local(node.getparent()) in {"trPr", "tcPr"}):
            raise ValueError("Tracked row/cell revision requires native Word acceptance")
    # Deleted paragraph marks join paragraphs. Only a fully deleted paragraph
    # can be removed here without making unverified formatting/merge decisions.
    marked = root.xpath(".//w:p[w:pPr/w:rPr/w:del or w:pPr/w:rPr/w:moveFrom]", namespaces=NS)
    for paragraph in marked:
        trial = deepcopy(paragraph)
        for node in reversed(trial.xpath(".//w:del|.//w:moveFrom", namespaces=NS)):
            node.getparent().remove(node)
        content = [node for node in trial if _local(node) != "pPr"]
        if content or trial.xpath("./w:pPr/w:sectPr", namespaces=NS):
            raise ValueError("Nonempty deleted paragraph mark requires native Word acceptance")
        paragraph.getparent().remove(paragraph)
    for node in reversed(list(root.iter())):
        if (not isinstance(node.tag, str) or E.QName(node).namespace != W
                or node.getparent() is None):
            continue
        name, parent = _local(node), node.getparent()
        if name in {"del", "moveFrom"} | FORMAT | RANGES | COMMENTS | {"trackRevisions"}:
            parent.remove(node)
        elif name in {"ins", "moveTo"}:
            index = parent.index(node)
            for child in list(node):
                parent.insert(index, child)
                index += 1
            parent.remove(node)
    if root.xpath(".//w:delText|.//w:delInstrText", namespaces=NS):
        raise ValueError("Unwrapped deleted text remains; native Word review required")


def _paragraphs(root):
    rows = []
    for paragraph in root.xpath(".//w:body//w:p", namespaces=NS):
        pieces = []
        for node in paragraph.iter():
            # Text boxes have separate paragraphs; do not count them twice.
            owner = next((a for a in node.iterancestors() if a.tag == f"{{{W}}}p"), None)
            if node is not paragraph and owner is not paragraph:
                continue
            if node.tag == f"{{{W}}}t":
                pieces.append(node.text or "")
            elif node.tag == f"{{{W}}}tab":
                pieces.append("\t")
            elif node.tag in {f"{{{W}}}br", f"{{{W}}}cr"}:
                pieces.append("\n")
        style = paragraph.find("w:pPr/w:pStyle", NS)
        rows.append({"text": "".join(pieces),
                     "style": style.get(f"{{{W}}}val") if style is not None else None})
    return rows


def inspect_word(path):
    """Read hash, accepted body text, revisions and comments; never modify source.

    Comment text is returned for human review; it is not interpreted or silently
    applied. Accepted text alone does not mean the author's scientific changes
    have been approved.
    """
    path = Path(path)
    counts, comments = Counter(), []
    has_comment_markup = False
    with ZipFile(path) as archive:
        for name in archive.namelist():
            if name.startswith("word/") and name.endswith(".xml"):
                root = _xml(archive.read(name))
                has_comment_markup = has_comment_markup or "comments" in name.lower() or any(
                    isinstance(node.tag, str) and E.QName(node).namespace == W
                    and _local(node) in COMMENTS for node in root.iter())
                counts.update(_local(node) for node in root.iter()
                              if isinstance(node.tag, str) and E.QName(node).namespace == W
                              and _local(node) in WRAPPERS | FORMAT | RANGES)
                if name == "word/comments.xml":
                    for comment in root.findall("w:comment", NS):
                        comments.append({"id": comment.get(f"{{{W}}}id"),
                                         "author": comment.get(f"{{{W}}}author"),
                                         "text": "".join(comment.xpath(".//w:t/text()", namespaces=NS))})
        root = _xml(archive.read("word/document.xml"))
        _accept(root)
        paragraphs = _paragraphs(root)
    return {"path": str(path.resolve()), "sha256": sha256(path.read_bytes()).hexdigest(),
            "revision_counts": dict(counts), "format_revision_count": sum(counts[k] for k in FORMAT),
            "comments": comments, "has_comment_markup": has_comment_markup, "paragraphs": paragraphs,
            "accepted_text": "\n".join(row["text"] for row in paragraphs)}


def clean_word(source, target, *, comments_reviewed=False):
    """Accept supported revisions on a new path; remove only reviewed comments.

    All unaffected package parts, including images, tables and source metadata,
    remain intact. Existing output is never overwritten. Any unsupported revision
    aborts before the target is written.
    """
    source, target = Path(source), Path(target)
    if target.suffix.lower() != ".docx":
        raise ValueError("Clean output must use the .docx suffix")
    if source.resolve() == target.resolve() or target.exists():
        raise ValueError("Clean output must be a new path distinct from the source")
    with ZipFile(source) as archive:
        dropped = {name for name in archive.namelist()
                   if name.startswith("word/") and
                   (posixpath.basename(name).lower().startswith("comments")
                    or posixpath.basename(name).lower() == "people.xml")}
        # Require explicit review for comment-related parts or orphaned anchors;
        # a missing comments.xml is not evidence that annotations are absent.
        has_comments = bool(dropped)
        for name in archive.namelist():
            if name.startswith("word/") and name.endswith(".xml"):
                root = _xml(archive.read(name))
                has_comments = has_comments or any(
                    isinstance(node.tag, str) and E.QName(node).namespace == W
                    and _local(node) in COMMENTS for node in root.iter())
        if has_comments and comments_reviewed is not True:
            raise ValueError("Review Word comments explicitly before creating a clean copy")
        parts = {}
        for info in archive.infolist():
            name = info.filename
            if name in dropped or (name.startswith("word/_rels/comments") and name.endswith(".rels")):
                continue
            data = archive.read(name)
            if name.endswith(".rels"):
                root = _xml(data)
                base = posixpath.dirname(posixpath.dirname(name))
                for node in list(root):
                    dest = posixpath.normpath(posixpath.join(base, node.get("Target", ""))).lstrip("/")
                    if dest in dropped or node.get("Type", "").rsplit("/", 1)[-1].startswith("comments"):
                        root.remove(node)
                data = _bytes(root)
            elif name == "[Content_Types].xml":
                root = _xml(data)
                for node in list(root):
                    if node.get("PartName", "").lstrip("/") in dropped:
                        root.remove(node)
                data = _bytes(root)
            elif name.startswith("word/") and name.endswith(".xml"):
                root = _xml(data)
                _accept(root)
                data = _bytes(root)
            parts[name] = (info, data)
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("xb") as stream, ZipFile(stream, "w", ZIP_DEFLATED) as result:
        for info, data in parts.values():
            result.writestr(info, data)
    return target
