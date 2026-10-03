/** Ordinary ads only. Rewarded ads use INeedHost's separate ads.rewarded method. */
export function createDisplayAds(host) {
  const unavailable = () => ({ok:false,error:{code:'UNSUPPORTED',message:'Display ads are not enabled by this host'}});
  async function invoke(method, params) {
    const bridge = host === undefined ? globalThis.INeedHost : host;
    if (!bridge?.request) return unavailable();
    const hello = await bridge.request('hello',{protocols:[1]});
    if (!hello.ok || !hello.value?.capabilities?.includes(method)) return unavailable();
    return bridge.request(method,params);
  }
  return Object.freeze({
    show: params => invoke('ads.show',params),
    close: requestId => invoke('ads.close',{requestId})
  });
}
export const displayAds = createDisplayAds();
