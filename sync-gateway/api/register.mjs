import crypto from 'node:crypto';
import { readBody, json, safeError, employeeId, githubGet, githubPut, encryptJson, decryptJson, signSession, normalizeFio } from './_lib.mjs';

export default async function handler(req, res) {
  if (req.method !== 'POST') return json(res, 405, { error: 'method_not_allowed' });
  try {
    const body = await readBody(req);
    const fio = String(body.fio || '').trim();
    const role = String(body.role || '').toLowerCase();
    const deviceId = String(body.deviceId || crypto.randomUUID());
    if (normalizeFio(fio).split(' ').length < 2) return json(res, 400, { error: 'fio_required' });
    if (!['bartender', 'waiter'].includes(role)) return json(res, 400, { error: 'invalid_role' });

    const id = employeeId(fio, role);
    const path = `data/employees/${id}.json`;
    const existing = await githubGet(path);
    let employee;
    if (existing) {
      employee = decryptJson(existing.text);
      if (employee.disabled) return json(res, 403, { error: 'employee_disabled' });
      employee.lastSeenAt = new Date().toISOString();
      employee.devices = Array.from(new Set([...(employee.devices || []), deviceId])).slice(-20);
      await githubPut(path, encryptJson(employee), `Update employee session ${id}`, existing.sha);
    } else {
      employee = {
        id,
        fio,
        role,
        createdAt: new Date().toISOString(),
        lastSeenAt: new Date().toISOString(),
        disabled: false,
        devices: [deviceId]
      };
      await githubPut(path, encryptJson(employee), `Register employee ${id}`);
    }

    const token = signSession({ employeeId: id, role, fio, deviceId });
    return json(res, 200, {
      employee: { id, fio, role },
      token
    });
  } catch (error) {
    const e = safeError(error);
    return json(res, e.status, e.body);
  }
}
