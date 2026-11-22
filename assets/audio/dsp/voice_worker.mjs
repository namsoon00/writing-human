import createModule from './signalsmith_factory.mjs';
let module;
const heap = m => new Float32Array(m.HEAP8.buffer);
async function processVoice({samples, rate, speed, pitch}) {
  const data = new Float32Array(samples);
  if (!(rate >= 8000 && rate <= 96000) || !Number.isFinite(speed) || speed < .5 || speed > 2 || !Number.isFinite(pitch) || data.length === 0 || data.length > rate*90) throw Error('Invalid voice buffer');
  const m = module ??= await createModule();
  m._presetDefault(1, rate);
  m._reset();
  m._setTransposeSemitones(pitch, 0);
  m._setFormantFactor(1, true);
  m._setFormantBase(190/rate);
  const ahead = m._inputLatency(), behind = m._outputLatency();
  const count = Math.round(data.length/speed);
  const capacity = Math.max(data.length, count, ahead, behind);
  const pointer = m._setBuffers(1, capacity)/4;
  heap(m).fill(0, pointer, pointer+capacity);
  heap(m).set(data.subarray(0, Math.min(ahead, data.length)), pointer);
  m._seek(ahead, data.length/count);
  heap(m).fill(0, pointer, pointer+capacity);
  if (data.length > ahead) heap(m).set(data.subarray(ahead), pointer);
  m._process(data.length, count);
  const result = new Float32Array(count+behind);
  result.set(heap(m).subarray(pointer+capacity, pointer+capacity+count));
  m._flush(behind);
  result.set(heap(m).subarray(pointer+capacity, pointer+capacity+behind), count);
  return result.slice(behind, behind+count);
}
let queue = Promise.resolve();
self.onmessage = ({data}) => {
  queue = queue.then(async () => {
    try {
      const output = await processVoice(data);
      self.postMessage({id:data.id, samples:output.buffer}, [output.buffer]);
    } catch (error) { self.postMessage({id:data.id, error:String(error)}); }
  });
};
