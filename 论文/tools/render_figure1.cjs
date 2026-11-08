/** Render the editable Figure 1 SVG to the manuscript and Overleaf image formats. */
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');

async function main() {
  // Resolve the figure paths relative to this script so rendering is independent of the working directory.
  const paperRoot = path.resolve(__dirname, '..');
  const figureRoot = path.join(paperRoot, 'figures');
  // Keep both comparison styles separate until a variant is adopted by the manuscript.
  const illustratedVariant = process.argv.includes('--illustrated-preview');
  const previewVariant = illustratedVariant || process.argv.includes('--systems-preview');
  const stem = illustratedVariant
    ? '图1_GriddingMachine框架_彩色组件版_2026-11-08'
    : (previewVariant
      ? '图1_GriddingMachine框架_系统论文风格_2026-11-08'
      : '图1_GriddingMachine总体架构_终稿');
  const source = await fs.readFile(path.join(figureRoot, `${stem}.svg`));

  // Rasterize at twice the SVG dimensions while retaining the SVG as the editable source.
  const png = await sharp(source, { density: 144 })
    .flatten({ background: '#ffffff' })
    .withMetadata({ density: 144 })
    .png()
    .toBuffer();
  await fs.writeFile(path.join(figureRoot, `${stem}.png`), png);
  // Synchronize Overleaf only for the active manuscript figure, preserving the current comparison baseline.
  if (!previewVariant) {
    await fs.writeFile(path.join(paperRoot, 'overleaf', 'figures', 'figure1.png'), png);
  }

  // Export the same pixels as a losslessly compressed TIFF with the journal's print-resolution metadata.
  await sharp(png)
    .withMetadata({ density: 300 })
    .tiff({ compression: 'lzw' })
    .toFile(path.join(figureRoot, `${stem}_300dpi.tiff`));
  // State explicitly whether this command generated a comparison figure or replaced the active image.
  console.log(previewVariant
    ? 'Figure 1 comparison PNG and TIFF have been generated.'
    : 'Figure 1 PNG, TIFF, and Overleaf copy have been synchronized.');
}

// Surface conversion failures to the caller instead of leaving apparently successful stale images.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
