import { blobatar } from "blobatar";
import sharp from "sharp";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";

const output = new URL("../../ios/Packages/KizukiKit/Sources/KizukiDesignSystem/Resources/", import.meta.url);
const manifestURL = new URL("manifest.json", import.meta.url);
const check = process.argv.includes("--check");
const manifest = {};
await mkdir(output, { recursive: true });
// Opaque preset IDs only. Never names, email addresses, profile data, or a network API.
for (let index = 0; index < 32; index++) {
  const name = `avatar-${String(index).padStart(2, "0")}.png`;
  const svg = blobatar(`kizuki-avatar-v1-${index}`, { size: 256 });
  const png = await sharp(Buffer.from(svg)).resize(256, 256).png().toBuffer();
  const digest = createHash("sha256").update(png).digest("hex");
  manifest[name] = digest;
  if (check) {
    const committed = await readFile(new URL(name, output));
    if (createHash("sha256").update(committed).digest("hex") !== digest) {
      throw new Error(`Generated avatar differs: ${name}. Review generator/platform changes.`);
    }
  } else {
    await writeFile(new URL(name, output), png);
  }
}
const text = JSON.stringify(manifest, null, 2) + "\n";
if (check) {
  if (await readFile(manifestURL, "utf8") !== text) throw new Error("Avatar SHA-256 manifest differs.");
} else {
  await writeFile(manifestURL, text);
}
console.log(`${check ? "Verified" : "Generated"} 32 local Blobatar PNGs and their SHA-256 manifest.`);
