import { Routes, Route } from 'react-router-dom';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import DailyExpense from './pages/DailyExpense';
import LoansCredit from './pages/LoansCredit';
import Monetary from './pages/Monetary';
import Events from './pages/Events';
import About from './pages/About';

export default function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<Dashboard />} />
        <Route path="daily-expense" element={<DailyExpense />} />
        <Route path="loans-credit" element={<LoansCredit />} />
        <Route path="monetary" element={<Monetary />} />
        <Route path="events" element={<Events />} />
        <Route path="about" element={<About />} />
      </Route>
    </Routes>
  );
}
