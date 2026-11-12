// OCR is lazy, local to the browser, and loads only our own static assets.
(() => {
  const directory = new URL('vendor/ocr/', document.baseURI);
  const asset = (name) => new URL(name, directory).href;
  let loading;
  let active;

  function engine() {
    if (window.Tesseract) return Promise.resolve();
    if (!loading) {
      loading = new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = asset('tesseract.min.js');
        script.onload = resolve;
        script.onerror = () => {
          script.remove();
          loading = undefined;
          reject(new Error('OCR engine could not load'));
        };
        document.head.appendChild(script);
      });
    }
    return loading;
  }

  window.writingHumanCancelOcr = () => active?.cancel(new Error('Cancelled'));

  window.writingHumanScanPhoto = async (bytes, width, height, tight) => {
    window.writingHumanCancelOcr();
    const job = {cancelled: false};
    const interrupted = new Promise((_, reject) => {
      job.cancel = (error) => {
        job.cancelled = true;
        reject(error);
      };
    });
    active = job;
    try {
      await Promise.race([engine(), interrupted]);
      const initializing = window.Tesseract.createWorker(['kor'], 1, {
        workerPath: asset('worker.min.js'),
        corePath: directory.href,
        langPath: directory.href.replace(/\/$/, ''),
        workerBlobURL: false,
        legacyCore: false,
        errorHandler: () => job.cancel(new Error('OCR worker failed')),
      }).then(async (worker) => {
        if (job.cancelled) {
          await worker.terminate();
          throw new Error('Cancelled');
        }
        return worker;
      });
      job.worker = await Promise.race([initializing, interrupted]);
      const image = new Blob([bytes]);
      const read = async () => {
        // Automatic layout handles columns. A selected crop is usually one block.
        await job.worker.setParameters({tessedit_pageseg_mode: tight ? '6' : '3'});
        let result = await job.worker.recognize(image, {}, {text: true, blocks: true});
        if (!result.data.text.trim() && !tight) {
          await job.worker.setParameters({tessedit_pageseg_mode: '6'});
          result = await job.worker.recognize(image, {}, {text: true, blocks: true});
        }
        return result;
      };
      const {data} = await Promise.race([read(), interrupted]);
      const bounds = (box) => box
        ? [box.x0 / width, box.y0 / height, box.x1 / width, box.y1 / height]
        : null;
      const word = (item) => ({
        text: item.text.trim(), bounds: bounds(item.bbox),
        confidence: item.confidence / 100,
      });
      const paragraphs = data.blocks?.flatMap((block) => block.paragraphs.map((paragraph) =>
        paragraph.lines?.length
          ? paragraph.lines.filter((line) => line.text.trim()).map((line) => ({
              ...word(line), words: (line.words ?? []).filter((item) => item.text.trim()).map(word),
            }))
          : paragraph.text.trim().split('\n').filter(Boolean).map((text) => ({text})),
      )).filter((paragraph) => paragraph.length);
      return paragraphs?.length ? paragraphs : data.text.trim().split(/\n\s*\n/).filter(Boolean)
        .map((paragraph) => paragraph.split('\n').filter(Boolean).map((text) => ({text})));
    } finally {
      if (active === job) active = undefined;
      if (job.worker) await job.worker.terminate();
    }
  };

  // Older cached app shells can still call the text-only bridge.
  window.writingHumanRecognizePhoto = async (bytes) =>
    (await window.writingHumanScanPhoto(bytes, 1, 1, false))
      .map((paragraph) => paragraph.map((line) => line.text).join('\n'));
})();
