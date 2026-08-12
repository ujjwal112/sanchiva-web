import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, userId } from '../auth/middleware.js';

const router = Router();
router.use(requireAuth);

async function assertGroupOwner(groupId, uid) {
  const { rows } = await query(
    'SELECT * FROM split_groups WHERE id = $1 AND user_id = $2',
    [groupId, uid]
  );
  return rows[0] || null;
}

/** Net balance per member: + means others owe them, - means they owe */
async function computeBalances(groupId) {
  const { rows: members } = await query(
    'SELECT * FROM split_members WHERE group_id = $1 ORDER BY is_you DESC, id ASC',
    [groupId]
  );
  const bal = {};
  for (const m of members) bal[m.id] = 0;

  const { rows: paid } = await query(
    `SELECT paid_by_member_id AS mid, COALESCE(SUM(amount),0)::float AS total
     FROM split_expenses WHERE group_id = $1 GROUP BY paid_by_member_id`,
    [groupId]
  );
  for (const r of paid) {
    if (bal[r.mid] !== undefined) bal[r.mid] += Number(r.total);
  }

  const { rows: shares } = await query(
    `SELECT s.member_id AS mid, COALESCE(SUM(s.share_amount),0)::float AS total
     FROM split_shares s
     JOIN split_expenses e ON e.id = s.expense_id
     WHERE e.group_id = $1
     GROUP BY s.member_id`,
    [groupId]
  );
  for (const r of shares) {
    if (bal[r.mid] !== undefined) bal[r.mid] -= Number(r.total);
  }

  // Settlement: from pays to → from balance ↑, to balance ↓
  const { rows: settles } = await query(
    `SELECT from_member_id, to_member_id, amount::float AS amount
     FROM split_settlements WHERE group_id = $1`,
    [groupId]
  );
  for (const s of settles) {
    if (bal[s.from_member_id] !== undefined) bal[s.from_member_id] += Number(s.amount);
    if (bal[s.to_member_id] !== undefined) bal[s.to_member_id] -= Number(s.amount);
  }

  return members.map((m) => ({
    id: m.id,
    name: m.name,
    is_you: m.is_you,
    balance: Math.round((bal[m.id] || 0) * 100) / 100,
  }));
}

/** Equal-split share rows (cent rounding). */
function buildEqualShares(amount, memberIds) {
  const n = memberIds.length;
  const cents = Math.round(Number(amount) * 100);
  const base = Math.floor(cents / n);
  let rem = cents - base * n;
  return memberIds.map((mid) => {
    const c = base + (rem > 0 ? 1 : 0);
    if (rem > 0) rem -= 1;
    return { member_id: mid, share_amount: c / 100 };
  });
}

/** Pairwise simplify: who should pay whom */
function simplifyDebts(balances) {
  const creditors = balances
    .filter((b) => b.balance > 0.009)
    .map((b) => ({ ...b }))
    .sort((a, b) => b.balance - a.balance);
  const debtors = balances
    .filter((b) => b.balance < -0.009)
    .map((b) => ({ ...b, balance: -b.balance }))
    .sort((a, b) => b.balance - a.balance);

  const transfers = [];
  let i = 0;
  let j = 0;
  while (i < debtors.length && j < creditors.length) {
    const pay = Math.min(debtors[i].balance, creditors[j].balance);
    if (pay > 0.009) {
      transfers.push({
        from_member_id: debtors[i].id,
        from_name: debtors[i].name,
        to_member_id: creditors[j].id,
        to_name: creditors[j].name,
        amount: Math.round(pay * 100) / 100,
      });
    }
    debtors[i].balance -= pay;
    creditors[j].balance -= pay;
    if (debtors[i].balance < 0.01) i += 1;
    if (creditors[j].balance < 0.01) j += 1;
  }
  return transfers;
}

// ── Groups list ────────────────────────────────────────────────────────────
router.get('/groups', async (req, res) => {
  try {
    const uid = userId(req);
    const { rows: groups } = await query(
      `SELECT g.*,
              (SELECT COUNT(*)::int FROM split_members m WHERE m.group_id = g.id) AS member_count,
              (SELECT COALESCE(SUM(e.amount),0)::float FROM split_expenses e WHERE e.group_id = g.id) AS total_spent
       FROM split_groups g
       WHERE g.user_id = $1
       ORDER BY g.updated_at DESC, g.id DESC`,
      [uid]
    );

    const out = [];
    for (const g of groups) {
      const balances = await computeBalances(g.id);
      const you = balances.find((b) => b.is_you);
      out.push({
        ...g,
        your_balance: you ? you.balance : 0,
        balances,
      });
    }
    res.json(out);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Create group ───────────────────────────────────────────────────────────
router.post('/groups', async (req, res) => {
  try {
    const uid = userId(req);
    const { name, notes, members } = req.body;
    if (!name || !String(name).trim()) {
      return res.status(400).json({ error: 'Group name required' });
    }
    const memberNames = Array.isArray(members)
      ? members.map((m) => String(m).trim()).filter(Boolean)
      : [];

    const { rows } = await query(
      `INSERT INTO split_groups (user_id, name, notes) VALUES ($1,$2,$3) RETURNING *`,
      [uid, String(name).trim(), notes || null]
    );
    const group = rows[0];

    await query(
      `INSERT INTO split_members (group_id, name, is_you) VALUES ($1, 'You', TRUE)`,
      [group.id]
    );
    for (const mn of memberNames) {
      if (mn.toLowerCase() === 'you') continue;
      await query(
        `INSERT INTO split_members (group_id, name, is_you) VALUES ($1, $2, FALSE)`,
        [group.id, mn]
      );
    }

    const { rows: fullMembers } = await query(
      'SELECT * FROM split_members WHERE group_id = $1 ORDER BY is_you DESC, id ASC',
      [group.id]
    );
    res.status(201).json({ ...group, members: fullMembers, your_balance: 0 });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Group detail ───────────────────────────────────────────────────────────
router.get('/groups/:id', async (req, res) => {
  try {
    const uid = userId(req);
    const group = await assertGroupOwner(req.params.id, uid);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const { rows: members } = await query(
      'SELECT * FROM split_members WHERE group_id = $1 ORDER BY is_you DESC, id ASC',
      [group.id]
    );
    const balances = await computeBalances(group.id);
    const transfers = simplifyDebts(balances);

    const { rows: expenses } = await query(
      `SELECT e.*,
              m.name AS paid_by_name,
              m.is_you AS paid_by_is_you,
              (SELECT COUNT(*)::int FROM split_expense_amount_history h WHERE h.expense_id = e.id) AS amount_edit_count
       FROM split_expenses e
       JOIN split_members m ON m.id = e.paid_by_member_id
       WHERE e.group_id = $1
       ORDER BY e.expense_date DESC, e.id DESC`,
      [group.id]
    );

    const expenseIds = expenses.map((e) => e.id);
    const sharesByExpense = {};
    if (expenseIds.length) {
      const { rows: shares } = await query(
        `SELECT s.*, m.name AS member_name, m.is_you
         FROM split_shares s
         JOIN split_members m ON m.id = s.member_id
         WHERE s.expense_id = ANY($1::int[])`,
        [expenseIds]
      );
      for (const s of shares) {
        if (!sharesByExpense[s.expense_id]) sharesByExpense[s.expense_id] = [];
        sharesByExpense[s.expense_id].push(s);
      }
    }

    const historyByExpense = {};
    const recentAmountEdits = [];
    if (expenseIds.length) {
      const { rows: histRows } = await query(
        `SELECT h.id, h.expense_id, h.old_amount, h.new_amount, h.note, h.created_at,
                h.changed_by_user_id, u.name AS changed_by_name,
                e.description AS expense_description
         FROM split_expense_amount_history h
         JOIN split_expenses e ON e.id = h.expense_id
         LEFT JOIN users u ON u.id = h.changed_by_user_id
         WHERE h.expense_id = ANY($1::int[])
         ORDER BY h.created_at DESC, h.id DESC`,
        [expenseIds]
      );
      for (const h of histRows) {
        const row = {
          ...h,
          old_amount: Number(h.old_amount),
          new_amount: Number(h.new_amount),
        };
        if (!historyByExpense[h.expense_id]) historyByExpense[h.expense_id] = [];
        historyByExpense[h.expense_id].push(row);
        if (recentAmountEdits.length < 20) recentAmountEdits.push(row);
      }
    }

    const expensesOut = expenses.map((e) => {
      const hist = historyByExpense[e.id] || [];
      const last = hist[0] || null;
      return {
        ...e,
        amount: Number(e.amount),
        amount_edit_count: Number(e.amount_edit_count) || hist.length,
        amount_history: hist,
        last_amount_change: last
          ? {
              old_amount: last.old_amount,
              new_amount: last.new_amount,
              created_at: last.created_at,
              note: last.note,
              changed_by_name: last.changed_by_name,
            }
          : null,
        shares: (sharesByExpense[e.id] || []).map((s) => ({
          ...s,
          share_amount: Number(s.share_amount),
        })),
      };
    });

    const { rows: settlements } = await query(
      `SELECT s.*,
              f.name AS from_name, f.is_you AS from_is_you,
              t.name AS to_name, t.is_you AS to_is_you
       FROM split_settlements s
       JOIN split_members f ON f.id = s.from_member_id
       JOIN split_members t ON t.id = s.to_member_id
       WHERE s.group_id = $1
       ORDER BY s.settled_date DESC, s.id DESC`,
      [group.id]
    );

    const totalSpent = expensesOut.reduce((s, e) => s + e.amount, 0);
    const you = balances.find((b) => b.is_you);

    res.json({
      ...group,
      members,
      balances,
      transfers,
      expenses: expensesOut,
      recent_amount_edits: recentAmountEdits,
      settlements: settlements.map((s) => ({ ...s, amount: Number(s.amount) })),
      total_spent: totalSpent,
      your_balance: you ? you.balance : 0,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Update group ───────────────────────────────────────────────────────────
router.put('/groups/:id', async (req, res) => {
  try {
    const uid = userId(req);
    const group = await assertGroupOwner(req.params.id, uid);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    const { name, notes } = req.body;
    const { rows } = await query(
      `UPDATE split_groups SET
         name = COALESCE($1, name),
         notes = COALESCE($2, notes),
         updated_at = NOW()
       WHERE id = $3 RETURNING *`,
      [name != null ? String(name).trim() : null, notes, group.id]
    );
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Delete group ───────────────────────────────────────────────────────────
router.delete('/groups/:id', async (req, res) => {
  try {
    const uid = userId(req);
    const group = await assertGroupOwner(req.params.id, uid);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    await query('DELETE FROM split_groups WHERE id = $1', [group.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Add member ─────────────────────────────────────────────────────────────
router.post('/groups/:id/members', async (req, res) => {
  try {
    const uid = userId(req);
    const group = await assertGroupOwner(req.params.id, uid);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    const name = String(req.body.name || '').trim();
    if (!name) return res.status(400).json({ error: 'Name required' });
    if (name.toLowerCase() === 'you') {
      return res.status(400).json({ error: 'Name "You" is reserved' });
    }
    const { rows } = await query(
      `INSERT INTO split_members (group_id, name, is_you) VALUES ($1,$2,FALSE) RETURNING *`,
      [group.id, name]
    );
    await query(`UPDATE split_groups SET updated_at = NOW() WHERE id = $1`, [group.id]);
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Add expense (equal split among selected members) ───────────────────────
router.post('/groups/:id/expenses', async (req, res) => {
  try {
    const uid = userId(req);
    const group = await assertGroupOwner(req.params.id, uid);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const {
      description,
      amount,
      paid_by_member_id,
      expense_date,
      notes,
      split_member_ids,
    } = req.body;

    const amt = Number(amount);
    if (!description || !String(description).trim()) {
      return res.status(400).json({ error: 'Description required' });
    }
    if (!amt || amt <= 0) return res.status(400).json({ error: 'Valid amount required' });
    if (!paid_by_member_id) return res.status(400).json({ error: 'paid_by_member_id required' });
    if (!expense_date) return res.status(400).json({ error: 'expense_date required' });

    let memberIds = Array.isArray(split_member_ids)
      ? split_member_ids.map(Number).filter((n) => n > 0)
      : [];

    if (!memberIds.length) {
      const { rows: allM } = await query(
        'SELECT id FROM split_members WHERE group_id = $1',
        [group.id]
      );
      memberIds = allM.map((m) => m.id);
    }

    const { rows: validMembers } = await query(
      `SELECT id FROM split_members WHERE group_id = $1 AND id = ANY($2::int[])`,
      [group.id, memberIds]
    );
    if (validMembers.length !== memberIds.length) {
      return res.status(400).json({ error: 'Invalid members in split' });
    }
    const { rows: payerCheck } = await query(
      'SELECT id FROM split_members WHERE group_id = $1 AND id = $2',
      [group.id, paid_by_member_id]
    );
    if (!payerCheck[0]) return res.status(400).json({ error: 'Invalid paid_by member' });

    const shares = buildEqualShares(amt, memberIds);

    const { rows: expRows } = await query(
      `INSERT INTO split_expenses
         (group_id, description, amount, paid_by_member_id, expense_date, notes)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [
        group.id,
        String(description).trim(),
        amt,
        paid_by_member_id,
        expense_date,
        notes || null,
      ]
    );
    const expense = expRows[0];

    for (const s of shares) {
      await query(
        `INSERT INTO split_shares (expense_id, member_id, share_amount) VALUES ($1,$2,$3)`,
        [expense.id, s.member_id, s.share_amount]
      );
    }
    await query(`UPDATE split_groups SET updated_at = NOW() WHERE id = $1`, [group.id]);

    const { rows: shareRows } = await query(
      `SELECT s.*, m.name AS member_name, m.is_you
       FROM split_shares s JOIN split_members m ON m.id = s.member_id
       WHERE s.expense_id = $1`,
      [expense.id]
    );

    res.status(201).json({
      ...expense,
      amount: Number(expense.amount),
      amount_edit_count: 0,
      shares: shareRows.map((s) => ({ ...s, share_amount: Number(s.share_amount) })),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Update expense (re-split + amount history) ─────────────────────────────
router.put('/groups/:gid/expenses/:eid', async (req, res) => {
  try {
    const uid = userId(req);
    const group = await assertGroupOwner(req.params.gid, uid);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const { rows: existingRows } = await query(
      'SELECT * FROM split_expenses WHERE id = $1 AND group_id = $2',
      [req.params.eid, group.id]
    );
    const existing = existingRows[0];
    if (!existing) return res.status(404).json({ error: 'Expense not found' });

    const {
      description,
      amount,
      paid_by_member_id,
      expense_date,
      notes,
      split_member_ids,
      history_note,
    } = req.body;

    const amt = amount != null ? Number(amount) : Number(existing.amount);
    const desc =
      description != null ? String(description).trim() : existing.description;
    const payerId = paid_by_member_id != null ? Number(paid_by_member_id) : existing.paid_by_member_id;
    const expDate = expense_date || existing.expense_date;
    const noteVal =
      notes !== undefined ? (notes ? String(notes).trim() : null) : existing.notes;

    if (!desc) return res.status(400).json({ error: 'Description required' });
    if (!amt || amt <= 0) return res.status(400).json({ error: 'Valid amount required' });
    if (!payerId) return res.status(400).json({ error: 'paid_by_member_id required' });
    if (!expDate) return res.status(400).json({ error: 'expense_date required' });

    let memberIds = Array.isArray(split_member_ids)
      ? split_member_ids.map(Number).filter((n) => n > 0)
      : [];

    if (!memberIds.length) {
      // Keep current share members if not sent
      const { rows: currentShares } = await query(
        'SELECT member_id FROM split_shares WHERE expense_id = $1 ORDER BY member_id',
        [existing.id]
      );
      memberIds = currentShares.map((s) => s.member_id);
    }
    if (!memberIds.length) {
      const { rows: allM } = await query(
        'SELECT id FROM split_members WHERE group_id = $1',
        [group.id]
      );
      memberIds = allM.map((m) => m.id);
    }

    const { rows: validMembers } = await query(
      `SELECT id FROM split_members WHERE group_id = $1 AND id = ANY($2::int[])`,
      [group.id, memberIds]
    );
    if (validMembers.length !== memberIds.length) {
      return res.status(400).json({ error: 'Invalid members in split' });
    }
    const { rows: payerCheck } = await query(
      'SELECT id FROM split_members WHERE group_id = $1 AND id = $2',
      [group.id, payerId]
    );
    if (!payerCheck[0]) return res.status(400).json({ error: 'Invalid paid_by member' });

    const oldAmt = Number(existing.amount);
    const amountChanged = Math.round(oldAmt * 100) !== Math.round(amt * 100);

    if (amountChanged) {
      await query(
        `INSERT INTO split_expense_amount_history
           (expense_id, old_amount, new_amount, changed_by_user_id, note)
         VALUES ($1,$2,$3,$4,$5)`,
        [
          existing.id,
          oldAmt,
          amt,
          uid,
          history_note ? String(history_note).trim() : null,
        ]
      );
    }

    const { rows: expRows } = await query(
      `UPDATE split_expenses SET
         description = $1,
         amount = $2,
         paid_by_member_id = $3,
         expense_date = $4,
         notes = $5,
         updated_at = NOW()
       WHERE id = $6 AND group_id = $7
       RETURNING *`,
      [desc, amt, payerId, expDate, noteVal, existing.id, group.id]
    );
    const expense = expRows[0];

    await query('DELETE FROM split_shares WHERE expense_id = $1', [expense.id]);
    const shares = buildEqualShares(amt, memberIds);
    for (const s of shares) {
      await query(
        `INSERT INTO split_shares (expense_id, member_id, share_amount) VALUES ($1,$2,$3)`,
        [expense.id, s.member_id, s.share_amount]
      );
    }
    await query(`UPDATE split_groups SET updated_at = NOW() WHERE id = $1`, [group.id]);

    const { rows: shareRows } = await query(
      `SELECT s.*, m.name AS member_name, m.is_you
       FROM split_shares s JOIN split_members m ON m.id = s.member_id
       WHERE s.expense_id = $1`,
      [expense.id]
    );
    const { rows: histCount } = await query(
      'SELECT COUNT(*)::int AS c FROM split_expense_amount_history WHERE expense_id = $1',
      [expense.id]
    );

    res.json({
      ...expense,
      amount: Number(expense.amount),
      amount_edit_count: histCount[0]?.c || 0,
      amount_changed: amountChanged,
      shares: shareRows.map((s) => ({ ...s, share_amount: Number(s.share_amount) })),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Amount edit history for an expense ─────────────────────────────────────
router.get('/groups/:gid/expenses/:eid/amount-history', async (req, res) => {
  try {
    const uid = userId(req);
    const group = await assertGroupOwner(req.params.gid, uid);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const { rows: exp } = await query(
      'SELECT id FROM split_expenses WHERE id = $1 AND group_id = $2',
      [req.params.eid, group.id]
    );
    if (!exp[0]) return res.status(404).json({ error: 'Expense not found' });

    const { rows } = await query(
      `SELECT h.id, h.expense_id, h.old_amount, h.new_amount, h.note, h.created_at,
              h.changed_by_user_id, u.name AS changed_by_name, u.email AS changed_by_email
       FROM split_expense_amount_history h
       LEFT JOIN users u ON u.id = h.changed_by_user_id
       WHERE h.expense_id = $1
       ORDER BY h.created_at DESC, h.id DESC`,
      [exp[0].id]
    );

    res.json(
      rows.map((r) => ({
        ...r,
        old_amount: Number(r.old_amount),
        new_amount: Number(r.new_amount),
      }))
    );
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Delete expense ─────────────────────────────────────────────────────────
router.delete('/groups/:gid/expenses/:eid', async (req, res) => {
  try {
    const uid = userId(req);
    const group = await assertGroupOwner(req.params.gid, uid);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    const { rowCount } = await query(
      'DELETE FROM split_expenses WHERE id = $1 AND group_id = $2',
      [req.params.eid, group.id]
    );
    if (!rowCount) return res.status(404).json({ error: 'Expense not found' });
    await query(`UPDATE split_groups SET updated_at = NOW() WHERE id = $1`, [group.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Settlement ─────────────────────────────────────────────────────────────
router.post('/groups/:id/settlements', async (req, res) => {
  try {
    const uid = userId(req);
    const group = await assertGroupOwner(req.params.id, uid);
    if (!group) return res.status(404).json({ error: 'Group not found' });

    const { from_member_id, to_member_id, amount, settled_date, notes } = req.body;
    const amt = Number(amount);
    if (!from_member_id || !to_member_id) {
      return res.status(400).json({ error: 'from_member_id and to_member_id required' });
    }
    if (Number(from_member_id) === Number(to_member_id)) {
      return res.status(400).json({ error: 'Cannot settle with yourself' });
    }
    if (!amt || amt <= 0) return res.status(400).json({ error: 'Valid amount required' });
    if (!settled_date) return res.status(400).json({ error: 'settled_date required' });

    const { rows: mems } = await query(
      `SELECT id FROM split_members WHERE group_id = $1 AND id = ANY($2::int[])`,
      [group.id, [from_member_id, to_member_id]]
    );
    if (mems.length !== 2) return res.status(400).json({ error: 'Invalid members' });

    const { rows } = await query(
      `INSERT INTO split_settlements
         (group_id, from_member_id, to_member_id, amount, settled_date, notes)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [group.id, from_member_id, to_member_id, amt, settled_date, notes || null]
    );
    await query(`UPDATE split_groups SET updated_at = NOW() WHERE id = $1`, [group.id]);
    res.status(201).json({ ...rows[0], amount: Number(rows[0].amount) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/groups/:gid/settlements/:sid', async (req, res) => {
  try {
    const uid = userId(req);
    const group = await assertGroupOwner(req.params.gid, uid);
    if (!group) return res.status(404).json({ error: 'Group not found' });
    const { rowCount } = await query(
      'DELETE FROM split_settlements WHERE id = $1 AND group_id = $2',
      [req.params.sid, group.id]
    );
    if (!rowCount) return res.status(404).json({ error: 'Not found' });
    await query(`UPDATE split_groups SET updated_at = NOW() WHERE id = $1`, [group.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
