/** Render the editable Figure 1 SVG to the manuscript and Overleaf image formats. */
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');

async function main() {
  // Resolve the figure paths relative to this script so rendering is independent of the working directory.
  const paperRoot = path.resolve(__dirname, '..');
  const figureRoot = path.join(paperRoot, 'figures');
  const stem = '图1_GriddingMachine总体架构_终稿';
  const source = await fs.readFile(path.join(figureRoot, `${stem}.svg`));

  // Rasterize at twice the SVG dimensions while retaining the SVG as the editable source.
  const png = await sharp(source, { density: 144 })
    .flatten({ background: '#ffffff' })
    .withMetadata({ density: 144 })
    .png()
    .toBuffer();
  await fs.writeFile(path.join(figureRoot, `${stem}.png`), png);
  await fs.writeFile(path.join(paperRoot, 'overleaf', 'figures', 'figure1.png'), png);

  // Export the same pixels as a losslessly compressed TIFF with the journal's print-resolution metadata.
  await sharp(png)
    .withMetadata({ density: 300 })
    .tiff({ compression: 'lzw' })
    .toFile(path.join(figureRoot, `${stem}_300dpi.tiff`));
  console.log('Figure 1 PNG, TIFF, and Overleaf copy have been synchronized.');
}

// Surface conversion failures to the caller instead of leaving apparently successful stale images.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
