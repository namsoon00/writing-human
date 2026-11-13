// OCR is lazy, local to the browser, and loads only our own static assets.
(() => {
  const directory = new URL('vendor/ocr/', document.baseURI);
  const asset = (name) => new URL(name, directory).href;
  let loading;
  let active;
  let liveWorker;

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

  function paragraphs(data) {
    return data.blocks?.flatMap((block) => block.paragraphs.map((paragraph) =>
      paragraph.lines?.length
        ? paragraph.lines.filter((line) => line.text.trim())
        : paragraph.text.trim().split('\n').filter(Boolean).map((text) => ({text})),
    )).filter((paragraph) => paragraph.length) ?? [];
  }

  // A whole-page recognizer may join two columns into one line. Only split
  // when several rows agree on a wide central gutter.
  function columnGutter(paragraphs, width, height) {
    const rows = paragraphs.flat().filter((line) => line.bbox);
    const candidates = [];
    for (const row of rows) {
      const words = (row.words ?? []).filter((word) => word.bbox)
        .sort((a, b) => a.bbox.x0 - b.bbox.x0);
      const minGap = Math.max(width * .032, (row.bbox.y1 - row.bbox.y0) * 1.05);
      for (let i = 1; i < words.length; i++) {
        const left = words[i - 1].bbox.x1;
        const right = words[i].bbox.x0;
        const cut = (left + right) / 2;
        if (right - left >= minGap && cut >= width * .36 && cut <= width * .65 &&
            left - words[0].bbox.x0 >= width * .12 &&
            words.at(-1).bbox.x1 - right >= width * .12) {
          candidates.push({left, right, cut, row});
        }
      }
    }
    let best;
    for (const candidate of candidates) {
      const supporting = [...new Set(candidates
        .filter((gap) => gap.left < candidate.cut && candidate.cut < gap.right)
        .map((gap) => gap.row))];
      if (supporting.length < 2 || supporting.length <= (best?.count ?? 0)) continue;
      const first = Math.min(...supporting.map((line) => line.bbox.y0));
      const last = Math.max(...supporting.map((line) => line.bbox.y1));
      const body = rows.filter((line) => line.bbox.y0 >= first && line.bbox.y1 <= last);
      if (body.some((line) => (line.words ?? []).some((word) => word.bbox &&
          word.bbox.x0 < candidate.cut && candidate.cut < word.bbox.x1))) continue;
      best = {
        cut: Math.round(candidate.cut),
        top: Math.max(0, Math.floor(first - 8)),
        bottom: Math.min(height, Math.ceil(last + 8)),
        first, last, count: supporting.length,
      };
    }
    return best;
  }

  window.writingHumanCancelOcr = () => active?.cancel(new Error('Cancelled'));

  window.writingHumanEndLiveOcr = () => {
    if (active?.live) active.cancel(new Error('Cancelled'));
    const worker = liveWorker;
    liveWorker = undefined;
    if (worker) void worker.terminate().catch(() => {});
  };

  window.writingHumanScanPhoto = async (bytes, width, height, tight, live = false) => {
    window.writingHumanCancelOcr();
    const job = {cancelled: false, live};
    const interrupted = new Promise((_, reject) => {
      job.cancel = (error) => {
        job.cancelled = true;
        reject(error);
      };
    });
    active = job;
    try {
      await Promise.race([engine(), interrupted]);
      const initializing = live && liveWorker ? Promise.resolve(liveWorker) : window.Tesseract.createWorker(['kor'], 1, {
        workerPath: asset('worker.min.js'),
        corePath: directory.href,
        langPath: directory.href.replace(/\/$/, ''),
        workerBlobURL: false,
        legacyCore: false,
        errorHandler: () => {
          const running = live ? active : job;
          if (running && (!live || running.live)) {
            running.cancel(new Error('OCR worker failed'));
          }
        },
      }).then(async (worker) => {
        if (job.cancelled) {
          await worker.terminate();
          throw new Error('Cancelled');
        }
        if (live) liveWorker = worker;
        return worker;
      });
      job.worker = await Promise.race([initializing, interrupted]);
      const image = new Blob([bytes]);
      const read = async () => {
        await job.worker.setParameters({tessedit_pageseg_mode: tight ? '6' : '4'});
        let {data} = await job.worker.recognize(image, {}, {text: true, blocks: true});
        if (!data.text.trim() && !tight) {
          await job.worker.setParameters({tessedit_pageseg_mode: '6'});
          ({data} = await job.worker.recognize(image, {}, {text: true, blocks: true}));
        }
        const whole = paragraphs(data);
        if (!whole.length) return data.text.trim().split(/\n\s*\n/).filter(Boolean)
          .map((paragraph) => paragraph.split('\n').filter(Boolean).map((text) => ({text})));
        const gutter = tight ? null : columnGutter(whole, width, height);
        if (!gutter) return whole;
        const {cut, top, bottom, first, last} = gutter;
        const column = async (left, columnWidth) => {
          const rectangle = {left, top, width: columnWidth, height: bottom - top};
          const result = await job.worker.recognize(image, {rectangle}, {text: true, blocks: true});
          return paragraphs(result.data);
        };
        const left = await column(0, cut);
        const right = await column(cut, width - cut);
        if (!left.length || !right.length) return whole;
        const outside = (matches) => whole
          .map((paragraph) => paragraph.filter((line) => matches(line.bbox)))
          .filter((paragraph) => paragraph.length);
        return [
          ...outside((box) => !box || box.y0 < first),
          ...left,
          ...right,
          ...outside((box) => box && box.y1 > last && box.y0 >= first),
        ];
      };
      const recognized = await Promise.race([read(), interrupted]);
      const bounds = (box) => box
        ? [box.x0 / width, box.y0 / height, box.x1 / width, box.y1 / height]
        : null;
      const word = (item) => ({
        text: item.text.trim(), bounds: bounds(item.bbox),
        confidence: Number.isFinite(item.confidence) ? item.confidence / 100 : null,
      });
      return recognized.map((paragraph) => paragraph.map((line) => ({
        ...word(line), words: (line.words ?? []).filter((item) => item.text.trim()).map(word),
      })));
    } catch (error) {
      if (live && liveWorker === job.worker) {
        liveWorker = undefined;
        if (job.worker) await job.worker.terminate();
      }
      throw error;
    } finally {
      if (active === job) active = undefined;
      if (!live && job.worker) await job.worker.terminate();
    }
  };

  // Older cached app shells can still call the text-only bridge.
  window.writingHumanRecognizePhoto = async (bytes) =>
    (await window.writingHumanScanPhoto(bytes, 1, 1, false))
      .map((paragraph) => paragraph.map((line) => line.text).join('\n'));
})();
