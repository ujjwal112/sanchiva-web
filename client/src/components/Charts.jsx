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

const PALETTE = [
  '#7c6cff',
  '#22d3ee',
  '#f472b6',
  '#34d399',
  '#fbbf24',
  '#60a5fa',
  '#a78bfa',
  '#fb7185',
  '#2dd4bf',
  '#c084fc',
];

const baseOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      position: 'bottom',
      labels: {
        color: '#94a3b8',
        boxWidth: 12,
        padding: 14,
        font: { family: 'Outfit', size: 11 },
      },
    },
    tooltip: {
      backgroundColor: 'rgba(15, 20, 40, 0.92)',
      titleColor: '#fff',
      bodyColor: '#cbd5e1',
      borderColor: 'rgba(255,255,255,0.1)',
      borderWidth: 1,
      padding: 10,
      cornerRadius: 10,
    },
  },
};

const scaleOpts = {
  ticks: { color: '#94a3b8', font: { family: 'Outfit', size: 11 } },
  grid: { color: 'rgba(255,255,255,0.06)' },
  border: { display: false },
};

export function PieChart({ labels = [], values = [], doughnut = false }) {
  const data = {
    labels,
    datasets: [
      {
        data: values,
        backgroundColor: labels.map((_, i) => PALETTE[i % PALETTE.length]),
        borderColor: 'rgba(11, 16, 32, 0.6)',
        borderWidth: 2,
        hoverOffset: 8,
      },
    ],
  };
  const Comp = doughnut ? Doughnut : Pie;
  return (
    <div className="chart-box">
      {labels.length ? (
        <Comp data={data} options={baseOptions} />
      ) : (
        <div className="empty">No data yet</div>
      )}
    </div>
  );
}

export function BarChart({ labels = [], values = [], label = 'Amount', horizontal = false }) {
  const data = {
    labels,
    datasets: [
      {
        label,
        data: values,
        backgroundColor: labels.map((_, i) => PALETTE[i % PALETTE.length] + 'cc'),
        borderRadius: 8,
        borderSkipped: false,
      },
    ],
  };
  const options = {
    ...baseOptions,
    indexAxis: horizontal ? 'y' : 'x',
    scales: {
      x: scaleOpts,
      y: scaleOpts,
    },
  };
  return (
    <div className="chart-box">
      {labels.length ? (
        <Bar data={data} options={options} />
      ) : (
        <div className="empty">No data yet</div>
      )}
    </div>
  );
}

export function MultiBarChart({ labels = [], datasets = [] }) {
  const data = {
    labels,
    datasets: datasets.map((ds, i) => ({
      label: ds.label,
      data: ds.values,
      backgroundColor: PALETTE[i % PALETTE.length] + 'cc',
      borderRadius: 6,
    })),
  };
  const options = {
    ...baseOptions,
    scales: { x: scaleOpts, y: scaleOpts },
  };
  return (
    <div className="chart-box">
      {labels.length ? (
        <Bar data={data} options={options} />
      ) : (
        <div className="empty">No data yet</div>
      )}
    </div>
  );
}

export function LineChart({ labels = [], values = [], label = 'Total' }) {
  const data = {
    labels,
    datasets: [
      {
        label,
        data: values,
        borderColor: '#7c6cff',
        backgroundColor: 'rgba(124, 108, 255, 0.15)',
        fill: true,
        tension: 0.4,
        pointBackgroundColor: '#22d3ee',
        pointRadius: 4,
      },
    ],
  };
  const options = {
    ...baseOptions,
    scales: { x: scaleOpts, y: scaleOpts },
  };
  return (
    <div className="chart-box">
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
