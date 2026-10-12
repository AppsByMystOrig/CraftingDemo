document.getElementById('year').textContent = new Date().getFullYear();

// Section tabs: each card shows its own panel below.
const tabs = Array.from(document.querySelectorAll('.card'));

function select(tab) {
  tabs.forEach((t) => {
    const selected = t === tab;
    t.setAttribute('aria-selected', selected);
    t.tabIndex = selected ? 0 : -1;
    document.getElementById(t.getAttribute('aria-controls')).hidden = !selected;
  });
}

tabs.forEach((tab, i) => {
  tab.addEventListener('click', () => {
    select(tab);
    history.replaceState(null, '', '#' + tab.dataset.section);
  });
  tab.addEventListener('keydown', (e) => {
    const step = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }[e.key];
    if (!step) return;
    e.preventDefault();
    const next = tabs[(i + step + tabs.length) % tabs.length];
    next.click();
    next.focus();
  });
});

// Open the section named in the address (e.g. #music), otherwise the first.
select(tabs.find((t) => t.dataset.section === location.hash.slice(1)) || tabs[0]);
