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

  window.writingHumanRecognizePhoto = async (bytes) => {
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
        // A book photo is normally a single column containing paragraphs.
        await job.worker.setParameters({tessedit_pageseg_mode: '4'});
        let result = await job.worker.recognize(image, {}, {text: true, blocks: true});
        if (!result.data.text.trim()) {
          await job.worker.setParameters({tessedit_pageseg_mode: '6'});
          result = await job.worker.recognize(image, {}, {text: true, blocks: true});
        }
        return result;
      };
      const {data} = await Promise.race([read(), interrupted]);
      const paragraphs = data.blocks?.flatMap((block) =>
        block.paragraphs.map((paragraph) => paragraph.text.trim()).filter(Boolean),
      );
      return paragraphs?.length ? paragraphs : data.text.split(/\n\s*\n/).map((text) => text.trim()).filter(Boolean);
    } finally {
      if (active === job) active = undefined;
      if (job.worker) await job.worker.terminate();
    }
  };
})();
