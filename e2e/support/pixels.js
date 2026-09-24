// Pixel-content check for preview images (AGENTS.md "Preventing false
// positives"): an image that loads but is all-transparent or all-black is a
// broken preview, not a passing one.

// Loads url in the page, draws its top-left 100x100 region on a canvas and
// looks for a pixel with alpha > 0 and some RGB > 0.
// Usage: if (!(await imageHasVisiblePixels(page, src))) throw new Error("blank preview");
async function imageHasVisiblePixels(page, url) {
  return page.evaluate(async (src) => {
    return new Promise((resolve) => {
      const img = new Image();
      img.crossOrigin = "anonymous";
      img.onload = () => {
        try {
          const c = document.createElement("canvas");
          c.width = img.width;
          c.height = img.height;
          const ctx = c.getContext("2d");
          ctx.drawImage(img, 0, 0);
          const data = ctx.getImageData(0, 0, Math.min(100, img.width), Math.min(100, img.height)).data;
          for (let i = 0; i < data.length; i += 4) {
            if (data[i + 3] > 0 && (data[i] > 0 || data[i + 1] > 0 || data[i + 2] > 0)) {
              resolve(true);
              return;
            }
          }
          resolve(false);
        } catch { resolve(false); }
      };
      img.onerror = () => resolve(false);
      img.src = src;
    });
  }, url);
}

module.exports = { imageHasVisiblePixels };
