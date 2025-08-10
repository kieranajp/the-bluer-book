/** URL / media helpers extracted from monolith */
const YT_PATTERN = /(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/;

export function isYouTube(url) {
  return !!(url && YT_PATTERN.test(url));
}

export function videoId(url) {
  const m = url ? url.match(YT_PATTERN) : null;
  return m ? m[1] : null;
}

export function startTime(url) {
  if (!url) return null;

  const m = url.match(/[?&]t=(\d+)/);
  return m ? parseInt(m[1]) : null;
}

export function embedUrl(url) {
  const id = videoId(url);
  if (!id) return null;

  const t = startTime(url);
  return t ? `https://www.youtube.com/embed/${id}?start=${t}` : `https://www.youtube.com/embed/${id}`;
}

export function displayInfo(url) {
  if (!url) return null;

  if (isYouTube(url)) {
    return {
      type: 'youtube',
      embedUrl: embedUrl(url),
      originalUrl: url,
      icon: '📺',
      label: 'Watch Recipe Video'
    };
  }

  if (url.toLowerCase().includes('.pdf')) {
    return {
      type: 'pdf',
      originalUrl: url,
      icon: '📄',
      label: 'View Recipe PDF'
    };
  }

  try {
    const u = new URL(url);
    return {
      type: 'link',
      originalUrl: url,
      icon: '🔗',
      label: `Visit ${u.hostname}`,
      domain: u.hostname
    };
  } catch {
    return {
      type: 'link',
      originalUrl: url,
      icon: '🔗',
      label: 'View Recipe Source'
    };
  }
}
