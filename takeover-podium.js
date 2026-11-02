/* Shared league podium. Rank and points come from the leaderboard, never from the visual slot. */
(function () {
  'use strict';
  const number = value => {
    if (value == null || String(value).trim() === '') return null;
    const n = Number(String(value).replace(/[’'\s]/g, ''));
    return Number.isFinite(n) ? n : null;
  };
  const fmt = n => Number(n).toLocaleString('de-CH', {maximumFractionDigits: 0});
  function entries(rows) {
    return (Array.isArray(rows) ? rows : []).map((row, index) => ({
      name: String(row.boxer_name ?? row.name ?? '').trim(),
      points: number(row.monthly_points ?? row.points),
      rank: number(row.rank_position ?? row.rank), index, source: row
    })).filter(row => row.name && row.points !== null)
      .sort((a, b) => (a.rank > 0 ? a.rank : Infinity) - (b.rank > 0 ? b.rank : Infinity) || b.points - a.points || a.index - b.index)
      .slice(0, 3);
  }
  function render(host, rows, options = {}) {
    if (!host) return;
    host.replaceChildren();
    host.classList.add('tl-league-podium','tl-podium');
    const top = entries(rows);
    const scored = top.some(row => row.points > 0);
    const tied = scored && top.filter(row => row.rank === top[0].rank && row.points > 0).length > 1;
    host.dataset.scored = String(scored);
    const heading = document.createElement('div');
    heading.className = 'tl-podium-heading';
    const title = document.createElement('strong');
    title.textContent = scored ? 'Die Spitze der Liga' : 'Der nächste Aufstieg beginnt hier';
    const note = document.createElement('span');
    note.textContent = !top.length ? 'Noch keine Boxer in der Rangliste.' : !scored ? 'Noch keine bestätigten Monatspunkte.' : tied ? 'Gleichstand an der Spitze · aktueller Monatsstand' : 'Aktueller Monatsstand · noch kein Monatsabschluss';
    heading.append(title, note);
    host.append(heading);
    const arena = document.createElement('div');
    arena.className = 'tl-podium-arena';
    arena.setAttribute('role', 'list');
    arena.setAttribute('aria-label', 'Aktuelle Top 3 der Monatsrangliste');
    for (const slot of [1, 0, 2]) {
      const boxer = top[slot];
      const ranked = boxer && boxer.points > 0 && boxer.rank > 0;
      const step = document.createElement(boxer ? 'a' : 'div');
      step.className = 'tl-podium-person tl-podium-step tl-podium-' + (slot + 1) + ' ex-step ' + ['first','second','third'][slot];
      step.setAttribute('role', 'listitem');
      step.dataset.tlLookScope = '1';
      step.dataset.rank = ranked ? String(boxer.rank) : 'unranked';
      step.dataset.empty = String(!boxer);
      if (boxer) {
        step.href = './boxer-profile.html?name=' + encodeURIComponent(boxer.name);
        step.setAttribute('aria-label', (ranked ? 'Platz ' + boxer.rank : 'Noch ohne Wertung') + ': ' + boxer.name + ', ' + fmt(boxer.points) + ' Punkte. Profil ansehen.');
      }
      const caption = document.createElement('div');
      caption.className = 'tl-podium-caption';
      const name = document.createElement('strong');
      name.className = 'tl-podium-person-name tl-podium-name ex-step-name';
      name.textContent = boxer ? boxer.name : 'Noch offen';
      const points = document.createElement('span');
      points.className = 'tl-podium-person-points';
      points.textContent = boxer ? fmt(boxer.points) + ' P' : '–';
      caption.append(name, points);
      const figure = document.createElement('div');
      figure.className = 'tl-podium-figure ex-podium-holo';
      if (boxer && typeof options.figure === 'function') {
        const content = options.figure(boxer.source);
        if (typeof content === 'string') figure.innerHTML = content;
        else if (content instanceof Node) figure.append(content);
      }
      if (!figure.childElementCount) {
        const marker = document.createElement('span');
        marker.className = 'tl-podium-placeholder';
        marker.textContent = boxer ? '🥊' : '—';
        marker.setAttribute('role', 'img');
        marker.setAttribute('aria-label', boxer ? 'Figur derzeit nicht verfügbar' : 'Freier Podiumsplatz');
        figure.append(marker);
      }
      // Align the complete transparent character canvas to the plinth, without cropping its pose.
      figure.querySelector('svg')?.setAttribute('preserveAspectRatio', 'xMidYMax meet');
      const plinth = document.createElement('div');
      plinth.className = 'tl-podium-plinth tl-podium-block';
      plinth.setAttribute('aria-hidden', 'true');
      if (ranked && boxer.rank === 1) {
        const crown = document.createElement('span');
        crown.className = 'tl-podium-crown';
        crown.textContent = '♛';
        plinth.append(crown);
      }
      const rank = document.createElement('b');
      rank.textContent = ranked ? String(boxer.rank) : '–';
      plinth.append(rank);
      step.append(caption, figure, plinth);
      arena.append(step);
    }
    host.append(arena);
  }
  window.TLLeaguePodium = Object.freeze({render, entries});
})();
