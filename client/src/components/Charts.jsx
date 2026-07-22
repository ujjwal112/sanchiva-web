import {
  Chart as ChartJS,
  ArcElement,
  Tooltip,
  Legend,
  CategoryScale,
  LinearScale,
  BarElement,
  PointElement,
  LineElement,
  Filler,
} from 'chart.js';
import { Pie, Doughnut, Bar, Line } from 'react-chartjs-2';
import { useTheme } from '../theme/ThemeContext';

ChartJS.register(
  ArcElement,
  Tooltip,
  Legend,
  CategoryScale,
  LinearScale,
  BarElement,
  PointElement,
  LineElement,
  Filler
);

/** Light theme palette */
const PALETTE_LIGHT = [
  '#3ecf8e',
  '#ff9f1c',
  '#7c6cff',
  '#22d3ee',
  '#f43f5e',
  '#a3e635',
  '#fb7185',
  '#38bdf8',
  '#c084fc',
  '#fbbf24',
  '#34d399',
  '#e879f9',
];

/**
 * Dark theme palette — brighter / neon-glass so series pop on dark cards
 * (mint, amber, violet, cyan, rose, lime…)
 */
const PALETTE_DARK = [
  '#5eead4', // teal mint
  '#fbbf24', // gold
  '#a78bfa', // soft violet
  '#67e8f9', // bright cyan
  '#fb7185', // rose
  '#bef264', // lime
  '#f472b6', // pink
  '#60a5fa', // blue
  '#c4b5fd', // lavender
  '#fcd34d', // yellow
  '#6ee7b7', // emerald
  '#e879f9', // fuchsia
];

function withAlpha(hex, alpha) {
  const h = hex.replace('#', '');
  const full = h.length === 3 ? h.split('').map((c) => c + c).join('') : h;
  const n = parseInt(full, 16);
  const r = (n >> 16) & 255;
  const g = (n >> 8) & 255;
  const b = n & 255;
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

function isAppDark() {
  if (typeof document === 'undefined') return false;
  return document.documentElement.getAttribute('data-theme') === 'dark';
}

function palette() {
  return isAppDark() ? PALETTE_DARK : PALETTE_LIGHT;
}

function colorAt(i) {
  const p = palette();
  return p[i % p.length];
}

function softAt(i) {
  // Dark mode: more opaque fills so bars/slices don’t look muddy
  return withAlpha(colorAt(i), isAppDark() ? 0.88 : 0.78);
}

function glowAt(i) {
  return withAlpha(colorAt(i), isAppDark() ? 0.35 : 0.22);
}

const fontFamily = "'Inter', system-ui, sans-serif";

function chartChrome() {
  const dark = isAppDark();
  return {
    dark,
    legend: dark ? 'rgba(255,255,255,0.88)' : '#3a3a3a',
    ticks: dark ? 'rgba(255,255,255,0.72)' : '#5a5a5a',
    grid: dark ? 'rgba(255,255,255,0.1)' : 'rgba(0, 0, 0, 0.06)',
    // Dark: subtle ring between slices; light: white glass edge
    pieBorder: dark ? 'rgba(12, 12, 16, 0.92)' : 'rgba(255, 255, 255, 0.92)',
    pieHoverBorder: dark ? 'rgba(255,255,255,0.85)' : '#fff',
    tooltipBg: dark ? 'rgba(18, 16, 24, 0.94)' : 'rgba(28, 24, 26, 0.88)',
    tooltipBorder: dark ? 'rgba(255,255,255,0.22)' : 'rgba(255,255,255,0.18)',
  };
}

function baseOptions() {
  const c = chartChrome();
  return {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'bottom',
        labels: {
          color: c.legend,
          boxWidth: 12,
          boxHeight: 12,
          borderRadius: 4,
          useBorderRadius: true,
          padding: 14,
          font: { family: fontFamily, size: 11, weight: '500' },
        },
      },
      tooltip: {
        backgroundColor: c.tooltipBg,
        titleColor: '#fff',
        bodyColor: 'rgba(255,255,255,0.9)',
        borderColor: c.tooltipBorder,
        borderWidth: 1,
        padding: 12,
        cornerRadius: 12,
        titleFont: { family: fontFamily, size: 12, weight: '600' },
        bodyFont: { family: fontFamily, size: 11 },
        displayColors: true,
        boxPadding: 4,
      },
    },
  };
}

function scaleOpts() {
  const c = chartChrome();
  return {
    ticks: {
      color: c.ticks,
      font: { family: fontFamily, size: 11 },
      padding: 8,
    },
    grid: {
      color: c.grid,
      drawBorder: false,
    },
    border: { display: false },
  };
}

export function PieChart({ labels = [], values = [], doughnut = false }) {
  const { theme } = useTheme();
  const chrome = chartChrome();
  const base = baseOptions();
  const data = {
    labels,
    datasets: [
      {
        data: values,
        backgroundColor: labels.map((_, i) => softAt(i)),
        borderColor: chrome.pieBorder,
        borderWidth: chrome.dark ? 2.5 : 3,
        hoverOffset: 12,
        hoverBorderColor: chrome.pieHoverBorder,
        hoverBorderWidth: 3,
        hoverBackgroundColor: labels.map((_, i) => colorAt(i)),
      },
    ],
  };
  const options = {
    ...base,
    cutout: doughnut ? (chrome.dark ? '62%' : '58%') : undefined,
    plugins: {
      ...base.plugins,
      legend: {
        ...base.plugins.legend,
        labels: {
          ...base.plugins.legend.labels,
          generateLabels: (chart) =>
            (chart.data.labels || []).map((label, i) => ({
              text: String(label),
              fillStyle: colorAt(i),
              strokeStyle: colorAt(i),
              hidden: false,
              index: i,
              fontColor: chrome.legend,
            })),
        },
      },
    },
  };
  const Comp = doughnut ? Doughnut : Pie;
  return (
    <div className={`chart-box chart-box--${theme}`} key={theme}>
      {labels.length ? (
        <Comp data={data} options={options} />
      ) : (
        <div className="empty">No data yet</div>
      )}
    </div>
  );
}

export function BarChart({ labels = [], values = [], label = 'Amount', horizontal = false }) {
  const { theme } = useTheme();
  const dark = isAppDark();
  const data = {
    labels,
    datasets: [
      {
        label,
        data: values,
        backgroundColor: labels.map((_, i) => softAt(i)),
        hoverBackgroundColor: labels.map((_, i) => colorAt(i)),
        borderColor: labels.map((_, i) => withAlpha(colorAt(i), dark ? 0.65 : 0.35)),
        borderWidth: dark ? 1.5 : 1,
        borderRadius: 10,
        borderSkipped: false,
        maxBarThickness: 42,
      },
    ],
  };
  const scales = scaleOpts();
  const options = {
    ...baseOptions(),
    indexAxis: horizontal ? 'y' : 'x',
    scales: {
      x: scales,
      y: scales,
    },
  };
  return (
    <div className={`chart-box chart-box--${theme}`} key={theme}>
      {labels.length ? (
        <Bar data={data} options={options} />
      ) : (
        <div className="empty">No data yet</div>
      )}
    </div>
  );
}

export function MultiBarChart({ labels = [], datasets = [] }) {
  const { theme } = useTheme();
  const dark = isAppDark();
  const data = {
    labels,
    datasets: datasets.map((ds, i) => ({
      label: ds.label,
      data: ds.values,
      backgroundColor: softAt(i),
      hoverBackgroundColor: colorAt(i),
      borderColor: withAlpha(colorAt(i), dark ? 0.65 : 0.4),
      borderWidth: dark ? 1.5 : 1,
      borderRadius: 8,
      borderSkipped: false,
      maxBarThickness: 36,
    })),
  };
  const scales = scaleOpts();
  const options = {
    ...baseOptions(),
    scales: { x: scales, y: scales },
  };
  return (
    <div className={`chart-box chart-box--${theme}`} key={theme}>
      {labels.length ? (
        <Bar data={data} options={options} />
      ) : (
        <div className="empty">No data yet</div>
      )}
    </div>
  );
}

export function LineChart({ labels = [], values = [], label = 'Total' }) {
  const { theme } = useTheme();
  const dark = isAppDark();
  const lineColor = dark ? '#a78bfa' : '#7c6cff';
  const pointHover = dark ? '#67e8f9' : '#22d3ee';

  const data = {
    labels,
    datasets: [
      {
        label,
        data: values,
        borderColor: lineColor,
        backgroundColor: (ctx) => {
          const chart = ctx.chart;
          const { ctx: c, chartArea } = chart;
          if (!chartArea) {
            return dark ? 'rgba(167, 139, 250, 0.2)' : 'rgba(124, 108, 255, 0.12)';
          }
          const g = c.createLinearGradient(0, chartArea.top, 0, chartArea.bottom);
          if (dark) {
            g.addColorStop(0, 'rgba(167, 139, 250, 0.45)');
            g.addColorStop(0.45, 'rgba(103, 232, 249, 0.18)');
            g.addColorStop(1, 'rgba(94, 234, 212, 0.02)');
          } else {
            g.addColorStop(0, 'rgba(124, 108, 255, 0.35)');
            g.addColorStop(0.55, 'rgba(34, 211, 238, 0.12)');
            g.addColorStop(1, 'rgba(62, 207, 142, 0.02)');
          }
          return g;
        },
        fill: true,
        tension: 0.42,
        borderWidth: dark ? 3 : 2.5,
        pointBackgroundColor: dark ? '#1a1820' : '#fff',
        pointBorderColor: lineColor,
        pointBorderWidth: 2,
        pointRadius: 4,
        pointHoverRadius: 7,
        pointHoverBackgroundColor: pointHover,
        pointHoverBorderColor: '#fff',
        pointHoverBorderWidth: 2,
      },
    ],
  };
  const scales = scaleOpts();
  const options = {
    ...baseOptions(),
    scales: { x: scales, y: scales },
  };
  return (
    <div className={`chart-box chart-box--${theme}`} key={theme}>
      {labels.length ? (
        <Line data={data} options={options} />
      ) : (
        <div className="empty">No data yet</div>
      )}
    </div>
  );
}

export function categoryChartData(byCategory) {
  if (!byCategory) return { labels: [], values: [] };
  if (Array.isArray(byCategory)) {
    return {
      labels: byCategory.map((c) => c.name || c.category),
      values: byCategory.map((c) => Number(c.amount)),
    };
  }
  return {
    labels: Object.keys(byCategory),
    values: Object.values(byCategory).map(Number),
  };
}
