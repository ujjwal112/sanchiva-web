import { Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './auth/AuthContext';
import Layout from './components/Layout';
import ProtectedRoute from './components/ProtectedRoute';
import Dashboard from './pages/Dashboard';
import DailyExpense from './pages/DailyExpense';
import LoansCredit from './pages/LoansCredit';
import Monetary from './pages/Monetary';
import Events from './pages/Events';
import About from './pages/About';
import Login from './pages/Login';
import AuthCallback from './pages/AuthCallback';

export default function App() {
  return (
    <AuthProvider>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/auth/callback" element={<AuthCallback />} />
        <Route
          element={
            <ProtectedRoute>
              <Layout />
            </ProtectedRoute>
          }
        >
          <Route index element={<Dashboard />} />
          <Route path="daily-expense" element={<DailyExpense />} />
          <Route path="loans-credit" element={<LoansCredit />} />
          <Route path="monetary" element={<Monetary />} />
          <Route path="events" element={<Events />} />
          <Route path="about" element={<About />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AuthProvider>
  );
}
