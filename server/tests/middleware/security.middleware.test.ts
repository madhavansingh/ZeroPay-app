import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Request, Response, NextFunction } from 'express';
import {
  noSqlSanitizer,
  strictContentType,
} from '../../src/middleware/security.middleware';

// ── Helpers ──────────────────────────────────────────────────────────────────

function makeReq(overrides: Partial<Request> = {}): Request {
  return {
    body: {},
    query: {},
    params: {},
    method: 'GET',
    headers: {},
    ...overrides,
  } as unknown as Request;
}

function makeRes(): Response & { _status?: number; _json?: unknown } {
  const res: any = {};
  res.status = vi.fn().mockReturnValue(res);
  res.json = vi.fn().mockReturnValue(res);
  return res;
}

const next: NextFunction = vi.fn();

beforeEach(() => {
  vi.clearAllMocks();
});

// ── noSqlSanitizer tests ──────────────────────────────────────────────────────

describe('noSqlSanitizer', () => {
  it('passes through clean body untouched', () => {
    const req = makeReq({ body: { username: 'alice', amount: 42 } });
    noSqlSanitizer(req, makeRes(), next);
    expect(req.body).toEqual({ username: 'alice', amount: 42 });
    expect(next).toHaveBeenCalledOnce();
  });

  it('strips $ operator keys from body', () => {
    const req = makeReq({ body: { '$gt': '', username: 'admin' } });
    noSqlSanitizer(req, makeRes(), next);
    expect(req.body).toEqual({ username: 'admin' });
    expect(req.body['$gt']).toBeUndefined();
    expect(next).toHaveBeenCalledOnce();
  });

  it('strips nested $ operator keys recursively', () => {
    const req = makeReq({
      body: {
        user: { '$where': 'sleep(100)', name: 'bob' },
        amount: 100,
      },
    });
    noSqlSanitizer(req, makeRes(), next);
    expect(req.body).toEqual({ user: { name: 'bob' }, amount: 100 });
    expect(next).toHaveBeenCalledOnce();
  });

  it('strips dot-notation keys from body', () => {
    const req = makeReq({ body: { 'a.b': 'injection', safe: 'ok' } });
    noSqlSanitizer(req, makeRes(), next);
    expect(req.body).toEqual({ safe: 'ok' });
    expect(next).toHaveBeenCalledOnce();
  });

  it('sanitizes arrays inside body', () => {
    const req = makeReq({
      body: { items: [{ '$gt': 0 }, { price: 5 }] },
    });
    noSqlSanitizer(req, makeRes(), next);
    expect(req.body.items).toEqual([{}, { price: 5 }]);
    expect(next).toHaveBeenCalledOnce();
  });

  it('strips $ keys from query params', () => {
    const req = makeReq({ query: { '$ne': 'null', page: '1' } as any });
    noSqlSanitizer(req, makeRes(), next);
    expect((req as any).query['$ne']).toBeUndefined();
    expect((req as any).query.page).toBe('1');
    expect(next).toHaveBeenCalledOnce();
  });

  it('strips $ keys from route params', () => {
    const req = makeReq({ params: { '$where': 'evil', id: 'abc' } as any });
    noSqlSanitizer(req, makeRes(), next);
    expect((req as any).params['$where']).toBeUndefined();
    expect(req.params.id).toBe('abc');
    expect(next).toHaveBeenCalledOnce();
  });

  it('passes through null / primitive body values safely', () => {
    const req = makeReq({ body: null as any });
    noSqlSanitizer(req, makeRes(), next);
    expect(next).toHaveBeenCalledOnce();
  });

  it('handles deeply nested malicious payloads', () => {
    const req = makeReq({
      body: {
        level1: {
          level2: {
            '$or': [{ admin: true }],
            legit: 'value',
          },
        },
      },
    });
    noSqlSanitizer(req, makeRes(), next);
    expect(req.body.level1.level2['$or']).toBeUndefined();
    expect(req.body.level1.level2.legit).toBe('value');
    expect(next).toHaveBeenCalledOnce();
  });

  it('keeps string values that happen to start with $ as leaf values', () => {
    // Only keys are stripped, not string VALUES that start with $
    const req = makeReq({ body: { note: '$10 payment' } });
    noSqlSanitizer(req, makeRes(), next);
    expect(req.body.note).toBe('$10 payment');
    expect(next).toHaveBeenCalledOnce();
  });
});

// ── strictContentType tests ───────────────────────────────────────────────────

describe('strictContentType', () => {
  it('allows GET requests regardless of content-type', () => {
    const req = makeReq({ method: 'GET', headers: {} });
    const res = makeRes();
    strictContentType(req, res, next);
    expect(next).toHaveBeenCalledOnce();
    expect(res.status).not.toHaveBeenCalled();
  });

  it('allows DELETE requests regardless of content-type', () => {
    const req = makeReq({ method: 'DELETE', headers: {} });
    const res = makeRes();
    strictContentType(req, res, next);
    expect(next).toHaveBeenCalledOnce();
  });

  it('allows POST with application/json content-type', () => {
    const req = makeReq({
      method: 'POST',
      headers: { 'content-type': 'application/json' },
    });
    const res = makeRes();
    strictContentType(req, res, next);
    expect(next).toHaveBeenCalledOnce();
    expect(res.status).not.toHaveBeenCalled();
  });

  it('allows POST with application/json; charset=utf-8', () => {
    const req = makeReq({
      method: 'POST',
      headers: { 'content-type': 'application/json; charset=utf-8' },
    });
    const res = makeRes();
    strictContentType(req, res, next);
    expect(next).toHaveBeenCalledOnce();
  });

  it('allows POST with multipart/form-data for file uploads', () => {
    const req = makeReq({
      method: 'POST',
      headers: { 'content-type': 'multipart/form-data; boundary=abc123' },
    });
    const res = makeRes();
    strictContentType(req, res, next);
    expect(next).toHaveBeenCalledOnce();
  });

  it('allows PUT with application/json', () => {
    const req = makeReq({
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
    });
    const res = makeRes();
    strictContentType(req, res, next);
    expect(next).toHaveBeenCalledOnce();
  });

  it('allows PATCH with application/json', () => {
    const req = makeReq({
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
    });
    const res = makeRes();
    strictContentType(req, res, next);
    expect(next).toHaveBeenCalledOnce();
  });

  it('rejects POST with text/plain content-type with 415', () => {
    const req = makeReq({
      method: 'POST',
      headers: { 'content-type': 'text/plain' },
    });
    const res = makeRes();
    strictContentType(req, res, next);
    expect(res.status).toHaveBeenCalledWith(415);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false })
    );
    expect(next).not.toHaveBeenCalled();
  });

  it('rejects POST with application/xml content-type with 415', () => {
    const req = makeReq({
      method: 'POST',
      headers: { 'content-type': 'application/xml' },
    });
    const res = makeRes();
    strictContentType(req, res, next);
    expect(res.status).toHaveBeenCalledWith(415);
    expect(next).not.toHaveBeenCalled();
  });

  it('rejects POST with no content-type header with 415', () => {
    const req = makeReq({
      method: 'POST',
      headers: {},
    });
    const res = makeRes();
    strictContentType(req, res, next);
    expect(res.status).toHaveBeenCalledWith(415);
    expect(next).not.toHaveBeenCalled();
  });
});
