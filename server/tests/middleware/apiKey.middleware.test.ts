import { describe, it, expect, vi, beforeEach } from 'vitest';
import bcrypt from 'bcryptjs';

// Mock env variables
vi.mock('../../src/config/env', () => ({
  env: {
    NODE_ENV: 'test',
  },
}));

import { requireApiKey } from '../../src/middleware/apiKey.middleware';
import { ApiKey } from '../../src/models/ApiKey';

// Mock ApiKey Mongoose Model
vi.mock('../../src/models/ApiKey', () => ({
  ApiKey: {
    find: vi.fn(),
    updateOne: vi.fn().mockImplementation(() => ({
      catch: vi.fn().mockResolvedValue({}),
    })),
  },
}));

vi.mock('bcryptjs', () => ({
  default: {
    compare: vi.fn(),
  },
}));

describe('API Key Authentication Middleware', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  const mockRes = () => {
    const res: any = {};
    res.status = vi.fn().mockReturnValue(res);
    res.json = vi.fn().mockReturnValue(res);
    res.locals = {};
    return res;
  };

  const mockNext = vi.fn();

  it('should block requests missing Authorization header (401)', async () => {
    const middleware = requireApiKey('escrow:read');
    const req: any = { headers: {} };
    const res = mockRes();

    await middleware(req, res, mockNext);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ error: 'Missing or invalid API key' })
    );
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('should authenticate a valid API Key and attach metadata', async () => {
    const middleware = requireApiKey('escrow:read');
    const req: any = {
      headers: { authorization: 'Bearer ZPKEY-validkey' },
    };
    const res = mockRes();

    const mockCandidates = [
      {
        _id: 'mock-key-id',
        keyHash: 'hashed-key',
        permissions: ['escrow:read'],
        isActive: true,
      },
    ];

    vi.mocked(ApiKey.find).mockReturnValue({
      lean: vi.fn().mockResolvedValueOnce(mockCandidates),
    } as any);

    vi.mocked(bcrypt.compare).mockResolvedValueOnce(true as never);

    await middleware(req, res, mockNext);

    expect(req.apiKeyDoc).toBeDefined();
    expect(req.apiKeyDoc?.permissions).toContain('escrow:read');
    expect(mockNext).toHaveBeenCalled();
    expect(res.status).not.toHaveBeenCalled();
  });

  it('should block invalid API Keys (401)', async () => {
    const middleware = requireApiKey('escrow:read');
    const req: any = {
      headers: { authorization: 'Bearer ZPKEY-invalidkey' },
    };
    const res = mockRes();

    vi.mocked(ApiKey.find).mockReturnValue({
      lean: vi.fn().mockResolvedValueOnce([]), // No candidate keys
    } as any);

    await middleware(req, res, mockNext);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ error: 'Invalid API key' })
    );
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('should block valid key with insufficient permissions (403)', async () => {
    // Requires 'escrow:write'
    const middleware = requireApiKey('escrow:write');
    const req: any = {
      headers: { authorization: 'Bearer ZPKEY-validkey' },
    };
    const res = mockRes();

    const mockCandidates = [
      {
        _id: 'mock-key-id',
        keyHash: 'hashed-key',
        permissions: ['escrow:read'], // Only has read permissions
        isActive: true,
      },
    ];

    vi.mocked(ApiKey.find).mockReturnValue({
      lean: vi.fn().mockResolvedValueOnce(mockCandidates),
    } as any);

    vi.mocked(bcrypt.compare).mockResolvedValueOnce(true as never);

    await middleware(req, res, mockNext);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ error: 'Insufficient API key permissions' })
    );
    expect(mockNext).not.toHaveBeenCalled();
  });

  it('should grant full root access if key contains asterisk wildcard (*)', async () => {
    const middleware = requireApiKey('escrow:write', 'webhooks:write');
    const req: any = {
      headers: { authorization: 'Bearer ZPKEY-rootkey' },
    };
    const res = mockRes();

    const mockCandidates = [
      {
        _id: 'mock-key-id',
        keyHash: 'hashed-key',
        permissions: ['*'], // Wildcard permissions
        isActive: true,
      },
    ];

    vi.mocked(ApiKey.find).mockReturnValue({
      lean: vi.fn().mockResolvedValueOnce(mockCandidates),
    } as any);

    vi.mocked(bcrypt.compare).mockResolvedValueOnce(true as never);

    await middleware(req, res, mockNext);

    expect(req.apiKeyDoc).toBeDefined();
    expect(mockNext).toHaveBeenCalled();
  });
});
