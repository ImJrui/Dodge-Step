"""Build the DST Mod icon from the current static preview with Klei Mod Tools."""

import argparse
from pathlib import Path
import struct
import subprocess
import tempfile
import xml.etree.ElementTree as ET

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ICON_SIZE = 1024
ICON_NAME = "ds_modicon"
DEFAULT_CONVERTER = (
    ROOT.parents[2] / "Don't Starve Mod Tools" / "mod_tools"
    / "tools" / "bin" / "TextureConverter.exe"
)


def build_icon(source, output_dir, converter):
    if not converter.is_file():
        raise FileNotFoundError("Klei TextureConverter.exe not found; pass --converter.")
    with Image.open(source) as image:
        if image.width != image.height:
            raise ValueError("The static preview must be square.")
        icon = image.convert("RGBA").resize(
            (ICON_SIZE, ICON_SIZE), Image.Resampling.LANCZOS
        )
    output_dir.mkdir(parents=True, exist_ok=True)
    texture_path = output_dir / (ICON_NAME + ".tex")
    atlas_path = output_dir / (ICON_NAME + ".xml")
    with tempfile.TemporaryDirectory(prefix="ds_modicon_") as work:
        prepared = Path(work) / (ICON_NAME + ".png")
        generated = Path(work) / texture_path.name
        icon.save(prepared)
        subprocess.run(
            [str(converter), "--swizzle", "--format", "bc3", "--platform", "opengl",
             "--mipmap", "--premultiply", "-i", str(prepared), "-o", str(generated)],
            check=True,
        )
        data = generated.read_bytes()
        if data[:4] != b"KTEX":
            raise ValueError("The converter did not produce a Klei texture.")
        header = struct.unpack_from("<I", data, 4)[0]
        if (header >> 4) & 31 != 2:
            raise ValueError("The generated texture is not BC3.")
        if struct.unpack_from("<HH", data, 8) != (ICON_SIZE, ICON_SIZE):
            raise ValueError("The generated texture has an unexpected size.")
        texture_path.write_bytes(data)
    atlas = ET.Element("Atlas")
    ET.SubElement(atlas, "Texture", filename=texture_path.name)
    elements = ET.SubElement(atlas, "Elements")
    inset = 0.5 / ICON_SIZE
    ET.SubElement(
        elements, "Element", name=texture_path.name,
        u1=str(inset), v1=str(inset), u2=str(1 - inset), v2=str(1 - inset),
    )
    ET.indent(atlas, space="  ")
    ET.ElementTree(atlas).write(atlas_path, encoding="utf-8", xml_declaration=True)
    print("Built {} and {} ({} x {}, BC3, mipmaps).".format(
        texture_path, atlas_path, ICON_SIZE, ICON_SIZE
    ))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "docs/media/ds_dodge_step.png")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "images")
    parser.add_argument("--converter", type=Path, default=DEFAULT_CONVERTER)
    args = parser.parse_args()
    build_icon(args.source.resolve(), args.output_dir.resolve(), args.converter.resolve())


if __name__ == "__main__":
    main()
