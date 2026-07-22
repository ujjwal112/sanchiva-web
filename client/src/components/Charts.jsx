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

/**
 * Colorful chart palette — liquid-glass friendly (mint / amber / coral / violet / cyan).
 * Matches landing iridescent accents on light glass cards.
 */
const PALETTE = [
  '#3ecf8e', // mint
  '#ff9f1c', // amber
  '#7c6cff', // violet
  '#22d3ee', // cyan
  '#f43f5e', // rose
  '#a3e635', // lime
  '#fb7185', // soft coral
  '#38bdf8', // sky
  '#c084fc', // purple
  '#fbbf24', // gold
  '#34d399', // emerald
  '#e879f9', // fuchsia
];

const PALETTE_SOFT = PALETTE.map((hex) => withAlpha(hex, 0.78));
const PALETTE_GLOW = PALETTE.map((hex) => withAlpha(hex, 0.22));

function withAlpha(hex, alpha) {
  const h = hex.replace('#', '');
  const full = h.length === 3 ? h.split('').map((c) => c + c).join('') : h;
  const n = parseInt(full, 16);
  const r = (n >> 16) & 255;
  const g = (n >> 8) & 255;
  const b = n & 255;
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

function colorAt(i) {
  return PALETTE[i % PALETTE.length];
}

function softAt(i) {
  return PALETTE_SOFT[i % PALETTE_SOFT.length];
}

const fontFamily = "'Inter', system-ui, sans-serif";

/** Use theme from React context — not DOM — so charts update in the same render as the toggle. */
function chartChrome(theme) {
  const dark = theme === 'dark';
  return {
    legend: dark ? 'rgba(255,255,255,0.88)' : '#1a1a1a',
    ticks: dark ? 'rgba(255,255,255,0.72)' : '#3a3a3a',
    grid: dark ? 'rgba(255,255,255,0.1)' : 'rgba(0, 0, 0, 0.08)',
    pieBorder: dark ? 'rgba(20, 18, 22, 0.9)' : 'rgba(255, 255, 255, 0.95)',
  };
}

function baseOptions(theme) {
  const c = chartChrome(theme);
  return {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'bottom',
        labels: {
          color: c.legend,
          boxWidth: 11,
          boxHeight: 11,
          borderRadius: 3,
          useBorderRadius: true,
          padding: 14,
          font: { family: fontFamily, size: 11, weight: '500' },
        },
      },
      tooltip: {
        backgroundColor: 'rgba(28, 24, 26, 0.92)',
        titleColor: '#fff',
        bodyColor: 'rgba(255,255,255,0.9)',
        borderColor: 'rgba(255,255,255,0.2)',
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

function scaleOpts(theme) {
  const c = chartChrome(theme);
  return {
    ticks: {
      color: c.ticks,
      font: { family: fontFamily, size: 11 },
      padding: 6,
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
  const chrome = chartChrome(theme);
  const base = baseOptions(theme);
  const data = {
    labels,
    datasets: [
      {
        data: values,
        backgroundColor: labels.map((_, i) => softAt(i)),
        borderColor: chrome.pieBorder,
        borderWidth: 3,
        hoverOffset: 10,
        hoverBorderColor: '#fff',
        hoverBorderWidth: 3,
      },
    ],
  };
  const options = {
    ...base,
    cutout: doughnut ? '58%' : undefined,
    plugins: {
      ...base.plugins,
      legend: {
        ...base.plugins.legend,
        labels: {
          ...base.plugins.legend.labels,
          color: chrome.legend,
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
    <div className="chart-box" key={`pie-${theme}`}>
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
  const data = {
    labels,
    datasets: [
      {
        label,
        data: values,
        backgroundColor: labels.map((_, i) => softAt(i)),
        hoverBackgroundColor: labels.map((_, i) => colorAt(i)),
        borderColor: labels.map((_, i) => withAlpha(colorAt(i), 0.35)),
        borderWidth: 1,
        borderRadius: 10,
        borderSkipped: false,
        maxBarThickness: 42,
      },
    ],
  };
  const scales = scaleOpts(theme);
  const options = {
    ...baseOptions(theme),
    indexAxis: horizontal ? 'y' : 'x',
    scales: {
      x: scales,
      y: scales,
    },
  };
  return (
    <div className="chart-box" key={`bar-${theme}`}>
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
  const data = {
    labels,
    datasets: datasets.map((ds, i) => ({
      label: ds.label,
      data: ds.values,
      backgroundColor: softAt(i),
      hoverBackgroundColor: colorAt(i),
      borderColor: withAlpha(colorAt(i), 0.4),
      borderWidth: 1,
      borderRadius: 8,
      borderSkipped: false,
      maxBarThickness: 36,
    })),
  };
  const scales = scaleOpts(theme);
  const options = {
    ...baseOptions(theme),
    scales: { x: scales, y: scales },
  };
  return (
    <div className="chart-box" key={`mbar-${theme}`}>
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
  const data = {
    labels,
    datasets: [
      {
        label,
        data: values,
        borderColor: '#7c6cff',
        backgroundColor: (ctx) => {
          const chart = ctx.chart;
          const { ctx: c, chartArea } = chart;
          if (!chartArea) return 'rgba(124, 108, 255, 0.12)';
          const g = c.createLinearGradient(0, chartArea.top, 0, chartArea.bottom);
          g.addColorStop(0, 'rgba(124, 108, 255, 0.35)');
          g.addColorStop(0.55, 'rgba(34, 211, 238, 0.12)');
          g.addColorStop(1, 'rgba(62, 207, 142, 0.02)');
          return g;
        },
        fill: true,
        tension: 0.42,
        borderWidth: 2.5,
        pointBackgroundColor: theme === 'dark' ? '#1a1820' : '#fff',
        pointBorderColor: '#7c6cff',
        pointBorderWidth: 2,
        pointRadius: 4,
        pointHoverRadius: 6,
        pointHoverBackgroundColor: '#22d3ee',
        pointHoverBorderColor: '#fff',
      },
    ],
  };
  const scales = scaleOpts(theme);
  const options = {
    ...baseOptions(theme),
    scales: { x: scales, y: scales },
  };
  return (
    <div className="chart-box" key={`line-${theme}`}>
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
